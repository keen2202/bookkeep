import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/money_format.dart';
import '../../../data/repositories/reports_repository.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/theme/chart_colors.dart';

/// 图表通用网格线（Glassmorphism v3，Spec §5.4 / GLS-007）：
/// `palette.divider` α0.5，刻度清晰度不受画质档影响。
FlGridData glassGridData(BuildContext context, {bool vertical = false}) {
  final color = context.palette.divider.withValues(alpha: 0.5);
  return FlGridData(
    show: true,
    drawVerticalLine: vertical,
    getDrawingHorizontalLine: (_) => FlLine(color: color, strokeWidth: 1),
    getDrawingVerticalLine: (_) => FlLine(color: color, strokeWidth: 1),
  );
}

/// 「光透过图表」语义色渐变（Spec §5.4）：柱/折线下方 α0.12 → 0，
/// 不受画质档影响（标准档图表玻璃感三支柱之一）
LinearGradient chartAreaGradient(Color color) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0)],
    );

/// X 轴标签压缩：桶间「共有」的部分对区分各桶没有贡献（跨年对比的同期后缀、
/// 同年的年份前缀），剥离后仅保留区分维度，避免长日期标签在窄屏上相互重叠。
/// - 跨年对比（各桶年份不同、同期相同）→ 仅保留年份：`2021-08-09` → `2021`；
/// - 按月分桶（自定义范围，含跨年）→ 仅保留月：`2026-01` → `01`；
/// - 其余（如「年」对比、按周）→ 保持原样。
List<String> compactPeriodAxisLabels(List<String> labels) {
  if (labels.length < 2) return List.of(labels);
  final suffix = _commonSuffix(labels);
  final yearPrefixed = labels.every(_startsWithYear);
  // 跨年对比：年份变化、同期后缀固定 → 保留年份
  if (yearPrefixed && suffix.length >= 2) {
    return [
      for (final l in labels) l.substring(0, l.length - suffix.length),
    ];
  }
  // 按月分桶（YYYY-MM…）：剥离「YYYY-」年份前缀，保留月份
  if (yearPrefixed && labels.every(_hasYearSeparator)) {
    return [for (final l in labels) l.substring(5)];
  }
  return List.of(labels);
}

bool _startsWithYear(String label) {
  if (label.length < 4) return false;
  return int.tryParse(label.substring(0, 4)) != null;
}

bool _hasYearSeparator(String label) =>
    label.length > 4 && label.codeUnitAt(4) == 0x2D; // '-'

String _commonSuffix(List<String> labels) {
  final first = labels.first;
  var len = 0;
  while (len < first.length) {
    final c = first[first.length - 1 - len];
    if (labels.any((l) => len >= l.length || l[l.length - 1 - len] != c)) break;
    len++;
  }
  return first.substring(first.length - len);
}

/// 分类占比饼图（Spec §3.5；审查 U-11：扇区仅百分比，金额进外置图例；
/// 脱敏态图例金额脱敏）。序列色自 palette/语义色派生（UI 重构 BK-UI-007）
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key, required this.slices, required this.hideAmounts});

  final List<CategorySlice> slices;
  final bool hideAmounts;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
    final series = chartSeriesColors(context);
    final total = slices.fold<int>(0, (a, b) => a + b.amountMinor);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (var i = 0; i < slices.length; i++)
                  PieChartSectionData(
                    value: slices[i].amountMinor.toDouble(),
                    color: series[i % series.length],
                    title: hideAmounts
                        ? null
                        : total <= 0
                            ? null
                            : '${(slices[i].amountMinor * 100 ~/ total)}%',
                    titleStyle: context.text.bodySmall?.copyWith(
                      color: onColorFor(series[i % series.length]),
                    ),
                    radius: 64,
                  ),
              ],
            ),
          ),
        ),
        // 外置图例：色块 + 分类名 + 金额（脱敏态显示 ***）
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < slices.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: series[i % series.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${slices[i].categoryName} '
                    '${hideAmounts ? '***' : formatMoney(slices[i].amountMinor)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// 周期对比柱状图（Spec §3.5；审查 U-11：touch 开启 + tooltip 金额格式化 + 可读刻度）
class PeriodBarChart extends StatelessWidget {
  const PeriodBarChart({super.key, required this.buckets, required this.hideAmounts});

  final List<PeriodBucket> buckets;
  final bool hideAmounts;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
    final series = chartSeriesColors(context);
    final axisStyle = context.text.bodySmall;
    final maxAmount = buckets.fold<int>(0, (a, b) => a > b.amountMinor ? a : b.amountMinor);
    // x/y 轴比例均衡：显式「好看」刻度步长（约 4 档），避免 fl_chart 默认间隔
    // 在极端量级下产生过密刻度或柱高与刻度错位的观感
    final yInterval = niceAxisStep((maxAmount == 0 ? 1 : maxAmount) * 1.2 / 4);
    final axisLabels = compactPeriodAxisLabels([
      for (final b in buckets) b.label,
    ]);
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          // 跨年对比允许某年无数据（0 柱）；maxY 兜底避免 0 刻度
          maxY: (maxAmount == 0 ? 1 : maxAmount).toDouble() * 1.2,
          // v3 网格线：divider α0.5（GLS-007，刻度不受档位影响）
          gridData: glassGridData(context),
          barTouchData: BarTouchData(
            enabled: !hideAmounts,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(formatMoney(rod.toY.round()), const TextStyle()),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: hideAmounts
                ? const AxisTitles(sideTitles: SideTitles(showTitles: false))
                : AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        if (value <= 0) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          space: 4,
                          child: Text(compactTickLabel(value.round()), style: axisStyle),
                        );
                      },
                    ),
                  ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= buckets.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(axisLabels[index], style: axisStyle),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < buckets.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: buckets[i].amountMinor.toDouble(),
                  // 「光透过图表」：柱身自上而下语义色 → α0.12 渐变（GLS-007）
                  gradient: chartAreaGradient(series[i % series.length]),
                  width: 16,
                  borderRadius: BorderRadius.circular(2),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

