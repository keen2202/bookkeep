import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database_provider.dart';
import '../../data/repositories/reports_repository.dart';
import 'charts/report_charts.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(databaseProvider));
});

typedef ReportWindow = ({DateTime start, DateTime end});

final dailyTotalsProvider =
    FutureProvider.family<List<DailyTotal>, ReportWindow>((ref, window) {
  return ref.watch(reportsRepositoryProvider).dailyTotals(start: window.start, end: window.end);
});

final categoryBreakdownProvider =
    FutureProvider.family<List<CategorySlice>, ReportWindow>((ref, window) {
  return ref
      .watch(reportsRepositoryProvider)
      .categoryBreakdown(start: window.start, end: window.end);
});

final periodBucketsProvider =
    FutureProvider.family<List<PeriodBucket>, ({ReportWindow window, ReportRange range})>(
        (ref, key) {
  return ref.watch(reportsRepositoryProvider).periodBuckets(
        start: key.window.start,
        end: key.window.end,
        granularity: key.range == ReportRange.day || key.range == ReportRange.week
            ? BucketGranularity.week
            : BucketGranularity.month,
      );
});

enum ReportRange { day, week, month, year }

extension ReportRangeWindow on ReportRange {
  ({DateTime start, DateTime end}) window(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      ReportRange.day => (
          start: today,
          end: today.add(const Duration(days: 1)),
        ),
      ReportRange.week => (
          start: today.subtract(Duration(days: today.weekday - 1)),
          end: today.add(Duration(days: 8 - today.weekday)),
        ),
      ReportRange.month => (
          start: DateTime(now.year, now.month),
          end: DateTime(now.year, now.month + 1),
        ),
      ReportRange.year => (
          start: DateTime(now.year),
          end: DateTime(now.year + 1),
        ),
    };
  }
}

/// 报表页（Spec §3.5 / BK-P0-005）：饼图（分类占比）/ 柱状（周期对比）/ 折线（趋势）
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportRange _range = ReportRange.month;
  bool _hideAmounts = false;

  @override
  Widget build(BuildContext context) {
    final window = _range.window(DateTime.now());
    final daily = ref.watch(dailyTotalsProvider(window));
    final slices = ref.watch(categoryBreakdownProvider(window));
    final buckets = ref.watch(periodBucketsProvider((window: window, range: _range)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('报表'),
        actions: [
          IconButton(
            tooltip: _hideAmounts ? '显示金额' : '隐藏金额',
            icon: Icon(_hideAmounts ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _hideAmounts = !_hideAmounts),
          ),
        ],
      ),
      body: Column(
        children: [
          SegmentedButton<ReportRange>(
            segments: const [
              ButtonSegment(value: ReportRange.day, label: Text('日')),
              ButtonSegment(value: ReportRange.week, label: Text('周')),
              ButtonSegment(value: ReportRange.month, label: Text('月')),
              ButtonSegment(value: ReportRange.year, label: Text('年')),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                _Section(
                  title: '分类占比',
                  child: slices.maybeWhen(data: (s) => CategoryPieChart(slices: s, hideAmounts: _hideAmounts), orElse: () => const Center(child: CircularProgressIndicator())),
                ),
                _Section(
                  title: '周期对比',
                  child: buckets.maybeWhen(data: (b) => PeriodBarChart(buckets: b, hideAmounts: _hideAmounts), orElse: () => const Center(child: CircularProgressIndicator())),
                ),
                _Section(
                  title: '收支趋势',
                  child: daily.maybeWhen(data: (d) => TrendLineChart(totals: d, hideAmounts: _hideAmounts), orElse: () => const Center(child: CircularProgressIndicator())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
