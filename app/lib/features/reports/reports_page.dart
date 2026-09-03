import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger_version.dart';
import '../../data/local/database_provider.dart';
import '../../data/repositories/reports_repository.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/glass_tokens.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_segmented_button.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/glass_panel.dart';
import '../accounts/accounts_providers.dart' show exchangeRateServiceProvider;
import '../auth_lock/lock_controller.dart';
import '../books/books_providers.dart' show reportsRepositoryProvider;
import '../calendar/calendar_page.dart' show CalendarPage;
import 'charts/report_charts.dart';

typedef ReportWindow = ({DateTime start, DateTime end});

/// 报表视图（BK-DOC-26 需求6：日历并入报表）：图表 / 日历双视图
enum ReportsView { charts, calendar }

/// 图表时间筛选选择模型（BK-DOC-28 需求3）：滚轮依次选年 → 月 → 日，
/// 月/日选「全部」时记 null，统计粒度由选择深度决定
/// （仅年 → 年、年+月 → 月、年+月+日 → 日）。
/// 纯数据 + 纯派生：窗口/粒度/标签与滚轮联动规则均可脱离 Widget 单测。
class ReportTimeSelection {
  const ReportTimeSelection({required this.year, this.month, this.day});

  /// 首次进入 = 今年（年粒度）
  factory ReportTimeSelection.thisYear([DateTime? now]) =>
      ReportTimeSelection(year: (now ?? DateTime.now()).year);

  /// 年列可选范围（与日历 `firstDay/lastDay`、日期选择器边界一致）
  static const int firstYear = 2020;
  static const int lastYear = 2035;

  final int year;

  /// null = 「全部」（年维度）
  final int? month;

  /// null = 「全部」（月维度）；仅 [month] 非空时可选
  final int? day;

  /// 统计粒度：供周期对比取数（最近5年 / 最近5个月 / 最近7天）
  ReportRange get range => day != null
      ? ReportRange.day
      : month != null
          ? ReportRange.month
          : ReportRange.year;

  /// 统计窗口（开区间 `[start, end)`）
  ReportWindow get window {
    final m = month;
    if (m == null) return (start: DateTime(year), end: DateTime(year + 1));
    final d = day;
    if (d == null) {
      return (start: DateTime(year, m), end: DateTime(year, m + 1));
    }
    return (start: DateTime(year, m, d), end: DateTime(year, m, d + 1));
  }

  /// 当前统计期标签：「2026年」/「2026年9月」/「2026年9月2日」
  String get label {
    final m = month;
    if (m == null) return '$year年';
    final d = day;
    return d == null ? '$year年$m月' : '$year年$m月$d日';
  }

  /// 所选年月的天数（闰年 2 月 = 29）；月为「全部」时 null → 日列禁用
  int? get daysInMonth {
    final m = month;
    return m == null ? null : DateTime(year, m + 1, 0).day;
  }

  /// 年列滚动（AC3-2）：月保留（若非「全部」），日重置「全部」
  ReportTimeSelection selectYear(int next) =>
      ReportTimeSelection(year: next, month: month);

  /// 月列滚动（AC3-2）：日重置「全部」；next = null 表示「全部」
  ReportTimeSelection selectMonth(int? next) =>
      ReportTimeSelection(year: year, month: next);

  /// 日列滚动：next = null 表示「全部」；
  /// 月为「全部」时日列禁用，变更被忽略（返回原选择）
  ReportTimeSelection selectDay(int? next) {
    final m = month;
    return m == null
        ? this
        : ReportTimeSelection(year: year, month: m, day: next);
  }
}

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

/// 周期对比（需求3）：最近连续周期（日=最近7天 / 月=最近5个月 / 年=最近5年），
/// 每桶支出/收入双柱对比；锚点 = 所选周期起点。
/// 「周」「自定义范围」已无 UI 入口（Spec §3 C4），repo 层能力保留。
final periodBucketsProvider =
    FutureProvider.family<List<PeriodBucket>, ({ReportWindow window, ReportRange range})>(
        (ref, key) async {
  ref.watch(ledgerVersionProvider);
  final rates = await ref.watch(reportRatesProvider.future);
  return ref.watch(reportsRepositoryProvider).comparisonBuckets(
        windows: comparisonWindows(key.range, key.window.start),
        rates: rates,
      );
});

/// 年维度收支趋势（需求9 / Spec §2.9）：选中年 1–12 月支出/收入双柱。
/// 口径与报表其余区块一致（账本过滤 + 记账汇率快照回退汇率表）；
/// repo 只回有数据的月份，补零交给 [yearlyTrendBuckets]。
final yearlyTrendProvider =
    FutureProvider.family<List<PeriodBucket>, int>((ref, year) async {
  ref.watch(ledgerVersionProvider);
  final rates = await ref.watch(reportRatesProvider.future);
  final sparse = await ref.watch(reportsRepositoryProvider).periodBuckets(
        start: DateTime(year),
        end: DateTime(year + 1),
        granularity: BucketGranularity.month,
        rates: rates,
      );
  return yearlyTrendBuckets(year, sparse);
});

