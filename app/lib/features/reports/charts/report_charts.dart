import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/money_format.dart';
import '../../../data/repositories/reports_repository.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/theme/chart_colors.dart';
import '../../../shared/theme/tokens.dart';

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

/// x 轴两行周期标签：top 为次级信息（年份，可空）、main 为主标签。
/// 主标签只保留区分维度，避免长日期在窄屏上相互重叠。
typedef PeriodAxisLabel = ({String? top, String main});

/// 周期标签渲染规则（与 reports_repository 的源标签格式一一对应）：
/// - 日（周一…周日）、年（YYYY）：原样单行；
/// - 月（YYYY-MM）：主标签「M月」，顶行年份仅在首桶与跨年处出现一次；
/// - 周（周一日期 M/D，兼容旧格式 MM-DD / MM-DD 周）：主标签「M/D」。
List<PeriodAxisLabel> periodAxisLabels(List<String> labels) {
  final result = <PeriodAxisLabel>[];
  String? lastYear;
  for (final label in labels) {
    final month = _monthBucket(label);
    if (month != null) {
      final (year, mon) = month;
      result.add((top: year == lastYear ? null : year, main: '$mon月'));
      lastYear = year;
      continue;
    }
    final week = _weekMondayLabel(label);
    if (week != null) {
      result.add((top: null, main: week));
      continue;
    }
    result.add((top: null, main: label));
  }
  return result;
}

/// 「YYYY-MM」月桶 → (年, 月)
(String, int)? _monthBucket(String label) {
  final m = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(label);
  return m == null ? null : (m.group(1)!, int.parse(m.group(2)!));
}

/// 周一日期桶（「M/D」「MM-DD」「MM-DD 周」）→「M/D」
String? _weekMondayLabel(String label) {
  final m = RegExp(r'^(\d{1,2})[-/](\d{1,2})( 周)?$').firstMatch(label);
  if (m == null) return null;
  return '${int.parse(m.group(1)!)}/${int.parse(m.group(2)!)}';
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

/// 周期对比柱状图（Spec §3.5；需求：日/周/月/年各桶以「支出红 / 收入绿」
/// 双柱并列呈现，实心加深语义色替代 α 渐变淡柱，x 轴每个周期下可直接
/// 对比当期收支；审查 U-11：touch tooltip 金额格式化 + 可读刻度）。
/// x 轴标签按维度语义紧凑化（[periodAxisLabels]）：日=周几、周=周一日期
/// 「M/D」、月=「M月」（跨年顶行标年份）、年=YYYY；柱宽随桶数自适应。
class PeriodBarChart extends StatelessWidget {
  const PeriodBarChart({super.key, required this.buckets, required this.hideAmounts});

  final List<PeriodBucket> buckets;
  final bool hideAmounts;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
    // 需求「加深柱状图颜色」：弃用 chartAreaGradient（顶色 α0.12 起），
    // 改为收支语义实心色（支出红 / 收入绿，浅深主题锁定值）
    final expenseColor = context.appColors.expense;
    final incomeColor = context.appColors.income;
    final axisStyle = context.text.bodySmall;
    final maxAmount = buckets.fold<int>(
      0,
      (a, b) => a > b.expenseMinor ? a : (b.expenseMinor > b.incomeMinor ? b.expenseMinor : b.incomeMinor),
    );
    // x/y 轴比例均衡：显式「好看」刻度步长（约 4 档），避免 fl_chart 默认间隔
    // 在极端量级下产生过密刻度或柱高与刻度错位的观感
    final yInterval = niceAxisStep((maxAmount == 0 ? 1 : maxAmount) * 1.2 / 4);
    final axisLabels = periodAxisLabels([
      for (final b in buckets) b.label,
    ]);
    // 月桶带年份顶行 → 底部预留两行高度
    final hasYearLine = axisLabels.any((l) => l.top != null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 收支对比图例：双柱语义一眼可辨
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _legendDot(expenseColor),
              const SizedBox(width: AppSpacing.xs),
              Text('支出', style: axisStyle),
              const SizedBox(width: AppSpacing.lg),
              _legendDot(incomeColor),
              const SizedBox(width: AppSpacing.xs),
              Text('收入', style: axisStyle),
            ],
          ),
        ),
        // 柱宽随桶数/屏宽自适应（日=7 桶、周/月/年=5 桶观感一致，
        // 窄屏自动收窄；左轴刻度区仅在金额可见时计入）
        LayoutBuilder(builder: (context, constraints) {
          final axisReserved = hideAmounts ? 0.0 : 52.0;
          final slot = (constraints.maxWidth - axisReserved) / buckets.length;
          final barWidth = ((slot - AppSpacing.xs) / 2).clamp(6.0, 14.0).toDouble();
          return SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                // 允许某周期无数据（0 柱）；maxY 兜底避免 0 刻度
                maxY: (maxAmount == 0 ? 1 : maxAmount).toDouble() * 1.2,
                // v3 网格线：divider α0.5（GLS-007，刻度不受档位影响）
                gridData: glassGridData(context),
                barTouchData: BarTouchData(
                  enabled: !hideAmounts,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                      '${rodIndex == 0 ? '支出' : '收入'} ${formatMoney(rod.toY.round())}',
                      TextStyle(color: rodIndex == 0 ? expenseColor : incomeColor),
                    ),
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
                                child: Text(compactTickLabel(value.round()),
                                    style: axisStyle),
                              );
                            },
                          ),
                        ),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: hasYearLine ? 46 : 32,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= axisLabels.length) {
                          return const SizedBox.shrink();
                        }
                        final label = axisLabels[index];
                        return SideTitleWidget(
                          meta: meta,
                          space: 6,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (label.top != null)
                                Text(label.top!, style: context.text.labelSmall),
                              Text(label.main, style: axisStyle),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < buckets.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: AppSpacing.xs,
                      barRods: [
                        BarChartRodData(
                          toY: buckets[i].expenseMinor.toDouble(),
                          color: expenseColor,
                          width: barWidth,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                        BarChartRodData(
                          toY: buckets[i].incomeMinor.toDouble(),
                          color: incomeColor,
                          width: barWidth,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      );
}
