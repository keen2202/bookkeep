import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/features/reports/charts/report_charts.dart';

void main() {
  group('compactPeriodAxisLabels', () {
    test('最近7天（MM-DD）：无冗余公共部分，保持原样', () {
      expect(
        compactPeriodAxisLabels(
            ['08-03', '08-04', '08-05', '08-06', '08-07', '08-08', '08-09']),
        ['08-03', '08-04', '08-05', '08-06', '08-07', '08-08', '08-09'],
      );
    });

    test('最近5周（MM-DD 周）：保持原样', () {
      expect(
        compactPeriodAxisLabels(['07-06 周', '07-13 周', '07-20 周', '07-27 周', '08-03 周']),
        ['07-06 周', '07-13 周', '07-20 周', '07-27 周', '08-03 周'],
      );
    });

    test('同年多桶：剥离年份前缀，仅保留月', () {
      expect(
        compactPeriodAxisLabels(['2026-04', '2026-05', '2026-06', '2026-07', '2026-08']),
        ['04', '05', '06', '07', '08'],
      );
      // 仅有数据的稀疏月也保持两位月份
      expect(
        compactPeriodAxisLabels(['2026-02', '2026-05', '2026-11']),
        ['02', '05', '11'],
      );
    });

    test('跨年连续月：剥离年份前缀保留月（顺序表达跨年）', () {
      expect(
        compactPeriodAxisLabels(['2025-11', '2025-12', '2026-01', '2026-02']),
        ['11', '12', '01', '02'],
      );
    });

    test('年对比（纯年份）保持原样', () {
      expect(
        compactPeriodAxisLabels(['2022', '2023', '2024', '2025', '2026']),
        ['2022', '2023', '2024', '2025', '2026'],
      );
    });

    test('单桶无需压缩', () {
      expect(compactPeriodAxisLabels(['2026-08']), ['2026-08']);
    });
  });
}
