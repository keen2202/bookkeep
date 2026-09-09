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

    // BK-DOC-31 需求1：月维度收支趋势按日汇总的日桶
    test('日桶（YYYY-MM-DD）：主标签「D日」，不被月桶规则吞掉', () {
      expect(
        periodAxisLabels(['2026-08-01', '2026-08-15', '2026-08-31']),
        [
          (top: null, main: '1日'),
          (top: null, main: '15日'),
          (top: null, main: '31日'),
        ],
      );
    });
  });

  // BK-DOC-31 需求1：31 个日桶在窄屏下必须跳标，标签不互相重叠
  group('axisLabelInterval', () {
    test('桶数少/宽度足 → 每桶都标', () {
      expect(axisLabelInterval(320, 5), 1);
      expect(axisLabelInterval(320, 7), 1);
    });

    test('12 个月桶（320px）→ 每 2 月标一次（与既有行为一致）', () {
      expect(axisLabelInterval(320, 12), 2);
    });

    test('28~31 个日桶 → 跳标间隔 4，可见标签数 ≤ 9', () {
      for (final count in [28, 29, 30, 31]) {
        final step = axisLabelInterval(320, count);
        expect(step, 4);
        expect((count / step).ceil(), lessThanOrEqualTo(9));
      }
    });

    test('单桶/空桶 → 1（不跳标，避免除零）', () {
      expect(axisLabelInterval(320, 1), 1);
      expect(axisLabelInterval(320, 0), 1);
    });
  });
}
