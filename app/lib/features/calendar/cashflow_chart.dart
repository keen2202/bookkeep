import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_lock/lock_controller.dart';
import 'calendar_page.dart' show calendarDailyTotalsProvider;

/// 现金流趋势（Spec §4.6 / BK-T-015）：以选中日为锚点的 30 天滑动窗口日净额折线。
/// 复用报表按日聚合查询层，与报表同区间口径一致。
class CashflowChart extends ConsumerWidget {
  const CashflowChart({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final end = DateTime(day.year, day.month, day.day).add(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 30));
    final totals = ref.watch(calendarDailyTotalsProvider((start: start, end: end)));
    final masked = ref.watch(amountMaskProvider);

    return totals.maybeWhen(
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('暂无数据'));
        }
        final byDay = {for (final t in list) t.date: t.incomeMinor - t.expenseMinor};
        final points = <FlSpot>[];
        var maxAbs = 1;
        for (var i = 0; i < 30; i++) {
          final d = start.add(Duration(days: i));
          final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}';
          final net = byDay[key] ?? 0;
          if (net.abs() > maxAbs) maxAbs = net.abs();
          points.add(FlSpot(i.toDouble(), net.toDouble()));
        }
        // 审查 U-8：脱敏态坐标尺度固定化——maxAbs 由真实数据推出，脱敏时
        // 若沿用会经坐标轴量级泄露真实金额，故锁定为固定尺度
        if (masked) maxAbs = 1;
        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('近 30 天现金流',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: LineChart(
                    LineChartData(
                      minY: -maxAbs.toDouble(),
                      maxY: maxAbs.toDouble(),
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      titlesData: const FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: masked ? const [FlSpot(0, 0)] : points,
                          isCurved: true,
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
