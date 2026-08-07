import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger_version.dart';
import '../../data/local/database_provider.dart';
import '../../data/repositories/reports_repository.dart';
import '../accounts/accounts_providers.dart' show exchangeRateServiceProvider;
import '../auth_lock/lock_controller.dart';
import '../books/books_providers.dart' show reportsRepositoryProvider;
import 'charts/report_charts.dart';

typedef ReportWindow = ({DateTime start, DateTime end});

/// 报表汇率表（非主币种 → kRateScale 刻度；Spec §4.5 折算主币种）
final reportRatesProvider = FutureProvider<Map<String, int>>((ref) async {
  final service = ref.watch(exchangeRateServiceProvider);
  final db = ref.watch(databaseProvider);
  final currencies = await db.select(db.currencies).get();
  final rates = <String, int>{};
  for (final c in currencies) {
    if (c.code == 'CNY') continue;
    rates[c.code] = await service.rateScaled(c.code);
  }
  return rates;
});

final dailyTotalsProvider =
    FutureProvider.family<List<DailyTotal>, ReportWindow>((ref, window) async {
  ref.watch(ledgerVersionProvider); // 账本写操作后自动重建（审查 F-1）
  final rates = await ref.watch(reportRatesProvider.future);
  return ref
      .watch(reportsRepositoryProvider)
      .dailyTotals(start: window.start, end: window.end, rates: rates);
});

final categoryBreakdownProvider =
    FutureProvider.family<List<CategorySlice>, ReportWindow>((ref, window) async {
  ref.watch(ledgerVersionProvider);
  final rates = await ref.watch(reportRatesProvider.future);
  return ref
      .watch(reportsRepositoryProvider)
      .categoryBreakdown(start: window.start, end: window.end, rates: rates);
});

final periodBucketsProvider =
    FutureProvider.family<List<PeriodBucket>, ({ReportWindow window, ReportRange range})>(
        (ref, key) async {
  ref.watch(ledgerVersionProvider);
  final rates = await ref.watch(reportRatesProvider.future);
  return ref.watch(reportsRepositoryProvider).periodBuckets(
        start: key.window.start,
        end: key.window.end,
        granularity: key.range == ReportRange.day || key.range == ReportRange.week
            ? BucketGranularity.week
            : BucketGranularity.month,
        rates: rates,
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
    // 隐私锁锁定/后台态强制脱敏（Spec §3.6），叠加用户手动隐藏金额开关
    final hideAmounts = _hideAmounts || ref.watch(amountMaskProvider);

    // 审查 U-1：无内层 Scaffold/AppBar；隐藏金额开关内联（IndexedStack 保持 _range/_hideAmounts）
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<ReportRange>(
                segments: const [
                  ButtonSegment(value: ReportRange.day, label: Text('日')),
                  ButtonSegment(value: ReportRange.week, label: Text('周')),
                  ButtonSegment(value: ReportRange.month, label: Text('月')),
                  ButtonSegment(value: ReportRange.year, label: Text('年')),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
            ),
            IconButton(
              tooltip: _hideAmounts ? '显示金额' : '隐藏金额',
              icon: Icon(_hideAmounts ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _hideAmounts = !_hideAmounts),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              // 审查 U-11：错误态带重试（invalidate 对应 provider 重建）
              _Section(
                title: '分类占比',
                child: _chartOrRetry(
                  slices,
                  (s) => CategoryPieChart(slices: s, hideAmounts: hideAmounts),
                  () => ref.invalidate(categoryBreakdownProvider(window)),
                ),
              ),
              _Section(
                title: '周期对比',
                child: _chartOrRetry(
                  buckets,
                  (b) => PeriodBarChart(buckets: b, hideAmounts: hideAmounts),
                  () => ref.invalidate(periodBucketsProvider((window: window, range: _range))),
                ),
              ),
              _Section(
                title: '收支趋势',
                child: _chartOrRetry(
                  daily,
                  (d) => TrendLineChart(totals: d, hideAmounts: hideAmounts),
                  () => ref.invalidate(dailyTotalsProvider(window)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 图表区：data/loading/error 三态；error 提供重试按钮
Widget _chartOrRetry<T>(
  AsyncValue<T> value,
  Widget Function(T data) builder,
  VoidCallback onRetry,
) {
  return value.when(
    data: builder,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (_, _) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('图表加载失败'),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
  );
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
