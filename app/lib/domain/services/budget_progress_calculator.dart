/// 预算进度计算（Spec §3.4 / BK-P0-004）：
/// 纯函数，周期窗口 + 进度/剩余/日均，便于单元测试。
class BudgetProgressCalculator {
  const BudgetProgressCalculator();

  /// 默认预警阈值（%）——预算未自定义 threshold 时的回退值
  static const warningThresholdPercent = 80;

  /// 周期窗口：以 monthStartDay 为月起始日（默认 1 号）；
  /// 起始日超过当月天数时回退到当月最后一天（如 31 → 2 月 28/29）。
  /// 语义：now 属于窗口 [prevStart, thisStart)，起始日当天属于上一周期。
  static ({DateTime start, DateTime end}) periodWindow(
    DateTime now, {
    required int monthStartDay,
  }) {
    final thisStart = _dayOfMonth(DateTime.utc(now.year, now.month), monthStartDay);
    final prevStart = _dayOfMonth(DateTime.utc(now.year, now.month - 1), monthStartDay);
    if (!now.isAfter(thisStart)) {
      return (start: prevStart, end: thisStart);
    }
    final nextStart = _dayOfMonth(DateTime.utc(now.year, now.month + 1), monthStartDay);
    return (start: thisStart, end: nextStart);
  }

  static DateTime _dayOfMonth(DateTime month, int day) {
    final lastDay = DateTime.utc(month.year, month.month + 1, 0).day;
    return DateTime.utc(month.year, month.month, day > lastDay ? lastDay : day);
  }

  static BudgetProgress progress({
    required int budgetMinor,
    required int spentMinor,
    required int daysRemaining,
    int thresholdPercent = warningThresholdPercent,
  }) {
    final remaining = budgetMinor - spentMinor;
    final percent = budgetMinor <= 0
        ? (spentMinor > 0 ? 100 : 0)
        : (spentMinor * 100 ~/ budgetMinor);
    final daily = remaining > 0 && daysRemaining > 0
        ? remaining ~/ daysRemaining
        : 0;
    return BudgetProgress(
      spentMinor: spentMinor,
      remainingMinor: remaining,
      dailyBudgetMinor: daily,
      percent: percent,
      // 审查 F-5：阈值读预算自带的 threshold 字段（默认 80）
      overThreshold: percent >= thresholdPercent,
      exceeded: spentMinor >= budgetMinor && budgetMinor > 0,
    );
  }
}

class BudgetProgress {
  const BudgetProgress({
    required this.spentMinor,
    required this.remainingMinor,
    required this.dailyBudgetMinor,
    required this.percent,
    required this.overThreshold,
    required this.exceeded,
  });

  final int spentMinor;
  final int remainingMinor;
  final int dailyBudgetMinor;
  final int percent;
  final bool overThreshold;
  final bool exceeded;
}
