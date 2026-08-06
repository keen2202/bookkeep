import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money_format.dart';
import '../../data/local/database.dart';
import '../../domain/services/budget_progress_calculator.dart';
import '../auth_lock/lock_controller.dart';
import '../books/books_providers.dart'
    show budgetRepositoryProvider, currentRoleProvider;
import '../categories/categories_page.dart' show categoriesViewModelProvider;
import 'budget_edit_sheet.dart';
import 'budget_progress_bar.dart';

class BudgetWithProgress {
  const BudgetWithProgress({required this.budget, required this.progress});
  final Budget budget;
  final BudgetProgress progress;
}

/// 预算视图模型：记账保存路径显式 invalidate 触发重算（Spec §3.4）
final budgetsViewModelProvider = FutureProvider<List<BudgetWithProgress>>((ref) async {
  final repo = ref.watch(budgetRepositoryProvider);

  final now = DateTime.now();
  final budgets = await repo.listBudgets();
  final result = <BudgetWithProgress>[];
  for (final budget in budgets) {
    final monthStartDay = int.tryParse(budget.period.split('-')[2]) ?? 1;
    final window = BudgetProgressCalculator.periodWindow(now, monthStartDay: monthStartDay);
    final spent = await repo.spentForPeriod(
      categoryId: budget.categoryId,
      start: window.start,
      end: window.end,
    );
    final daysRemaining = window.end.difference(now).inDays;
    result.add(BudgetWithProgress(
      budget: budget,
      progress: BudgetProgressCalculator.progress(
        budgetMinor: budget.amountMinor,
        spentMinor: spent,
        daysRemaining: daysRemaining > 0 ? daysRemaining : 0,
      ),
    ));
  }
  return result;
});

/// 预算页（Spec §3.4 / BK-P0-004）
class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsViewModelProvider);
    final categoriesAsync = ref.watch(categoriesViewModelProvider);
    final viewer = ref.watch(currentRoleProvider) == 'viewer';
    return Scaffold(
      appBar: AppBar(title: const Text('预算')),
      body: budgets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (items) {
          final categories = categoriesAsync.maybeWhen(
              data: (c) => {for (final cat in c) cat.id: cat}, orElse: () => const {});
          if (items.isEmpty) {
            return const Center(child: Text('还没有预算，点击右下角 + 新建'));
          }
          return ListView(
            padding: const EdgeInsets.all(8),
            children: [
              for (final item in items)
                _BudgetCard(
                  item: item,
                  categoryName: item.budget.categoryId == null
                      ? '总预算'
                      : categories[item.budget.categoryId]?.name ?? '分类',
                ),
            ],
          );
        },
      ),
      // viewer 只读（Spec §4.1 权限矩阵：UI 与服务端双重拒绝）
      // HeroMode 禁用：避免页面 FAB 与全局 FAB 在切换/重建时触发 Hero flight 出现多个 + 按钮
      floatingActionButton: viewer
          ? null
          : HeroMode(
              enabled: false,
              child: FloatingActionButton.extended(
                heroTag: 'budgets_fab',
                onPressed: () => BudgetEditSheet.show(context),
                tooltip: '新建预算',
                icon: const Icon(Icons.add),
                label: const Text('新增预算'),
              ),
            ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({required this.item, required this.categoryName});

  final BudgetWithProgress item;
  final String categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = item.progress;
    final theme = Theme.of(context);
    final masked = ref.watch(amountMaskProvider);
    final money = masked ? maskedMoney() : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(categoryName, style: theme.textTheme.titleMedium),
                Text(
                  '${money ?? formatMoney(progress.spentMinor)} / ${money ?? formatMoney(item.budget.amountMinor)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            BudgetProgressBar(progress: progress),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('剩余 ${money ?? formatMoney(progress.remainingMinor)}',
                    style: theme.textTheme.bodySmall),
                Text('日均 ${money ?? formatMoney(progress.dailyBudgetMinor)}',
                    style: theme.textTheme.bodySmall),
                if (progress.exceeded)
                  Text('已超支', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error))
                else if (progress.overThreshold)
                  const Text('接近上限', style: TextStyle(color: Colors.orange, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
