import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/features/reports/charts/report_charts.dart';

void main() {
  group('periodAxisLabels', () {
    test('日对比（周一…周日）：原样单行', () {
      const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      expect(periodAxisLabels(days), [
        for (final w in days) (top: null, main: w),
      ]);
    });

    test('周对比（周一日期）：归一为 M/D，兼容新旧源格式', () {
      expect(periodAxisLabels(['08-03 周', '08-10 周']), [
        (top: null, main: '8/3'),
        (top: null, main: '8/10'),
      ]);
      expect(periodAxisLabels(['7/6', '8/3']), [
        (top: null, main: '7/6'),
        (top: null, main: '8/3'),
      ]);
    });

    test('月对比（同年）：主标签「M月」，年份仅首桶顶行一次', () {
      expect(
        periodAxisLabels(['2026-04', '2026-05', '2026-06', '2026-07', '2026-08']),
        [
          (top: '2026', main: '4月'),
          (top: null, main: '5月'),
          (top: null, main: '6月'),
          (top: null, main: '7月'),
          (top: null, main: '8月'),
        ],
      );
      // 稀疏月（仅有数据的桶）同规则
      expect(periodAxisLabels(['2026-02', '2026-05', '2026-11']), [
        (top: '2026', main: '2月'),
        (top: null, main: '5月'),
        (top: null, main: '11月'),
      ]);
    });

    test('月对比（跨年）：年份变化处再次顶行标注', () {
      expect(periodAxisLabels(['2025-11', '2025-12', '2026-01', '2026-02']), [
        (top: '2025', main: '11月'),
        (top: null, main: '12月'),
        (top: '2026', main: '1月'),
        (top: null, main: '2月'),
      ]);
    });

    test('年对比（纯年份）与未知格式原样单行', () {
      const years = ['2022', '2023', '2024', '2025', '2026'];
      expect(periodAxisLabels(years), [
        for (final y in years) (top: null, main: y),
      ]);
      expect(periodAxisLabels(['未知']), [(top: null, main: '未知')]);
    });
  });
}
