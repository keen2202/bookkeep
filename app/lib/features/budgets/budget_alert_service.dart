import '../../data/repositories/budget_repository.dart';
import '../../domain/services/budget_progress_calculator.dart';

/// 预算提醒通知端口（审查 F-5）：实现可替换，便于单测；通知失败不抛给调用方
abstract class BudgetNotifier {
  Future<void> showBudgetAlert({required String title, required String body});
}

/// 预算阈值评估（审查 F-5）：保存流水后调用，达阈值/超支且本周期未通知 → 通知一次。
/// 「每周期每预算每级别恰好一次」由 BudgetRepository.shouldNotify/markAlertNotified 保证。
class BudgetAlertService {
  BudgetAlertService({required this.repo, required this.notifier});

  final BudgetRepository repo;
  final BudgetNotifier notifier;

  static const _monthStartDay = 1;

  /// 返回本次发出的通知数；评估/通知失败静默（不阻断记账主流程）
  Future<int> evaluate({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final budgets = await repo.listBudgets();
    var notified = 0;
    for (final budget in budgets) {
      final window = BudgetProgressCalculator.periodWindow(
        current,
        monthStartDay: _monthStartDay,
      );
      final spent = await repo.spentForPeriod(
        categoryId: budget.categoryId,
        start: window.start,
        end: window.end,
      );
      final progress = BudgetProgressCalculator.progress(
        budgetMinor: budget.amountMinor,
        spentMinor: spent,
        daysRemaining: 0,
        thresholdPercent: budget.threshold,
      );
      // 超支级别优先于阈值级别（同一预算同一周期只发一条）
      final level = progress.exceeded
          ? 'exceeded'
          : (progress.overThreshold ? 'threshold' : null);
      if (level == null) continue;
      final period = _dayKey(window.start);
      if (!await repo.shouldNotify(budget.id, period: period, level: level)) {
        continue;
      }
      try {
        await notifier.showBudgetAlert(
          title: progress.exceeded ? '预算已超支' : '预算接近上限',
          body: '预算${progress.exceeded ? '已超支' : '已达阈值'}（${progress.percent}%）',
        );
      } catch (_) {
        // 通知权限拒绝/平台不可用时优雅降级：不阻断记账
        continue;
      }
      await repo.markAlertNotified(budget.id, period: period, level: level);
      notified++;
    }
    return notified;
  }

  String _dayKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }
}
