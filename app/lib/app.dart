import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';


import 'core/ledger_version.dart';
import 'data/local/database_provider.dart';
import 'data/repositories/settings_repository.dart';
import 'features/accounts/accounts_page.dart';
import 'features/auth_lock/lock_gate.dart';
import 'features/auth_lock/lock_settings.dart';
import 'features/auto_capture/csv_import/csv_import_page.dart' show AutoCaptureSettingsEntry;
import 'features/backup/backup_page.dart';
import 'features/books/book_switcher.dart';
import 'features/books/books_page.dart' show serverBooksProvider;
import 'features/books/books_providers.dart' show currentBookIdProvider, currentRoleProvider;
import 'features/bills/bills_page.dart';
import 'features/calendar/calendar_page.dart';
import 'features/categories/categories_page.dart' show CategoriesPage, categoriesPageAction;
import 'features/currency/currency_manage_page.dart';
import 'features/quick_entry/quick_entry_sheet.dart';
import 'features/recurring/recurring_page.dart' show RecurringPage, recurringPageActions;
import 'features/recurring/recurring_providers.dart' show recurringServiceProvider;
import 'features/reports/reports_page.dart';
import 'features/settings/account_sync_section.dart';
import 'features/settings/appearance_page.dart';
import 'shared/theme/app_icons.dart';
import 'shared/theme/theme_controller.dart';
import 'shared/theme/theme_transition.dart';
import 'shared/widgets/glass_nav.dart';
import 'shared/theme/background/app_background.dart';

/// 中文本地化配置（主入口与秒开模式的 MaterialApp 共用）
const bookkeepLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const bookkeepSupportedLocales = [Locale('zh', 'CN')];

/// 全局 shell builder（审核 F7/A2）：主题 200ms 过场（FGDS §9）+ 全局
/// 纯净背景（Spec §2.2）+ 隐私锁门禁。主入口与秒开入口共用同一拼装链。
Widget appShellBuilder(BuildContext context, Widget? child) => ThemeTransition(
      child: AppBackground(
        child: lockGateBuilder(context, child),
      ),
    );

/// App 根组件：底部导航（记账/账户/分类）+ 秒开模式入口
class BookkeepApp extends ConsumerStatefulWidget {
  const BookkeepApp({super.key, this.startInQuickEntry = false});

  /// 冷启动秒开模式：首帧后自动打开快速记账页，并提供明确退出入口。
  final bool startInQuickEntry;

  @override
  ConsumerState<BookkeepApp> createState() => _BookkeepAppState();
}

