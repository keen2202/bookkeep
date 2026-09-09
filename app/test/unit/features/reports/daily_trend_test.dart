import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/repositories/reports_repository.dart';
import 'package:bookkeep_app/features/reports/reports_page.dart';

PeriodBucket dayBucket(String label, {int expense = 0, int income = 0}) =>
    PeriodBucket(label: label, expenseMinor: expense, incomeMinor: income);

/// BK-DOC-31 需求1：月维度「收支趋势」按日汇总的补零逻辑（纯函数，可单测）
void main() {
  group('dailyTrendBuckets 补零（按日汇总）', () {
    test('空月（repo 无桶）→ 空列表走「暂无数据」空态', () {
      expect(dailyTrendBuckets(2026, 8, const []), isEmpty);
    });

    test('部分日期 → 固定当月天数桶、缺失日补 0、label 为 YYYY-MM-DD 且按日升序', () {
      final filled = dailyTrendBuckets(2026, 8, [
        // repo 按 GROUP BY 返回，顺序不保证；补零后必须重排为 1–31 日
        dayBucket('2026-08-31', expense: 3000, income: 5000),
        dayBucket('2026-08-02', expense: 1200),
      ]);

      expect(filled, hasLength(31));
      expect(
        [for (final b in filled) b.label],
        [for (var d = 1; d <= 31; d++) '2026-08-${d.toString().padLeft(2, '0')}'],
      );
      expect(filled[1].expenseMinor, 1200);
      expect(filled[1].incomeMinor, 0);
      expect(filled[30].expenseMinor, 3000);
      expect(filled[30].incomeMinor, 5000);
      // 缺失日为 0 值桶（渲染 0 点，折线不断档）
      expect(filled[0].expenseMinor, 0);
      expect(filled[0].incomeMinor, 0);
      expect(filled[15].expenseMinor, 0);
    });

    test('天数随年月自适应：2028-02 闰年 29 桶、2026-02 28 桶、4 月 30 桶', () {
      expect(
        dailyTrendBuckets(2028, 2, [dayBucket('2028-02-01', expense: 1)]),
        hasLength(29),
      );
      expect(
        dailyTrendBuckets(2026, 2, [dayBucket('2026-02-01', expense: 1)]),
        hasLength(28),
      );
      expect(
        dailyTrendBuckets(2026, 4, [dayBucket('2026-04-01', expense: 1)]),
        hasLength(30),
      );
    });

    test('跨月/跨年桶不属于选中月 → 被忽略（窗口过滤由 repo 负责，此处防错标）', () {
      final filled = dailyTrendBuckets(2026, 8, [
        dayBucket('2026-07-31', expense: 900),
        dayBucket('2027-08-05', expense: 700),
        dayBucket('2026-08-05', expense: 100),
      ]);

      expect(filled, hasLength(31));
      expect(filled[4].expenseMinor, 100);
      expect(filled.fold<int>(0, (a, b) => a + b.expenseMinor), 100);
    });

    test('未来月份无流水 → 空态（Spec 边界：允许选择未来年月）', () {
      expect(dailyTrendBuckets(2035, 12, const []), isEmpty);
    });
  });
}
