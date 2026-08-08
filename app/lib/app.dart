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
import 'features/settings/theme_settings_page.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_settings.dart';

/// 中文本地化配置（主入口与秒开模式的 MaterialApp 共用）
const bookkeepLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const bookkeepSupportedLocales = [Locale('zh', 'CN')];

/// App 根组件：底部导航（记账/账户/分类）+ 秒开模式入口
class BookkeepApp extends ConsumerStatefulWidget {
  const BookkeepApp({super.key});

  @override
  ConsumerState<BookkeepApp> createState() => _BookkeepAppState();
}

class _BookkeepAppState extends ConsumerState<BookkeepApp> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    // 个性化主题：种子色 + 外观模式（设置页即时生效，全树热重建）
    final themeSettings = ref.watch(themeSettingsProvider);
    return MaterialApp(
      title: 'bookkeep',
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: bookkeepLocalizationsDelegates,
      supportedLocales: bookkeepSupportedLocales,
      // 审查 U-2：深色模式（themeMode: system 跟随系统），语义色经 AppColors 扩展
      theme: buildTheme(Brightness.light, seedColor: themeSettings.seedColor),
      darkTheme: buildTheme(Brightness.dark, seedColor: themeSettings.seedColor),
      themeMode: themeSettings.mode,
      builder: lockGateBuilder,
      // Builder 提供 Navigator 内 context（state.context 在 MaterialApp 之上，无法导航）
      home: Builder(
        builder: (navContext) {
          // 启动即拉取服务端账本角色（登录态；离线忽略，保持缓存），
          // 驱动 viewer 写拦截（Spec §4.1 UI + 服务端双校验）
          ref.watch(serverBooksProvider);
          final viewer = ref.watch(currentRoleProvider) == 'viewer';
          return Scaffold(
            // 审查 U-9：IndexedStack 保持各 Tab 状态（滚动位置、报表 _range/_hideAmounts）
            body: IndexedStack(
              index: _tab,
              children: const [
                BillsPage(),
                CategoriesPage(),
                RecurringPage(),
                ReportsPage(),
                CalendarPage(),
              ],
            ),
            floatingActionButton: viewer
                ? null
                : FloatingActionButton(
                    onPressed: () => _openQuickEntry(navContext),
                    tooltip: '记一笔',
                    child: const Icon(Icons.add),
                  ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: '账单'),
                NavigationDestination(icon: Icon(Icons.category_outlined), label: '分类'),
                NavigationDestination(icon: Icon(Icons.repeat), label: '周期记账'),
                NavigationDestination(icon: Icon(Icons.bar_chart), label: '报表'),
                NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: '日历'),
              ],
            ),
            // 审查 U-1：单 AppBar，按 Tab 配置标题与动作（页面动作经顶层函数组装）
            appBar: AppBar(
              title: Text(_tabTitles[_tab]),
              actions: [
                ..._tabActions(navContext),
                const BookSwitcher(),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => _showSettings(navContext),
                ),
              ],
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
                title: const Text('个性化主题'),
                subtitle: const Text('主题颜色 / 外观模式'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ThemeSettingsPage()),
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
