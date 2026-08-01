import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local/database_provider.dart';
import 'data/repositories/settings_repository.dart';
import 'features/accounts/accounts_page.dart';
import 'features/budgets/budgets_page.dart';
import 'features/categories/categories_page.dart';
import 'features/quick_entry/quick_entry_sheet.dart';
import 'features/reports/reports_page.dart';

/// App 根组件：底部导航（记账/账户/分类）+ 秒开模式入口
class BookkeepApp extends ConsumerStatefulWidget {
  const BookkeepApp({super.key});

  @override
  ConsumerState<BookkeepApp> createState() => _BookkeepAppState();
}

class _BookkeepAppState extends ConsumerState<BookkeepApp> {
  int _tab = 0;

  Future<void> _openQuickEntry() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const QuickEntrySheet()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
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
      home: Scaffold(
        body: switch (_tab) {
          0 => const CategoriesPage(),
          1 => const AccountsPage(),
          2 => const BudgetsPage(),
          3 => const ReportsPage(),
          _ => const SizedBox.shrink(),
        },
        floatingActionButton: FloatingActionButton(
          onPressed: _openQuickEntry,
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
          ],
        ),
        appBar: AppBar(
          title: const Text('bookkeep'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _showSettings(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const _SettingsSheet(),
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
            ],
          ),
        );
      },
    );
  }
}
