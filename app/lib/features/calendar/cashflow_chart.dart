import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money_format.dart';
import '../auth_lock/lock_controller.dart';
import 'calendar_page.dart' show calendarDailyTotalsProvider;

/// 现金流趋势（Spec §4.6 / BK-T-015）：以选中日为锚点的 30 天滑动窗口日净额折线。
/// 复用报表按日聚合查询层，与报表同区间口径一致。
///
/// 显示修复：
/// - 补 y 轴可读刻度与 x 轴日期刻度（此前全部隐藏，正负/量级不可读）；
/// - 补零轴基线（虚线），正负区间一目了然；
/// - 面积填充以零轴为界（cutOffY），不再把负净额填充到图表底部造成误读；
/// - 触摸显示「日期 + 当日净额」tooltip；脱敏态不绘制真实曲线（坐标
///   量级会泄露金额），改为占位展示。
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
        final byDay = {for (final t in list) t.date: t.incomeMinor - t.expenseMinor};
        final points = <FlSpot>[];
        var maxAbs = 0;
        for (var i = 0; i < 30; i++) {
          final d = start.add(Duration(days: i));
          final net = byDay[_dayKey(d)] ?? 0;
          if (net.abs() > maxAbs) maxAbs = net.abs();
          points.add(FlSpot(i.toDouble(), net.toDouble()));
        }
        final title = _isAnchorToday
            ? '近 30 天现金流'
            : '近 30 天现金流（截至 ${day.month}月${day.day}日）';
        // 无任何收支的窗口：空态而非一条贴底的假曲线
        if (maxAbs == 0) {
          return _shell(context, title, const Center(child: Text('暂无数据')));
        }
        // 审查 U-8：脱敏态坐标尺度会经量级泄露真实金额——不绘制曲线，仅占位
        if (masked) {
          return _shell(
            context,
            title,
            Center(
              // 脱敏占位走字阶 Token（静态卡点禁裸字号）
              child: Text('***',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
            ),
          );
        }

        final theme = Theme.of(context);
        final axisStyle = theme.textTheme.bodySmall;
        final bound = maxAbs * 1.2;
        final yInterval = niceAxisStep(bound * 2 / 4);

        return _shell(
          context,
          title,
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: -bound,
                maxY: bound,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        space: 4,
                        child: Text(compactTickLabel(value.round()), style: axisStyle),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 7,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index > 29 || value % 7 != 0) {
                          return const SizedBox.shrink();
                        }
                        final d = start.add(Duration(days: index));
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('${d.month}/${d.day}', style: axisStyle),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                // 零轴基线：区分净流入/流出区间
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 0,
                      color: theme.colorScheme.outline,
                      strokeWidth: 1,
                      dashArray: const [4, 4],
                    ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: points,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: theme.colorScheme.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      cutOffY: 0,
                      applyCutOffY: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${_md(start.add(Duration(days: s.x.toInt())))}'
                          ' 净额 ${formatMoney(s.y.round())}',
                          TextStyle(
                            color: s.y >= 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      orElse: () => const SizedBox.shrink(),
    );
  }

  bool get _isAnchorToday {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  Widget _shell(BuildContext context, String title, Widget child) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  String _md(DateTime d) => '${d.month}/${d.day}';

  String _dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
