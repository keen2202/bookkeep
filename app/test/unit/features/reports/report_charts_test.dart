import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/features/reports/charts/report_charts.dart';

void main() {
  group('compactPeriodAxisLabels', () {
    test('跨年对比：剥离同期后缀，仅保留年份', () {
      expect(
        compactPeriodAxisLabels(
            ['2021-08-09', '2022-08-09', '2023-08-09', '2024-08-09', '2025-08-09', '2026-08-09']),
        ['2021', '2022', '2023', '2024', '2025', '2026'],
      );
      expect(
        compactPeriodAxisLabels(['2021-08', '2022-08', '2023-08', '2024-08', '2025-08', '2026-08']),
        ['2021', '2022', '2023', '2024', '2025', '2026'],
      );
      expect(
        compactPeriodAxisLabels(['2021-W32', '2022-W32', '2023-W32', '2024-W32', '2025-W32', '2026-W32']),
        ['2021', '2022', '2023', '2024', '2025', '2026'],
      );
    });

    test('同年多桶：剥离年份前缀，仅保留月', () {
      expect(
        compactPeriodAxisLabels(
            ['2026-01', '2026-02', '2026-03', '2026-04', '2026-05', '2026-06']),
        ['01', '02', '03', '04', '05', '06'],
      );
      // 仅有数据的稀疏月也保持两位月份
      expect(
        compactPeriodAxisLabels(['2026-02', '2026-05', '2026-11']),
        ['02', '05', '11'],
      );
    });

    test('跨年按月分桶：剥离年份前缀，保留月（顺序表达跨年）', () {
      expect(
        compactPeriodAxisLabels(
            ['2026-10', '2026-11', '2026-12', '2027-01', '2027-02']),
        ['10', '11', '12', '01', '02'],
      );
    });

    test('年对比（纯年份）保持原样', () {
      expect(
        compactPeriodAxisLabels(['2021', '2022', '2023', '2024', '2025', '2026']),
        ['2021', '2022', '2023', '2024', '2025', '2026'],
      );
    });

    test('按周桶（MM-DD 周）保持原样', () {
      expect(
        compactPeriodAxisLabels(['08-03 周', '08-10 周', '08-17 周']),
        ['08-03 周', '08-10 周', '08-17 周'],
      );
    });

    test('单桶无需压缩', () {
      expect(compactPeriodAxisLabels(['2026-08']), ['2026-08']);
    });
  });
}
