import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger_version.dart';
import '../../core/utils/money_format.dart';
import '../../shared/theme/app_theme.dart';
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

/// 预算视图模型：watch 刷新总线，写操作后自动重算（Spec §3.4 / 审查 F-1）
final budgetsViewModelProvider = FutureProvider<List<BudgetWithProgress>>((ref) async {
  ref.watch(ledgerVersionProvider);
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
        thresholdPercent: budget.threshold, // 审查 F-5：阈值读预算字段
      ),
    ));
  }
  return result;
});

/// 预算页（Spec §3.4 / BK-P0-004）；无内层 Scaffold/AppBar/FAB（审查 U-1）
class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsViewModelProvider);
    final categoriesAsync = ref.watch(categoriesViewModelProvider);
    return budgets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (items) {
        final categories = categoriesAsync.maybeWhen(
            data: (c) => {for (final cat in c) cat.id: cat}, orElse: () => const {});
        if (items.isEmpty) {
          return const Center(child: Text('还没有预算，点击右上角 + 新建'));
        }
        // 审查 U-10：ListView.builder 惰性构建
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return _BudgetCard(
              item: item,
              categoryName: item.budget.categoryId == null
                  ? '总预算'
                  : categories[item.budget.categoryId]?.name ?? '分类',
            );
          },
        );
      },
    );
  }
}

/// 主 shell AppBar 动作：新建预算（viewer 只读 → null，Spec §4.1 双重拒绝）
Widget? budgetsPageAction(BuildContext context, WidgetRef ref) {
  if (ref.watch(currentRoleProvider) == 'viewer') return null;
  return IconButton(
    tooltip: '新建预算',
    icon: const Icon(Icons.add),
    onPressed: () => BudgetEditSheet.show(context),
  );
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
      // 审查 F-10：点按进入编辑（金额/阈值/分类），底部可删除
      child: InkWell(
        onTap: () => BudgetEditSheet.show(context, budget: item.budget),
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
                    Text('接近上限',
                        style: theme.textTheme.bodySmall?.copyWith(color: context.appColors.warning)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