/// 把仅有数据的月份 [sparse]（label `YYYY-MM`）补零为固定 12 桶，
/// 让无数据月渲染 0 柱而非断档（Spec §2.9 交互 4）。
/// 全年零流水时返回空列表 → 图表走「暂无数据」空态（AC9-3）：
/// 12 根 0 柱占满整块视觉却不传递信息，空态更诚实。
/// label 沿用 `YYYY-MM`，由 `periodAxisLabels` 渲染为「1月…12月」。
List<PeriodBucket> yearlyTrendBuckets(int year, List<PeriodBucket> sparse) {
  String monthLabel(int month) => '$year-${month.toString().padLeft(2, '0')}';

  final byLabel = <String, PeriodBucket>{for (final b in sparse) b.label: b};
  final filled = [
    for (var m = 1; m <= 12; m++)
      byLabel[monthLabel(m)] ??
          PeriodBucket(
            label: monthLabel(m),
            expenseMinor: 0,
            incomeMinor: 0,
          ),
  ];
  final allZero =
      filled.every((b) => b.expenseMinor == 0 && b.incomeMinor == 0);
  return allZero ? const [] : filled;
}

/// 报表页（Spec §3.5 / BK-P0-005；BK-DOC-26 需求6 日历并入）：
/// 图表视图 = 饼图（分类占比）/ 柱状（周期对比，支出/收入双柱）
/// + 年粒度追加「收支趋势」12 月双柱（BK-DOC-28 需求9），
/// 时间筛选为滚轮式年 → 月 → 日（BK-DOC-28 需求3）；
/// 日历视图 = 月历每日收支净额，点日下方展开当日明细。
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportsView _view = ReportsView.charts;

  /// 图表统计期（需求3）：默认今年 → 年粒度
  ReportTimeSelection _selection = ReportTimeSelection.thisYear();

  /// 打开三列滚轮弹层；「确定」才落选，取消 / 下滑关闭返回 null 即丢弃（AC3-5）
  Future<void> _pickTime() async {
    final picked = await showAppSheet<ReportTimeSelection>(
      context,
      title: '选择统计期',
      child: _TimeWheelPicker(initial: _selection),
    );
    if (picked != null && mounted) setState(() => _selection = picked);
  }

  @override
  Widget build(BuildContext context) {
    // 审查 U-1：无内层 Scaffold/AppBar；IndexedStack 保持 _view/_selection
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // BK-DOC-26 需求6：图表 / 日历双视图切换
        // BK-DOC-28 需求7：选中态去 ✔，改颜色突显（样式收敛于共享组件）
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: AppSegmentedButton<ReportsView>(
            segments: const [
              ButtonSegment(
                value: ReportsView.charts,
                label: Text('图表'),
                icon: Icon(Icons.pie_chart_outline),
              ),
              ButtonSegment(
                value: ReportsView.calendar,
                label: Text('日历'),
                icon: Icon(Icons.calendar_month_outlined),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ),
        if (_view == ReportsView.charts)
          ..._chartsBody()
        else
          // 日历视图：月历日格每日收支净额 + 点日下方展开当日明细
          const Expanded(child: CalendarPage()),
      ],
    );
  }

  /// 图表视图内容（原报表页主体；取数仅在图表态触发）
  List<Widget> _chartsBody() {
    final selection = _selection;
    final window = selection.window;
    final slices = ref.watch(categoryBreakdownProvider(window));
    final buckets = ref.watch(
      periodBucketsProvider((window: window, range: selection.range)),
    );
    // 隐私锁锁定/后台态强制脱敏（Spec §3.6）；手动隐藏开关已按需求移除
    final hideAmounts = ref.watch(amountMaskProvider);
    // 需求9：仅年粒度取数并渲染「收支趋势」；月/日粒度不发起这次查询，
    // 也不会因切换粒度而多出一轮 provider 重建
    final trend = selection.range == ReportRange.year
        ? ref.watch(yearlyTrendProvider(selection.year))
        : null;

    return [
      // 需求3：全宽时间 chip（当前统计期 + 展开图标）→ 滚轮弹层
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: _TimeChip(label: selection.label, onTap: _pickTime),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            // 审查 U-11：错误态带重试（invalidate 对应 provider 重建）
            _Section(
              title: '分类占比',
              subtitle: selection.label,
              child: _chartOrRetry(
                slices,
                (s) => CategoryPieChart(slices: s, hideAmounts: hideAmounts),
                () => ref.invalidate(categoryBreakdownProvider(window)),
              ),
            ),
            // 需求1：折线图取消，收支双柱由「周期对比」承载
            _Section(
              title: '周期对比',
              subtitle: _comparisonSubtitle,
              child: _chartOrRetry(
                buckets,
                (b) => PeriodBarChart(buckets: b, hideAmounts: hideAmounts),
                () => ref.invalidate(
                  periodBucketsProvider((window: window, range: selection.range)),
                ),
              ),
            ),
            // 需求9：选中年 1–12 月收支走势（AC9-1 ~ AC9-4）
            if (trend != null)
              _Section(
                title: '收支趋势',
                subtitle: '${selection.year}年 · 按月汇总',
                child: _chartOrRetry(
                  trend,
                  (b) => PeriodBarChart(
                    buckets: b,
                    hideAmounts: hideAmounts,
                    // 同年 12 桶：年份已由副标题承载，轴顶行让位给柱区
                    showLeadingYear: false,
                  ),
                  () => ref.invalidate(yearlyTrendProvider(selection.year)),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  /// 周期对比取数口径（需求3 / AC3-4）：年 → 最近5年、月 → 最近5个月、
  /// 日 → 最近7天（`range` 仅可能为这三值）
  String get _comparisonSubtitle => switch (_selection.range) {
        ReportRange.day => '最近7天',
        ReportRange.month => '最近5个月',
        _ => '最近5年',
      };
}

/// 时间筛选 chip（需求3）：全宽可点按，展示当前统计期 + 尾部展开图标；
/// 容器走 G1 玻璃 + 胶囊圆角（可点面板按压反馈由 [GlassPanel] 承载）
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassPanel(
      level: GlassLevel.g1,
      borderRadius: AppRadius.pillAll,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, size: 18, color: palette.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: context.text.titleSmall)),
          Icon(Icons.expand_more, size: 18, color: palette.textSecondary),
        ],
      ),
    );
  }
}

