import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/money_format.dart';
import '../../../data/repositories/reports_repository.dart';

const _palette = [
  Color(0xFFFF7043), Color(0xFFFFB300), Color(0xFF66BB6A), Color(0xFF26C6DA),
  Color(0xFF42A5F5), Color(0xFF7E57C2), Color(0xFFEC407A), Color(0xFF8D6E63),
];

/// 可读刻度（审查 U-11）：大额转「x.xx万」，小额原样；负值保留符号
String _compactTick(int minor) {
  final abs = minor.abs();
  final sign = minor < 0 ? '-' : '';
  if (abs >= 10000000) return '$sign${(minor / 1000000).toStringAsFixed(1)}百万';
  if (abs >= 100000) return '$sign${(minor / 100000).toStringAsFixed(1)}万';
  return '$sign${formatMoney(minor).replaceAll('¥', '')}';
}

/// 分类占比饼图（Spec §3.5；审查 U-11：扇区仅百分比，金额进外置图例；
/// 脱敏态图例金额脱敏）
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key, required this.slices, required this.hideAmounts});

  final List<CategorySlice> slices;
  final bool hideAmounts;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
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
                    color: _palette[i % _palette.length],
                    title: hideAmounts
                        ? null
                        : total <= 0
                            ? null
                            : '${(slices[i].amountMinor * 100 ~/ total)}%',
                    titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
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
                      color: _palette[i % _palette.length],
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
    final maxAmount = buckets.fold<int>(0, (a, b) => a > b.amountMinor ? a : b.amountMinor);
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxAmount.toDouble() * 1.2,
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
                      getTitlesWidget: (value, meta) {
                        if (value <= 0) return const SizedBox.shrink();
                        return Text(_compactTick(value.toInt()),
                            style: const TextStyle(fontSize: 12));
                      },
                    ),
                  ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= buckets.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(buckets[index].label, style: const TextStyle(fontSize: 12)),
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
                  color: _palette[i % _palette.length],
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

/// 收支趋势折线图（Spec §3.5；审查 U-11：tooltip 金额格式化 + 可读刻度）
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
    final sampled = totals.length > maxPoints
        ? [for (var i = 0; i < totals.length; i += totals.length ~/ maxPoints) totals[i]]
        : totals;
    if (sampled.length < 2) {
      return const Center(child: Text('暂无数据'));
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
                    formatMoney(s.y.round()),
                    TextStyle(
                      color: s.barIndex == 0
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: hideAmounts
                ? const AxisTitles(sideTitles: SideTitles(showTitles: false))
                : AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (value, meta) {
                        if (value <= 0) return const SizedBox.shrink();
                        return Text(_compactTick(value.toInt()),
                            style: const TextStyle(fontSize: 12));
                      },
                    ),
                  ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: expense,
              color: Theme.of(context).colorScheme.error,
              barWidth: 2,
              isCurved: true,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: income,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 2,
              isCurved: true,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
