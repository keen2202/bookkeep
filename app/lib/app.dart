import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local/database_provider.dart';
import 'data/repositories/settings_repository.dart';
import 'features/accounts/accounts_page.dart';
import 'features/auth_lock/lock_gate.dart';
import 'features/auth_lock/lock_settings.dart';
import 'features/auto_capture/csv_import/csv_import_page.dart' show AutoCaptureSettingsEntry;
import 'features/backup/backup_page.dart';
import 'features/books/book_switcher.dart';
import 'features/books/books_page.dart' show serverBooksProvider;
import 'features/books/books_providers.dart' show currentRoleProvider;
import 'features/budgets/budgets_page.dart';
import 'features/calendar/calendar_page.dart';
import 'features/categories/categories_page.dart';
import 'features/quick_entry/quick_entry_sheet.dart';
import 'features/recurring/recurring_page.dart';
import 'features/reports/reports_page.dart';

/// App 根组件：底部导航（记账/账户/分类）+ 秒开模式入口
class BookkeepApp extends ConsumerStatefulWidget {
  const BookkeepApp({super.key});

  @override
  ConsumerState<BookkeepApp> createState() => _BookkeepAppState();
}

class _BookkeepAppState extends ConsumerState<BookkeepApp> {
  int _tab = 0;

  /// 需传入 Navigator 内的 context（state.context 在 MaterialApp 之上，无法定位 Navigator）
  Future<void> _openQuickEntry(BuildContext navContext) async {
    final saved = await Navigator.of(navContext).push<bool>(
      MaterialPageRoute(builder: (_) => const QuickEntrySheet()),
    );
    if (saved == true && navContext.mounted) {
      ScaffoldMessenger.of(navContext).showSnackBar(
        const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bookkeep',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      builder: lockGateBuilder,
      // Builder 提供 Navigator 内 context（state.context 在 MaterialApp 之上，无法导航）
      home: Builder(
        builder: (navContext) {
          // 启动即拉取服务端账本角色（登录态；离线忽略，保持缓存），
          // 驱动 viewer 写拦截（Spec §4.1 UI + 服务端双校验）
          ref.watch(serverBooksProvider);
          final viewer = ref.watch(currentRoleProvider) == 'viewer';
          return Scaffold(
            body: switch (_tab) {
              0 => const CategoriesPage(),
              1 => const AccountsPage(),
              2 => const BudgetsPage(),
              3 => const ReportsPage(),
              4 => const CalendarPage(),
              _ => const SizedBox.shrink(),
            },
            floatingActionButton: viewer
                ? null
                : FloatingActionButton(
                    heroTag: 'quick_entry_fab', // 与分类页 FAB 区分，避免 Hero 标签冲突
                    onPressed: () => _openQuickEntry(navContext),
                    tooltip: '记一笔',
                    child: const Icon(Icons.add),
                  ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.category_outlined), label: '分类'),
                NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: '账户'),
                NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: '预算'),
                NavigationDestination(icon: Icon(Icons.bar_chart), label: '报表'),
                NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: '日历'),
              ],
            ),
            appBar: AppBar(
              title: const Text('bookkeep'),
              actions: [
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
                leading: const Icon(Icons.repeat),
                title: const Text('周期记账'),
                subtitle: const Text('日/周/月/季/年 + 时间锚点 + 补跑'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecurringPage()),
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
