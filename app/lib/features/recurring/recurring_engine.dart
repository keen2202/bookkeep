import 'anchor_resolver.dart';

/// 周期规则（与 recurring_rules 表字段对应）
class RecurringRuleSpec {
  const RecurringRuleSpec({
    required this.frequency,
    required this.interval,
    required this.anchorType,
    required this.anchorDay,
    required this.startDate,
    this.endDate,
  });

  final RecurringFrequency frequency;
  final int interval;
  final AnchorType anchorType;
  final int anchorDay;
  final DateTime startDate;
  final DateTime? endDate;
}

/// 到期事件
class DueEvent {
  const DueEvent({required this.ruleId, required this.dueDate});
  final int ruleId;
  final DateTime dueDate;

  /// 幂等去重键（rule_id + due_date，Spec §4.4）
  String dedupKey() => '$ruleId|${dueDate.year}-${dueDate.month}-${dueDate.day}';
}

/// 周期展开引擎（Spec §4.4 / BK-T-013）：
/// 纯函数计算到期集合；锚点经 AnchorResolver 统一解析（锚点语义不下沉 UI）；
/// 季度 = MONTHLY;INTERVAL=3 等价展开，跨年自然衔接。
class RecurringEngine {
  const RecurringEngine();

  /// [start, end) 内的全部到期日（含规则起始日所在周期）
  List<DateTime> expandDates(RecurringRuleSpec spec, DateTime start, DateTime end) {
    final result = <DateTime>[];
    // 从规则起始日所在周期的起点开始按 interval 步进
    var period = AnchorResolver.periodStart(spec.frequency, spec.startDate);
    final endDate = spec.endDate;
    while (period.isBefore(end)) {
      if (endDate != null && period.isAfter(endDate)) break;
      final due = AnchorResolver.resolveInPeriod(
        spec.frequency,
        spec.anchorType,
        spec.anchorDay,
        period,
      );
      // 锚点落在规则起始日或展开窗口起点之前则跳过
      // （窗口起点即补跑游标 nextDue，保证幂等不重复生成）
      if (!due.isBefore(spec.startDate) && !due.isBefore(start)) {
        result.add(due);
      }
      // interval 步进（季度 = 3 个月）
      for (var i = 0; i < spec.interval; i++) {
        period = AnchorResolver.nextPeriod(spec.frequency, period);
      }
    }
    return result;
  }

  /// 补跑：自 nextDue（含）至 now 的全部到期日；幂等由调用方以
  /// (rule_id, due_date) 去重（Spec §4.4 启动补跑 + 幂等去重）。
  List<DateTime> catchUp(RecurringRuleSpec spec, DateTime nextDue, DateTime now) {
    return expandDates(spec, nextDue, now.add(const Duration(days: 1)));
  }
}

/// 等额分期（Spec §4.4）：总额按期数均分，舍入误差由末笔补差，分期合计 = 总额（误差 0）。
class InstallmentCalculator {
  const InstallmentCalculator();

  /// 返回每期金额（分）；末笔 = 总额 - 前 n-1 期之和
  List<int> schedule(int totalMinor, int periods) {
    if (periods <= 0) return const [];
    final base = totalMinor ~/ periods;
    final remainder = totalMinor - base * periods;
    return [
      for (var i = 0; i < periods; i++) i == periods - 1 ? base + remainder : base,
    ];
  }
}
