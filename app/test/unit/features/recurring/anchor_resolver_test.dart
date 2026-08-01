import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/features/recurring/anchor_resolver.dart';
import 'package:bookkeep_app/features/recurring/recurring_engine.dart';

void main() {
  group('AnchorResolver 全频率×全锚点矩阵（Spec §4.4）', () {
    test('月：月初/月中/月末/自定义（含 31 日回退到 2 月）', () {
      final feb = DateTime(2026, 2);
      expect(AnchorResolver.resolveInPeriod(RecurringFrequency.month, AnchorType.start, 0, feb),
          DateTime(2026, 2, 1));
      expect(AnchorResolver.resolveInPeriod(RecurringFrequency.month, AnchorType.middle, 0, feb),
          DateTime(2026, 2, 15));
      expect(AnchorResolver.resolveInPeriod(RecurringFrequency.month, AnchorType.end, 0, feb),
          DateTime(2026, 2, 28));
      expect(AnchorResolver.resolveInPeriod(RecurringFrequency.month, AnchorType.custom, 31, feb),
          DateTime(2026, 2, 28)); // 31 日回退
    });

    test('月：闰年 2 月末 = 2 月 29 日', () {
      expect(
          AnchorResolver.resolveInPeriod(
              RecurringFrequency.month, AnchorType.end, 0, DateTime(2028, 2)),
          DateTime(2028, 2, 29));
      expect(
          AnchorResolver.resolveInPeriod(
              RecurringFrequency.month, AnchorType.custom, 31, DateTime(2028, 2)),
          DateTime(2028, 2, 29));
    });

    test('季：季度初 = 季度首月 1 日（1/4/7/10 月）', () {
      for (final q in [1, 4, 7, 10]) {
        final due = AnchorResolver.resolveInPeriod(
            RecurringFrequency.quarter, AnchorType.start, 0, DateTime(2026, q));
        expect(due, DateTime(2026, q, 1));
      }
    });

    test('季：季度中 = 季度次月 15 日（2/5/8/11 月）', () {
      for (final q in [1, 4, 7, 10]) {
        final due = AnchorResolver.resolveInPeriod(
            RecurringFrequency.quarter, AnchorType.middle, 0, DateTime(2026, q));
        expect(due, DateTime(2026, q + 1, 15));
      }
    });

    test('季：季度末 = 季度末月最后一日（3/6/9/12 月最后一日）', () {
      expect(
          AnchorResolver.resolveInPeriod(
              RecurringFrequency.quarter, AnchorType.end, 0, DateTime(2026, 1)),
          DateTime(2026, 3, 31));
      expect(
          AnchorResolver.resolveInPeriod(
              RecurringFrequency.quarter, AnchorType.end, 0, DateTime(2026, 4)),
          DateTime(2026, 6, 30));
      expect(
          AnchorResolver.resolveInPeriod(
              RecurringFrequency.quarter, AnchorType.end, 0, DateTime(2026, 10)),
          DateTime(2026, 12, 31));
    });

    test('年：年初/年中/年末/自定义', () {
      expect(AnchorResolver.resolveInPeriod(RecurringFrequency.year, AnchorType.start, 0, DateTime(2026)),
          DateTime(2026, 1, 1));
      expect(AnchorResolver.resolveInPeriod(RecurringFrequency.year, AnchorType.middle, 0, DateTime(2026)),
          DateTime(2026, 7, 1));
      expect(AnchorResolver.resolveInPeriod(RecurringFrequency.year, AnchorType.end, 0, DateTime(2026)),
          DateTime(2026, 12, 31));
      expect(
          AnchorResolver.resolveInPeriod(
              RecurringFrequency.year, AnchorType.custom, 5, DateTime(2026)),
          DateTime(2026, 1, 5));
    });

    test('周：周一~周日', () {
      // 2026-08-03 是周一
      final monday = DateTime(2026, 8, 3);
      expect(
          AnchorResolver.resolveInPeriod(RecurringFrequency.week, AnchorType.custom, 1, monday),
          DateTime(2026, 8, 3));
      expect(
          AnchorResolver.resolveInPeriod(RecurringFrequency.week, AnchorType.custom, 7, monday),
          DateTime(2026, 8, 9));
    });
  });

  group('RecurringEngine 展开（RRULE 子集语义）', () {
    const engine = RecurringEngine();

    RecurringRuleSpec spec({
      required RecurringFrequency frequency,
      AnchorType anchor = AnchorType.start,
      int anchorDay = 1,
      int interval = 1,
      required DateTime start,
      DateTime? end,
    }) {
      return RecurringRuleSpec(
        frequency: frequency,
        interval: interval,
        anchorType: anchor,
        anchorDay: anchorDay,
        startDate: start,
        endDate: end,
      );
    }

    test('月频：月末锚点 2 月边界（31 日回退）', () {
      final dates = engine.expandDates(
        spec(frequency: RecurringFrequency.month, anchor: AnchorType.end, start: DateTime(2026, 1, 31)),
        DateTime(2026, 1),
        DateTime(2026, 4),
      );
      expect(dates, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28), // 2 月回退
        DateTime(2026, 3, 31),
      ]);
    });

    test('季频：Q4 → Q1 跨年展开正确（季度初 = 1/4/7/10 月 1 日）', () {
      final dates = engine.expandDates(
        spec(frequency: RecurringFrequency.quarter, anchor: AnchorType.start, start: DateTime(2026, 10, 1)),
        DateTime(2026, 10),
        DateTime(2027, 7),
      );
      expect(dates, [
        DateTime(2026, 10, 1),
        DateTime(2027, 1, 1),
        DateTime(2027, 4, 1),
      ]);
    });

    test('季频：季度中跨年（2/5/8/11 月 15 日）', () {
      final dates = engine.expandDates(
        spec(frequency: RecurringFrequency.quarter, anchor: AnchorType.middle, start: DateTime(2026, 11, 15)),
        DateTime(2026, 11),
        DateTime(2027, 9),
      );
      expect(dates, [
        DateTime(2026, 11, 15),
        DateTime(2027, 2, 15),
        DateTime(2027, 5, 15),
        DateTime(2027, 8, 15),
      ]);
    });

    test('季频：季度末连续 8 个季度无漂移（3/6/9/12 月最后一日）', () {
      final dates = engine.expandDates(
        spec(frequency: RecurringFrequency.quarter, anchor: AnchorType.end, start: DateTime(2025, 3, 31)),
        DateTime(2025, 3),
        DateTime(2027, 4),
      );
      expect(dates, [
        DateTime(2025, 3, 31),
        DateTime(2025, 6, 30),
        DateTime(2025, 9, 30),
        DateTime(2025, 12, 31),
        DateTime(2026, 3, 31),
        DateTime(2026, 6, 30),
        DateTime(2026, 9, 30),
        DateTime(2026, 12, 31),
        DateTime(2027, 3, 31),
      ]);
      // 相邻间隔漂移为 0（月度等价展开稳定）
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].difference(dates[i - 1]).inDays, inInclusiveRange(88, 92));
      }
    });

    test('年频：自定义锚点 = 1 月第 N 日（闰年 2 月末由月频月末锚点测试覆盖）', () {
      final dates = engine.expandDates(
        spec(
          frequency: RecurringFrequency.year,
          anchor: AnchorType.custom,
          anchorDay: 29,
          start: DateTime(2028, 1, 29),
        ),
        DateTime(2028),
        DateTime(2031),
      );
      expect(dates, [DateTime(2028, 1, 29), DateTime(2029, 1, 29), DateTime(2030, 1, 29)]);
    });

    test('interval=3 与季频等价（MONTHLY;INTERVAL=3）', () {
      final viaQuarter = engine.expandDates(
        spec(frequency: RecurringFrequency.quarter, anchor: AnchorType.start, start: DateTime(2026, 1, 1)),
        DateTime(2026, 1),
        DateTime(2027, 1),
      );
      final viaMonthly3 = engine.expandDates(
        spec(
          frequency: RecurringFrequency.month,
          interval: 3,
          anchor: AnchorType.start,
          start: DateTime(2026, 1, 1),
        ),
        DateTime(2026, 1),
        DateTime(2027, 1),
      );
      expect(viaQuarter, viaMonthly3);
    });

    test('结束条件：end_date 之后不再展开', () {
      final dates = engine.expandDates(
        spec(
          frequency: RecurringFrequency.month,
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 3, 1),
        ),
        DateTime(2026, 1),
        DateTime(2026, 12),
      );
      expect(dates, [DateTime(2026, 1, 1), DateTime(2026, 2, 1), DateTime(2026, 3, 1)]);
    });
  });

  group('InstallmentCalculator（等额末笔补差）', () {
    const calc = InstallmentCalculator();

    test('整除：每期均等', () {
      expect(calc.schedule(10000, 4), [2500, 2500, 2500, 2500]);
    });

    test('不整除：末笔补差，合计 = 总额（误差 0）', () {
      final schedule = calc.schedule(10001, 3);
      expect(schedule, [3333, 3333, 3335]);
      expect(schedule.reduce((a, b) => a + b), 10001);
    });

    test('大额分期合计一致', () {
      final schedule = calc.schedule(1234567, 12);
      expect(schedule, hasLength(12));
      expect(schedule.reduce((a, b) => a + b), 1234567);
    });
  });
}
