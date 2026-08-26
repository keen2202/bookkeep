import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger_version.dart';
import '../../data/local/database_provider.dart';
import '../../data/repositories/reports_repository.dart';
import '../accounts/accounts_providers.dart' show exchangeRateServiceProvider;
import '../auth_lock/lock_controller.dart';
import '../books/books_providers.dart' show reportsRepositoryProvider;
import '../../shared/theme/glass_tokens.dart';
import '../../shared/widgets/glass_panel.dart';
import 'charts/report_charts.dart';

typedef ReportWindow = ({DateTime start, DateTime end});

/// 报表汇率表（非主币种 → kRateScale 刻度；Spec §4.5 折算主币种）。
/// watch 账本版本号：手动改汇率先 bump 版本（汇率管理页），
/// 否则本 provider 缓存不失效，报表/日历将一直沿用旧汇率。
final reportRatesProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(ledgerVersionProvider);
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
  final repo = ref.watch(reportsRepositoryProvider);
  // 标准维度：周期对比 = 最近连续周期（日=最近7天 / 周=最近5周 /
  // 月=最近5月 / 年=最近5年），每桶支出/收入双柱对比
  if (key.range != ReportRange.custom) {
    return repo.comparisonBuckets(
      windows: comparisonWindows(key.range, key.window.start),
      rates: rates,
    );
  }
  // 自定义范围：按范围长度选周/月粒度分桶
  final duration = key.window.end.difference(key.window.start);
  final granularity =
      duration.inDays <= 62 ? BucketGranularity.week : BucketGranularity.month;
  return repo.periodBuckets(
    start: key.window.start,
    end: key.window.end,
    granularity: granularity,
    rates: rates,
  );
});

/// 报表页（Spec §3.5 / BK-P0-005）：饼图（分类占比）/ 柱状（周期对比，
/// 支出/收入双柱）
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportRange _range = ReportRange.month;
  DateTime? _customStart; // 含当日
  DateTime? _customEnd; // 含当日
  bool _hideAmounts = false;

  /// 当前窗口（custom 维度走自定义起止；其余维度相对今天）
  ReportWindow get _window {
    if (_range == ReportRange.custom) {
      final start = _customStart ?? DateTime.now();
      final end = _customEnd ?? start;
      return customWindow(start, end);
    }
    return _range.window(DateTime.now());
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: (_customStart != null && _customEnd != null)
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
      helpText: '选择自定义时间范围',
      saveText: '确定',
    );
    if (picked != null && mounted) {
      setState(() {
        _range = ReportRange.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final window = _window;
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
                selected: {_range == ReportRange.custom ? ReportRange.month : _range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
            ),
            IconButton(
              tooltip: '自定义时间范围',
              icon: Icon(
                _range == ReportRange.custom ? Icons.date_range : Icons.date_range_outlined,
              ),
              onPressed: _pickCustomRange,
            ),
            IconButton(
              tooltip: _hideAmounts ? '显示金额' : '隐藏金额',
              icon: Icon(_hideAmounts ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _hideAmounts = !_hideAmounts),
            ),
          ],
        ),
        if (_range == ReportRange.custom && _customStart != null && _customEnd != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    '${_fmtDate(_customStart!)} ~ ${_fmtDate(_customEnd!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onPressed: _pickCustomRange,
                ),
                TextButton(
                  onPressed: () => setState(() => _range = ReportRange.month),
                  child: const Text('退出自定义'),
                ),
              ],
            ),
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
              // 需求：取消「收支趋势」折线图；周期对比承载收支双柱
              _Section(
                title: '周期对比',
                child: _chartOrRetry(
                  buckets,
                  (b) => PeriodBarChart(buckets: b, hideAmounts: hideAmounts),
                  () => ref.invalidate(periodBucketsProvider((window: window, range: _range))),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
    // FGDS：图表容器统一 GlassPanel（G2，Spec §4.5）
    return GlassPanel(
      level: GlassLevel.g2,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
