import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/features/recurring/anchor_resolver.dart';
import 'package:bookkeep_app/features/recurring/recurring_engine.dart';

void main() {
  const engine = RecurringEngine();

  RecurringRuleSpec spec({
    RecurringFrequency frequency = RecurringFrequency.month,
    int interval = 1,
    AnchorType anchorType = AnchorType.start,
    int anchorDay = 1,
    required DateTime startDate,
    DateTime? endDate,
  }) {
    return RecurringRuleSpec(
      frequency: frequency,
      interval: interval,
      anchorType: anchorType,
      anchorDay: anchorDay,
      startDate: startDate,
      endDate: endDate,
    );
  }

  group('firstDueAfter', () {
    test('月度 15 日锚点：当前已过锚点日 → 下月 15 日', () {
      final s = spec(
        anchorType: AnchorType.custom,
        anchorDay: 15,
        startDate: DateTime(2026, 8, 1),
      );
      final due = engine.firstDueAfter(s, DateTime(2026, 8, 20, 10));
      expect(due, DateTime(2026, 9, 15));
    });

    test('月度 15 日锚点：锚点日未到 → 当月 15 日', () {
      final s = spec(
        anchorType: AnchorType.custom,
        anchorDay: 15,
        startDate: DateTime(2026, 8, 1),
      );
      final due = engine.firstDueAfter(s, DateTime(2026, 8, 5, 10));
      expect(due, DateTime(2026, 8, 15));
    });

    test('月末锚点：31 日自定义回退到 2 月 28/29 日', () {
      final s = spec(
        anchorType: AnchorType.custom,
        anchorDay: 31,
        startDate: DateTime(2025, 1, 1),
      );
      // 平年 2 月 → 28 日
      expect(engine.firstDueAfter(s, DateTime(2026, 2, 1)), DateTime(2026, 2, 28));
      // 闰年 2 月 → 29 日
      expect(engine.firstDueAfter(s, DateTime(2028, 2, 1)), DateTime(2028, 2, 29));
    });

    test('周频率：锚点日已过 → 下一周对应日', () {
      final s = spec(
        frequency: RecurringFrequency.week,
        anchorType: AnchorType.custom,
        anchorDay: 3, // 周三
        startDate: DateTime(2026, 8, 3), // 周一
      );
      // 2026-08-05 是周三，now = 当周周四
      final due = engine.firstDueAfter(s, DateTime(2026, 8, 6, 10));
      expect(due, DateTime(2026, 8, 12));
    });

    test('年频率：跨年展开（400 天窗口覆盖约 366 天间隔）', () {
      final s = spec(
        frequency: RecurringFrequency.year,
        anchorType: AnchorType.start,
        startDate: DateTime(2026, 1, 1),
      );
      final due = engine.firstDueAfter(s, DateTime(2026, 6, 15));
      expect(due, DateTime(2027, 1, 1));
    });

    test('endDate 已过 → null（显示已结束）', () {
      final s = spec(
        anchorType: AnchorType.custom,
        anchorDay: 15,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 12, 31),
      );
      expect(engine.firstDueAfter(s, DateTime(2026, 1, 10)), isNull);
    });

    test('今天即到期日：now 时刻在到期日当天之后 → 下一期', () {
      final s = spec(
        anchorType: AnchorType.start,
        startDate: DateTime(2026, 8, 1),
      );
      // 2026-08-01 是到期日，now 已到当日 12 点 → 下月 1 日
      expect(engine.firstDueAfter(s, DateTime(2026, 8, 1, 12)), DateTime(2026, 9, 1));
    });
  });
}
