import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/ledger_version.dart';
import '../../core/utils/money_format.dart';
import '../../shared/theme/app_theme.dart';
import '../../data/local/database.dart';
import '../../data/local/database_provider.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../data/repositories/reports_repository.dart';
import '../auth_lock/lock_controller.dart';
import '../books/books_providers.dart'
    show currentBookIdProvider, currentRoleProvider, reportsRepositoryProvider;
import '../quick_entry/quick_entry_sheet.dart' show openQuickEntrySheet;
import '../reports/reports_page.dart' show ReportWindow, reportRatesProvider;
import 'cashflow_chart.dart';

/// 日历/现金流视图（Spec §4.6 / BK-T-015）：
/// 月历日格显示收支净额（复用报表按日聚合），点击日进明细；
/// 月份切换懒加载（仅拉取可见月份区间）；下方为 30 天滑动窗口现金流趋势。
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  /// 当前视图的按日聚合取数窗口：聚焦月整月（月份懒加载，Spec §4.6）。
  /// 月/双周切换已移除：双周视图需跨月取数、口径特殊且信息密度低，
  /// 月历已完整覆盖需求；固定单格式也避免误触导致视图跳变。
  ReportWindow get _window {
    return (
      start: DateTime(_focusedDay.year, _focusedDay.month),
      end: DateTime(_focusedDay.year, _focusedDay.month + 1),
    );
  }

  Future<void> _pickYear(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && mounted) {
      setState(() => _focusedDay = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final window = _window;
    // 审查 U-1：无内层 Scaffold/AppBar；年份切换内联头部
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton.icon(
              onPressed: () => _pickYear(context),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('${_focusedDay.year}年'),
            ),
          ),
        ),
        // 懒加载：仅请求当前视图窗口的按日聚合
        _MonthTotalsScope(
          key: ValueKey(
              '${window.start.year}-${window.start.month}-${window.start.day}'),
          window: window,
          focusedDay: _focusedDay,
          selectedDay: _selectedDay,
          onSelected: (day) => setState(() => _selectedDay = day),
          onFocused: (day) => setState(() => _focusedDay = day),
        ),
        Expanded(
          child: CashflowChart(day: _selectedDay),
        ),
      ],
    );
  }
}

class _MonthTotalsScope extends ConsumerWidget {
  const _MonthTotalsScope({
    super.key,
    required this.window,
    required this.focusedDay,
    required this.selectedDay,
    required this.onSelected,
    required this.onFocused,
  });

  final ReportWindow window;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onFocused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(calendarDailyTotalsProvider((start: window.start, end: window.end)));
    final totalsByDay = totals.maybeWhen(
      data: (list) => {for (final t in list) t.date: t},
      orElse: () => <String, DailyTotal>{},
    );
    final masked = ref.watch(amountMaskProvider);
    final viewer = ref.watch(currentRoleProvider) == 'viewer';

