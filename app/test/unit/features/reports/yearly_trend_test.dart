import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/repositories/reports_repository.dart';
import 'package:bookkeep_app/features/reports/reports_page.dart';

PeriodBucket bucket(String label, {int expense = 0, int income = 0}) =>
    PeriodBucket(label: label, expenseMinor: expense, incomeMinor: income);

void main() {
  group('yearlyTrendBuckets 补零（AC9-2 / AC9-3）', () {
    test('空年（repo 无桶）→ 空列表走「暂无数据」空态，而非 12 根 0 柱', () {
      expect(yearlyTrendBuckets(2026, const []), isEmpty);
    });

    test('部分月 → 固定 12 桶、缺失月补 0、label 为 YYYY-MM 且按月升序', () {
      final filled = yearlyTrendBuckets(2026, [
        // repo 按 GROUP BY 返回，顺序不保证；补零后必须重排为 1–12 月
        bucket('2026-09', expense: 3000, income: 5000),
        bucket('2026-02', expense: 1200),
      ]);

      expect(filled, hasLength(12));
      expect(
        [for (final b in filled) b.label],
        [for (var m = 1; m <= 12; m++) '2026-${m.toString().padLeft(2, '0')}'],
      );
      expect(filled[1].expenseMinor, 1200);
      expect(filled[1].incomeMinor, 0);
      expect(filled[8].expenseMinor, 3000);
      expect(filled[8].incomeMinor, 5000);
      // 缺失月为 0 值桶（渲染 0 柱，不断档）
      expect(filled[0].expenseMinor, 0);
      expect(filled[0].incomeMinor, 0);
      expect(filled[11].expenseMinor, 0);
    });

    test('全月有数据 → 原样 12 桶，不丢金额', () {
      final sparse = [
        for (var m = 1; m <= 12; m++)
          bucket('2026-${m.toString().padLeft(2, '0')}',
              expense: m * 100, income: m * 50),
      ];
      final filled = yearlyTrendBuckets(2026, sparse);

      expect(filled, hasLength(12));
      expect(filled.first.expenseMinor, 100);
      expect(filled.last.expenseMinor, 1200);
      expect(filled.last.incomeMinor, 600);
    });

    test('跨年桶不属于选中年 → 被忽略（窗口过滤由 repo 负责，此处防错标）', () {
      final filled = yearlyTrendBuckets(2026, [
        bucket('2025-12', expense: 900),
        bucket('2026-01', expense: 100),
      ]);

      expect(filled, hasLength(12));
      expect(filled[0].expenseMinor, 100);
      expect(filled[11].expenseMinor, 0);
    });

    test('未来年份无流水 → 空态（Spec §2.9 边界：允许选择 2027 等未来年）', () {
      expect(yearlyTrendBuckets(2035, const []), isEmpty);
    });
  });
}
