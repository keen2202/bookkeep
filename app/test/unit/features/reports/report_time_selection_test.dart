import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/repositories/reports_repository.dart';
import 'package:bookkeep_app/features/reports/reports_page.dart';

void main() {
  group('ReportTimeSelection 粒度 / 窗口 / 标签', () {
    test('首次进入 = 今年 → 年粒度、整年窗口、标签「YYYY年」', () {
      final s = ReportTimeSelection.thisYear(DateTime(2026, 9, 3, 14, 20));
      expect(s.year, 2026);
      expect(s.month, isNull);
      expect(s.day, isNull);
      expect(s.range, ReportRange.year);
      expect(s.label, '2026年');
      expect(s.window, (start: DateTime(2026), end: DateTime(2027)));
      // 月为「全部」→ 无确定天数，日列禁用
      expect(s.daysInMonth, isNull);
    });

    test('年+月 → 月粒度、整月窗口、标签「YYYY年M月」', () {
      const s = ReportTimeSelection(year: 2026, month: 9);
      expect(s.range, ReportRange.month);
      expect(s.label, '2026年9月');
      expect(s.window, (start: DateTime(2026, 9), end: DateTime(2026, 10)));
      expect(s.daysInMonth, 30);
    });

    test('年+月+日 → 日粒度、单日窗口、标签「YYYY年M月D日」', () {
      const s = ReportTimeSelection(year: 2026, month: 9, day: 2);
      expect(s.range, ReportRange.day);
      expect(s.label, '2026年9月2日');
      expect(s.window, (start: DateTime(2026, 9, 2), end: DateTime(2026, 9, 3)));
    });

    test('12 月窗口跨年正确（end = 次年 1/1）', () {
      const s = ReportTimeSelection(year: 2026, month: 12);
      expect(s.window, (start: DateTime(2026, 12), end: DateTime(2027)));
      expect(s.daysInMonth, 31);
    });
  });

  group('ReportTimeSelection 滚轮联动矩阵（AC3-2 / AC3-5）', () {
    test('年变化 → 月保留、日重置「全部」', () {
      const s = ReportTimeSelection(year: 2026, month: 9, day: 2);
      final next = s.selectYear(2025);
      expect(next, const ReportTimeSelection(year: 2025, month: 9));
      expect(next.range, ReportRange.month);
    });

    test('年变化时月为「全部」→ 仍是年粒度', () {
      const s = ReportTimeSelection(year: 2026);
      expect(s.selectYear(2027), const ReportTimeSelection(year: 2027));
      expect(s.selectYear(2027).range, ReportRange.year);
    });

    test('月变化 → 日重置「全部」', () {
      const s = ReportTimeSelection(year: 2026, month: 9, day: 15);
      expect(s.selectMonth(10), const ReportTimeSelection(year: 2026, month: 10));
    });

    test('月改为「全部」→ 日重置且回到年粒度', () {
      const s = ReportTimeSelection(year: 2026, month: 9, day: 15);
      final next = s.selectMonth(null);
      expect(next, const ReportTimeSelection(year: 2026));
      expect(next.range, ReportRange.year);
      expect(next.daysInMonth, isNull);
    });

    test('月为「全部」时日列禁用：selectDay 被忽略', () {
      const s = ReportTimeSelection(year: 2026);
      expect(s.selectDay(5), s);
      expect(s.selectDay(5).range, ReportRange.year);
    });

    test('日列：选日 → 日粒度；选「全部」→ 回月粒度', () {
      const s = ReportTimeSelection(year: 2026, month: 9);
      final picked = s.selectDay(3);
      expect(picked, const ReportTimeSelection(year: 2026, month: 9, day: 3));
      expect(picked.range, ReportRange.day);
      expect(picked.selectDay(null), s);
      expect(picked.selectDay(null).range, ReportRange.month);
    });

    test('闰年 2 月日列联动 29 天，平年 2 月 28 天', () {
      expect(const ReportTimeSelection(year: 2028, month: 2).daysInMonth, 29);
      expect(const ReportTimeSelection(year: 2024, month: 2).daysInMonth, 29);
      expect(const ReportTimeSelection(year: 2027, month: 2).daysInMonth, 28);
      expect(const ReportTimeSelection(year: 2026, month: 1).daysInMonth, 31);
      expect(const ReportTimeSelection(year: 2026, month: 4).daysInMonth, 30);
    });

    test('闰日 2/29 改年到平年 → 日重置，不产生非法日期', () {
      const leap = ReportTimeSelection(year: 2028, month: 2, day: 29);
      expect(leap.window,
          (start: DateTime(2028, 2, 29), end: DateTime(2028, 3, 1)));
      final common = leap.selectYear(2027);
      expect(common.day, isNull);
      expect(common.daysInMonth, 28);
      expect(common.window, (start: DateTime(2027, 2), end: DateTime(2027, 3)));
    });

    test('年列范围与日历 firstDay/lastDay、日期选择器边界一致', () {
      expect(ReportTimeSelection.firstYear, 2020);
      expect(ReportTimeSelection.lastYear, 2035);
    });
  });
}