    return TableCalendar<DailyTotal>(
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime(2035, 12, 31),
      locale: 'zh_CN',
      rowHeight: 56,
      // 月/双周切换按钮已取消（仅保留月视图）：双周窗口跨月取数、口径特殊，
      // 且格式按钮易误触导致视图跳变；如需紧凑视图可后续以独立入口回归。
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: '月'},
      headerStyle: const HeaderStyle(formatButtonVisible: false),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(day, selectedDay),
      // 单击 → 更新选中日并直达当日记账（日期预填）；viewer 只读不跳转
      onDaySelected: (selected, focused) {
        onSelected(selected);
        onFocused(focused);
        if (!viewer) {
          openQuickEntrySheet(context, initialDate: selected);
        }
      },
      // 长按 → 当日明细弹层（Spec §4.6 点击日进明细）
      onDayLongPressed: (day, focused) {
        onSelected(day);
        onFocused(focused);
        DayDetailSheet.show(context, day);
      },
      onPageChanged: (focused) => onFocused(focused),
      calendarBuilders: CalendarBuilders<DailyTotal>(
        defaultBuilder: (context, day, _) => _dayCell(context, day, totalsByDay, masked),
        todayBuilder: (context, day, _) => _dayCell(context, day, totalsByDay, masked),
        selectedBuilder: (context, day, _) => _dayCell(context, day, totalsByDay, masked),
        // 空白日期修复：相邻月份日期不再整格留白，改渲染淡色日号
        // （无金额、可点按跳转对应月份），月面观感连续完整。
        outsideBuilder: (context, day, _) =>
            _dayCell(context, day, totalsByDay, masked, dimmed: true),
      ),
    );
  }

  Widget _dayCell(
    BuildContext context,
    DateTime day,
    Map<String, DailyTotal> totalsByDay,
    bool masked, {
    bool dimmed = false,
  }) {
    final theme = Theme.of(context);
    // 今天与选中态在 _dayCell 内统一判定，today/selected 两 builder 共用同一样式
    final isToday = isSameDay(day, DateTime.now());
    final isSelected = isSameDay(day, selectedDay);
    final key = _dayKey(day);
    final total = totalsByDay[key];
    final net = total == null ? 0 : total.incomeMinor - total.expenseMinor;
    // UI 重构（Spec §6）：选中/今日标记与金额色全部走 palette/语义色
    final amountColor = net > 0
        ? context.appColors.income
        : net < 0
            ? context.appColors.expense
            : context.palette.textSecondary;

    // 选择效果变形修复：高亮改为固定直径的圆形标记（仅包裹日号），
    // 不再以整格容器铺色——此前 BoxDecoration 会随日格宽度拉伸成椭圆/圆角矩形。
    // 优先级：今日 > 选中（同日重叠时以主色今日样式呈现）。
    final Color? markerColor = isToday
        ? theme.colorScheme.primary
        : isSelected
            ? theme.colorScheme.primaryContainer
            : null;
    final Color numberColor = isToday
        ? context.palette.onPrimary
        : isSelected
            ? theme.colorScheme.onPrimaryContainer
            : dimmed
                ? context.palette.textDisabled
                : context.palette.textPrimary;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: markerColor == null
              ? null
              : BoxDecoration(color: markerColor, shape: BoxShape.circle),
          child: Text(
            '${day.day}',
            style: (isToday || isSelected
                    ? context.text.bodyMedium
                    : context.text.bodySmall)
                ?.copyWith(
              fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
              color: numberColor,
            ),
          ),
        ),
        // 相邻月份的淡色日号不显示金额，避免与本月日格混淆
        if (!dimmed && net != 0)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                masked ? '*' : _compactMoney(net),
                style: context.text.bodySmall?.copyWith(
                  // 审查 U-8：字号下限 12sp（WCAG 可读性）
                  color: isToday ? context.palette.onPrimary : amountColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  String _compactMoney(int minor) {
    final abs = minor.abs();
    if (abs >= 10000) return formatMoney(abs ~/ 100 * 100).replaceAll('¥', '');
    return formatMoney(abs).replaceAll('¥', '');
  }
}

/// 按日聚合（复用报表查询层；月份懒加载，Spec §4.6）
final calendarDailyTotalsProvider = FutureProvider.family<List<DailyTotal>, ReportWindow>(
    (ref, window) async {
  ref.watch(ledgerVersionProvider); // 账本写操作后自动重建（审查 F-1）
  final rates = await ref.watch(reportRatesProvider.future);
  return ref
      .watch(reportsRepositoryProvider)
      .dailyTotals(start: window.start, end: window.end, rates: rates);
});

/// 点击日明细（当天流水；日聚合 = 明细合计交叉验证在测试中覆盖）
class DayDetailSheet extends ConsumerWidget {
  const DayDetailSheet({super.key, required this.day});

  final DateTime day;

  static Future<void> show(BuildContext context, DateTime day) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DayDetailSheet(day: day),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final bookId = ref.watch(currentBookIdProvider);
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final masked = ref.watch(amountMaskProvider);
    return SafeArea(
      child: FutureBuilder<List<Transaction>>(
        future: (db.select(db.transactions)
              ..where((t) =>
                  t.bookId.equals(bookId) &
                  t.deletedAt.isNull() &
                  t.occurredAt.isBiggerOrEqualValue(start) &
                  t.occurredAt.isSmallerThanValue(end))
              ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
            .get(),
        builder: (context, snapshot) {
          final txs = snapshot.data ?? const <Transaction>[];
          final net = txs.fold<int>(
              0, (sum, t) => sum + (t.type == TransactionType.expense ? -t.amountMinor.abs() : t.amountMinor.abs()));
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            // 审查 U-10：当日明细惰性构建（大流水量下滚动不卡顿）
            builder: (context, scrollController) => ListView.builder(
              controller: scrollController,
              itemCount: txs.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${day.year}-${day.month}-${day.day}  '
                      '净额 ${masked ? '***' : formatMoney(net)}（${txs.length} 笔）',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }
                final t = txs[i - 1];
                return ListTile(
                  leading: Icon(
                    t.type == TransactionType.expense
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: t.type == TransactionType.expense
                        ? context.appColors.expense
                        : context.appColors.income,
                  ),
                  title: Text(masked ? '***' : formatMoney(t.amountMinor)),
                  subtitle: Text(
                      '${t.note ?? '未命名'} · ${t.occurredAt.toLocal().hour}:${t.occurredAt.toLocal().minute.toString().padLeft(2, '0')}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
