import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger_version.dart';
import '../../data/local/database.dart';
import '../../domain/services/budget_progress_calculator.dart';
import '../books/books_providers.dart' show budgetRepositoryProvider;

class BudgetWithProgress {
  const BudgetWithProgress({required this.budget, required this.progress});
  final Budget budget;
  final BudgetProgress progress;
}

/// 当月总预算摘要（记账页顶部卡片用；仅总预算，无则 null）
class BudgetSummary {
  const BudgetSummary({
    required this.budget,
    required this.progress,
    required this.window,
  });
  final Budget budget;
  final BudgetProgress progress;
  final ({DateTime start, DateTime end}) window;
}

/// 当月总预算摘要：watch 刷新总线（记账保存后自动重算）；
/// 无总预算时返回 null（分类预算单独存在于管理弹层）
final monthBudgetSummaryProvider = FutureProvider<BudgetSummary?>((ref) async {
  ref.watch(ledgerVersionProvider);
  final repo = ref.watch(budgetRepositoryProvider);
  final now = DateTime.now();
  final window = BudgetProgressCalculator.periodWindow(now, monthStartDay: 1);
  final budgets = await repo.listBudgets();
  Budget? total;
  for (final b in budgets) {
    if (b.categoryId == null) {
      total = b;
      break;
    }
  }
  if (total == null) return null;
  final spent = await repo.spentForPeriod(
    categoryId: null,
    start: window.start,
    end: window.end,
  );
  final daysRemaining = window.end.difference(now).inDays;
  return BudgetSummary(
    budget: total,
    progress: BudgetProgressCalculator.progress(
      budgetMinor: total.amountMinor,
      spentMinor: spent,
      daysRemaining: daysRemaining > 0 ? daysRemaining : 0,
      thresholdPercent: total.threshold, // 审查 F-5：阈值读预算字段
    ),
    window: window,
  );
});

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
