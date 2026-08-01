/// 周期频率与锚点（Spec §4.4 / BK-T-013）：
/// 锚点语义集中于此（AnchorResolver），UI 不做日期推算。
enum RecurringFrequency { day, week, month, quarter, year }

enum AnchorType { start, middle, end, custom }

extension FrequencyLabel on RecurringFrequency {
  String get label => switch (this) {
        RecurringFrequency.day => '日',
        RecurringFrequency.week => '周',
        RecurringFrequency.month => '月',
        RecurringFrequency.quarter => '季',
        RecurringFrequency.year => '年',
      };
}

/// 锚点 → 具体日期（Spec §4.4）：
/// - 月：月初(1日)/月中(15日)/月末(最后一日)/自定义
/// - 季：季度初(季度首月1日)/季度中(季度次月15日)/季度末(季度末月最后一日)/自定义
///   （自然季度 Q1=1~3月、Q2=4~6月、Q3=7~9月、Q4=10~12月）
/// - 年：年初(1月1日)/年中(7月1日)/年末(12月31日)/自定义
/// - 周：周一~周日（anchorDay=1~7）；日：每天（anchorDay 忽略）
/// 季度以 MONTHLY;INTERVAL=3 等价展开：periodStart 按 3 个月步进。
abstract final class AnchorResolver {
  /// 当前周期起点（自然季度/自然月/自然周/自然年）
  static DateTime periodStart(RecurringFrequency frequency, DateTime now) {
    return switch (frequency) {
      RecurringFrequency.day => DateTime(now.year, now.month, now.day),
      RecurringFrequency.week =>
        DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1)),
      RecurringFrequency.month => DateTime(now.year, now.month),
      RecurringFrequency.quarter => DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1),
      RecurringFrequency.year => DateTime(now.year),
    };
  }

  /// 周期步进（季度 = 3 个月等价展开）
  static DateTime nextPeriod(RecurringFrequency frequency, DateTime periodStart) {
    return switch (frequency) {
      RecurringFrequency.day => periodStart.add(const Duration(days: 1)),
      RecurringFrequency.week => periodStart.add(const Duration(days: 7)),
      RecurringFrequency.month => DateTime(periodStart.year, periodStart.month + 1),
      RecurringFrequency.quarter => DateTime(periodStart.year, periodStart.month + 3),
      RecurringFrequency.year => DateTime(periodStart.year + 1),
    };
  }

  /// 锚点 → 周期内的具体到期日
  static DateTime resolveInPeriod(
    RecurringFrequency frequency,
    AnchorType anchorType,
    int anchorDay,
    DateTime periodStart,
  ) {
    switch (frequency) {
      case RecurringFrequency.day:
        return periodStart;
      case RecurringFrequency.week:
        // anchorDay：1=周一 … 7=周日；映射到周期（周一）内偏移
        final offset = (anchorDay - 1 + 7) % 7;
        return periodStart.add(Duration(days: offset));
      case RecurringFrequency.month:
        return _monthAnchor(periodStart, anchorType, anchorDay);
      case RecurringFrequency.quarter:
        final firstMonth = DateTime(periodStart.year, periodStart.month);
        final secondMonth = DateTime(periodStart.year, periodStart.month + 1);
        final lastMonth = DateTime(periodStart.year, periodStart.month + 2);
        return switch (anchorType) {
          // 季度初 = 季度首月 1 日
          AnchorType.start => firstMonth,
          // 季度中 = 季度次月 15 日
          AnchorType.middle => DateTime(secondMonth.year, secondMonth.month, 15),
          // 季度末 = 季度末月最后一日
          AnchorType.end => _lastDayOfMonth(lastMonth),
          AnchorType.custom => _dayInMonth(firstMonth, anchorDay),
        };
      case RecurringFrequency.year:
        return switch (anchorType) {
          AnchorType.start => DateTime(periodStart.year, 1, 1),
          AnchorType.middle => DateTime(periodStart.year, 7, 1),
          AnchorType.end => DateTime(periodStart.year, 12, 31),
          AnchorType.custom => _dayInMonth(DateTime(periodStart.year, 1), anchorDay),
        };
    }
  }

  static DateTime _monthAnchor(DateTime monthStart, AnchorType anchorType, int anchorDay) {
    return switch (anchorType) {
      AnchorType.start => monthStart, // 月初 1 日
      AnchorType.middle => DateTime(monthStart.year, monthStart.month, 15), // 月中 15 日
      AnchorType.end => _lastDayOfMonth(monthStart), // 月末最后一日
      AnchorType.custom => _dayInMonth(monthStart, anchorDay),
    };
  }

  /// 自定义日期：超月末时回退到月末（31 日 → 2 月 28/29 日）
  static DateTime _dayInMonth(DateTime monthStart, int day) {
    final last = _lastDayOfMonth(monthStart).day;
    return DateTime(monthStart.year, monthStart.month, day > last ? last : day);
  }

  static DateTime _lastDayOfMonth(DateTime monthStart) {
    return DateTime(monthStart.year, monthStart.month + 1, 0);
  }
}