class _BookkeepAppState extends ConsumerState<BookkeepApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  int _tab = 0;

  /// 主页滚动联动（FG-NAV 分隔线渐显）：滚动 >0 渐显 / 顶部隐藏
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.startInQuickEntry) {
      // 秒开模式不再把 QuickEntrySheet 作为根路由，而是推到主界面之上：
      // 这样快速记账页拥有可返回的主界面，用户可随时点击“退出”离开。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => const QuickEntrySheet(),
          ),
        );
      });
    }
    // 同步合并落库后 bump 刷新总线（审查 F-1）：远端流水即时出现在报表/日历
    syncMergeBus.addListener(_onSyncMerged);
  }

  @override
  void dispose() {
    syncMergeBus.removeListener(_onSyncMerged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onSyncMerged() {
    if (mounted) ref.read(ledgerVersionProvider.notifier).state++;
  }

  /// 前台恢复时重跑周期/分期补跑（审查 F-2）；幂等 + 失败静默记日志
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_runCatchup());
    }
  }

  Future<void> _runCatchup() async {
    try {
      final bookId = ref.read(currentBookIdProvider);
      await ref.read(recurringServiceProvider).runAll(bookId: bookId);
      await ref.read(recurringServiceProvider).runInstallmentDues(bookId: bookId);
      ref.read(ledgerVersionProvider.notifier).state++;
    } catch (e) {
      debugPrint('recurring catch-up on resume failed: $e');
    }
  }

  /// 需传入 Navigator 内的 context（state.context 在 MaterialApp 之上，无法定位 Navigator）
  Future<void> _openQuickEntry(BuildContext navContext) => openQuickEntrySheet(navContext);

  static const _tabTitles = ['账单', '分类', '周期记账', '报表', '日历'];

  @override
  Widget build(BuildContext context) {
    // 个性化主题：预制主题直出 / 自定义种子色（设置页即时生效，全树热重建）
    final themeSettings = ref.watch(themeControllerProvider);
    final themes = materialThemesFor(themeSettings);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'bookkeep',
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: bookkeepLocalizationsDelegates,
      supportedLocales: bookkeepSupportedLocales,
      // 预制主题完整直出；custom 退回 fromSeed 派生主色路径
      theme: themes.theme,
      darkTheme: themes.darkTheme,
      themeMode: themes.mode,
      // 主题切换 200ms 过场（FGDS §9/Spec §6 状态切换档）+ 全局纯净背景
      // （位于 Navigator 之上，二级页/弹层共享同一背景）+ 隐私锁门禁；
      // 与秒开入口共用 appShellBuilder（审核 F7/A2）
      builder: (context, child) => appShellBuilder(context, child),
      // Builder 提供 Navigator 内 context（state.context 在 MaterialApp 之上，无法导航）
      home: Builder(
        builder: (navContext) {
          // 启动即拉取服务端账本角色（登录态；离线忽略，保持缓存），
          // 驱动 viewer 写拦截（Spec §4.1 UI + 服务端双校验）
          ref.watch(serverBooksProvider);
          final viewer = ref.watch(currentRoleProvider) == 'viewer';
          return Scaffold(
            body: NotificationListener<UserScrollNotification>(
              onNotification: (n) {
                final scrolled = n.metrics.pixels > 0;
                if (scrolled != _scrolled) {
                  setState(() => _scrolled = scrolled);
                }
                return false;
              },
              // 审查 U-9：IndexedStack 保持各 Tab 状态（滚动位置、报表 _range/_hideAmounts）
              child: IndexedStack(
                index: _tab,
                children: const [
                  BillsPage(),
                  CategoriesPage(),
                  RecurringPage(),
                  ReportsPage(),
                  CalendarPage(),
                ],
              ),
            ),
            floatingActionButton: viewer
                ? null
                : GlassFab(
                    icon: Icons.add,
                    tooltip: '记一笔',
                    onTap: () => _openQuickEntry(navContext),
                  ),
            bottomNavigationBar: GlassBottomBar(
              selectedIndex: _tab,
              showDivider: _scrolled,
              onTap: (i) => setState(() => _tab = i),
              items: [
                for (final m in AppModule.values)
                  GlassNavItem(
                    icon: moduleIcon(m, themeSettings.iconPack),
                    label: m.label,
                  ),
              ],
            ),
            // FG-NAV（BK-FG-021）：G3 吸顶玻璃栏；滚动后分隔线渐显
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: GlassAppBar(
                title: Text(_tabTitles[_tab]),
                showDivider: _scrolled,
                actions: [
                  ..._tabActions(navContext),
                  const BookSwitcher(),
                  GlassAppBarAction(
                    icon: Icons.settings_outlined,
                    tooltip: '设置',
                    onPressed: () => _showSettings(navContext),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 当前 Tab 的动作（viewer 只读时为空，Spec §4.1 双重拒绝）
  List<Widget> _tabActions(BuildContext navContext) {
    return switch (_tab) {
      1 => [ ?categoriesPageAction(navContext, ref) ],
      2 => recurringPageActions(navContext, ref),
      _ => const [],
    };
  }

  void _showSettings(BuildContext navContext) {
    showModalBottomSheet<void>(
      context: navContext,
      isScrollControlled: true,
      builder: (_) => const SafeArea(
        child: SingleChildScrollView(child: _SettingsSheet()),
      ),
    );
  }
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = SettingsRepository(ref.watch(databaseProvider));
    return FutureBuilder<bool>(
      future: settings.secondsOpenMode(),
      builder: (context, snapshot) {
        final enabled = snapshot.data ?? false;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AccountSyncSection(),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('外观'),
                subtitle: const Text('主题方案 / 图标风格'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AppearancePage()),
                ),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('秒开模式（冷启动直达记账页）'),
                value: enabled,
                onChanged: (v) async {
                  await settings.setSecondsOpenMode(v);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const Divider(),
              const AutoCaptureSettingsEntry(),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('备份与导出'),
                subtitle: const Text('CSV 导出 / 加密备份 / WebDAV / 恢复'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BackupPage()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('账户管理'),
                subtitle: const Text('新增 / 编辑 / 归档账户'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccountsPage()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.currency_exchange),
                title: const Text('汇率管理'),
                subtitle: const Text('手动设置各币种汇率（未设置将显式标注）'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CurrencyManagePage()),
                ),
              ),
              const Divider(),
              const LockSettingsTile(),
            ],
          ),
        );
      },
    );
  }
}