/// 时间筛选滚轮弹层（需求3）：年 / 月 / 日三列 iOS 滚轮依次选择。
/// 联动（AC3-2）：月为「全部」→ 日列灰显禁用；年变化 → 月保留、日重置「全部」；
/// 月变化 → 日重置「全部」。规则由 [ReportTimeSelection] 纯函数承载（可单测）。
/// 「确定」以当前草稿出栈；取消 / 下滑关闭返回 null（草稿随弹层丢弃）。
class _TimeWheelPicker extends StatefulWidget {
  const _TimeWheelPicker({required this.initial});

  final ReportTimeSelection initial;

  @override
  State<_TimeWheelPicker> createState() => _TimeWheelPickerState();
}

class _TimeWheelPickerState extends State<_TimeWheelPicker> {
  /// iOS 日期滚轮惯用高度与单项行高
  static const double _wheelHeight = 216;
  static const double _itemExtent = 40;

  late ReportTimeSelection _draft = widget.initial;
  late final FixedExtentScrollController _yearController =
      FixedExtentScrollController(
    initialItem: _draft.year - ReportTimeSelection.firstYear,
  );
  late final FixedExtentScrollController _monthController =
      FixedExtentScrollController(initialItem: _draft.month ?? 0);
  late final FixedExtentScrollController _dayController =
      FixedExtentScrollController(initialItem: _draft.day ?? 0);

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  /// 年/月变化后日列必回「全部」：日列项数随年月联动变化，
  /// 停留旧索引会越界导致滚轮渲染错位，故显式归零
  void _resetDayWheel() {
    if (_dayController.hasClients) _dayController.jumpToItem(0);
  }

  void _onYearChanged(int index) {
    setState(() {
      _draft = _draft.selectYear(ReportTimeSelection.firstYear + index);
    });
    _resetDayWheel();
  }

  void _onMonthChanged(int index) {
    setState(() => _draft = _draft.selectMonth(index == 0 ? null : index));
    _resetDayWheel();
  }

  void _onDayChanged(int index) {
    setState(() => _draft = _draft.selectDay(index == 0 ? null : index));
  }

  @override
  Widget build(BuildContext context) {
    // null = 月为「全部」→ 日列禁用（AC3-2）
    final days = _draft.daysInMonth;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final title in const ['年', '月', '日'])
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: _wheelHeight,
          child: Row(
            children: [
              Expanded(
                child: CupertinoPicker(
                  scrollController: _yearController,
                  itemExtent: _itemExtent,
                  onSelectedItemChanged: _onYearChanged,
                  children: [
                    for (var y = ReportTimeSelection.firstYear;
                        y <= ReportTimeSelection.lastYear;
                        y++)
                      _wheelItem('$y年'),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: _monthController,
                  itemExtent: _itemExtent,
                  onSelectedItemChanged: _onMonthChanged,
                  children: [
                    _wheelItem('全部'),
                    for (var m = 1; m <= 12; m++) _wheelItem('$m月'),
                  ],
                ),
              ),
              Expanded(
                // 禁用态仅切换属性、不改变子树结构：滚轮位置得以保持，
                // 避免控制器反复脱离/重挂导致索引回落到 initialItem
                child: IgnorePointer(
                  ignoring: days == null,
                  child: Opacity(
                    opacity: days == null ? 0.4 : 1,
                    child: CupertinoPicker(
                      scrollController: _dayController,
                      itemExtent: _itemExtent,
                      onSelectedItemChanged: days == null ? null : _onDayChanged,
                      children: [
                        _wheelItem('全部'),
                        for (var d = 1; d <= (days ?? 0); d++) _wheelItem('$d日'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                block: true,
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton.primary(
                block: true,
                onPressed: () => Navigator.pop(context, _draft),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _wheelItem(String text) =>
      Center(child: Text(text, style: context.text.bodyLarge));
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
  const _Section({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