/// 收支趋势折线图（Spec §3.5；审查 U-11：tooltip 金额格式化 + 可读刻度）。
/// 修正：单日（「日」维度）折线无法绘制时直接展示收支汇总；
/// 采样步长取整；x 轴带日期标签；tooltip 显示日期。
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.totals,
    required this.hideAmounts,
    this.maxPoints = 60,
  });

  final List<DailyTotal> totals;
  final bool hideAmounts;
  final int maxPoints;

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
    // 收支语义色（UI 重构 BK-UI-007：序列色语义化，浅深主题锁定）
    final expenseColor = context.appColors.expense;
    final incomeColor = context.appColors.income;
    final axisStyle = context.text.bodySmall;
    final sampled = totals.length > maxPoints
        ? [
            for (var i = 0; i < totals.length; i += (totals.length / maxPoints).ceil())
              totals[i],
          ]
        : totals;
    // 单日（如「日」维度）：折线至少需 2 点，单日直接展示收支汇总（与记录一致）
    if (sampled.length < 2) {
      final t = sampled.single;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${t.date}  支出 ${hideAmounts ? '***' : formatMoney(t.expenseMinor)}'),
          Text('${t.date}  收入 ${hideAmounts ? '***' : formatMoney(t.incomeMinor)}'),
        ],
      );
    }
    final expense = <FlSpot>[
      for (var i = 0; i < sampled.length; i++)
        FlSpot(i.toDouble(), sampled[i].expenseMinor.toDouble()),
    ];
    final income = <FlSpot>[
      for (var i = 0; i < sampled.length; i++)
        FlSpot(i.toDouble(), sampled[i].incomeMinor.toDouble()),
    ];
    final maxY = [
      for (final s in expense) s.y,
      for (final s in income) s.y,
    ].fold<double>(0, (a, b) => a > b ? a : b) * 1.2;
    final labelStep = (sampled.length / 6).ceil().clamp(1, 99);
    final yInterval = niceAxisStep(maxY / 4);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          maxY: maxY,
          minY: 0,
          lineTouchData: LineTouchData(
            enabled: !hideAmounts,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${sampled[s.spotIndex].date}\n${formatMoney(s.y.round())}',
                    TextStyle(
                      color: s.barIndex == 0 ? expenseColor : incomeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          gridData: glassGridData(context),
          titlesData: FlTitlesData(
            leftTitles: hideAmounts
                ? const AxisTitles(sideTitles: SideTitles(showTitles: false))
                : AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        if (value <= 0) return const SizedBox.shrink();
                        return Text(compactTickLabel(value.round()), style: axisStyle);
                      },
                    ),
                  ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= sampled.length) return const SizedBox.shrink();
                  if (index % labelStep != 0 && index != sampled.length - 1) {
                    return const SizedBox.shrink();
                  }
                  final parts = sampled[index].date.split('-');
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${parts[1]}-${parts[2]}', style: axisStyle),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: expense,
              color: expenseColor,
              barWidth: 2,
              isCurved: true,
              dotData: const FlDotData(show: false),
              // 「光透过图表」：线下语义色 α0.12→0 渐变填充（GLS-007）
              belowBarData: BarAreaData(
                show: true,
                gradient: chartAreaGradient(expenseColor),
              ),
            ),
            LineChartBarData(
              spots: income,
              color: incomeColor,
              barWidth: 2,
              isCurved: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: chartAreaGradient(incomeColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
