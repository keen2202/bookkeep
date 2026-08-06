import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/utils/money_format.dart';
import '../../data/local/database.dart';
import '../../data/local/database_provider.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../data/repositories/reports_repository.dart';
import '../auth_lock/lock_controller.dart';
import '../books/books_providers.dart' show currentBookIdProvider, reportsRepositoryProvider;
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
  CalendarFormat _format = CalendarFormat.month;

  /// 当前视图的按日聚合取数窗口：
  /// month = 聚焦月；twoWeeks = 聚焦日所在周（周日起点，与 table_calendar
  /// 默认 startingDayOfWeek 一致）起的 14 天（可能跨月）。
  ReportWindow get _window {
    if (_format == CalendarFormat.month) {
      return (
        start: DateTime(_focusedDay.year, _focusedDay.month),
        end: DateTime(_focusedDay.year, _focusedDay.month + 1),
      );
    }
    final weekStart = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day)
        .subtract(Duration(days: _focusedDay.weekday % 7));
    return (
      start: weekStart,
      end: weekStart.add(const Duration(days: 14)),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('日历'),
        actions: [
          TextButton(
            onPressed: () => _pickYear(context),
            child: Text('${_focusedDay.year}年'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 懒加载：仅请求当前视图窗口的按日聚合
          _MonthTotalsScope(
            key: ValueKey(
                '${_format.name}|${window.start.year}-${window.start.month}-${window.start.day}'),
            window: window,
            format: _format,
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            onSelected: (day) => setState(() => _selectedDay = day),
            onFocused: (day) => setState(() => _focusedDay = day),
            onFormatChanged: (f) => setState(() => _format = f),
          ),
          Expanded(
            child: CashflowChart(day: _selectedDay),
          ),
        ],
      ),
    );
  }
}

class _MonthTotalsScope extends ConsumerWidget {
  const _MonthTotalsScope({
    super.key,
    required this.window,
    required this.format,
    required this.focusedDay,
    required this.selectedDay,
    required this.onSelected,
    required this.onFocused,
    required this.onFormatChanged,
  });

  final ReportWindow window;
  final CalendarFormat format;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onFocused;
  final ValueChanged<CalendarFormat> onFormatChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(calendarDailyTotalsProvider((start: window.start, end: window.end)));
    final totalsByDay = totals.maybeWhen(
      data: (list) => {for (final t in list) t.date: t},
      orElse: () => <String, DailyTotal>{},
    );
    final masked = ref.watch(amountMaskProvider);

    return TableCalendar<DailyTotal>(
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime(2035, 12, 31),
      locale: 'zh_CN',
      rowHeight: 56,
      calendarFormat: format,
      availableCalendarFormats: const {
        CalendarFormat.month: '月',
        CalendarFormat.twoWeeks: '双周',
      },
      onFormatChanged: onFormatChanged,
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(day, selectedDay),
      onDaySelected: (selected, focused) {
        onSelected(selected);
        onFocused(focused);
      },
      onPageChanged: (focused) => onFocused(focused),
      calendarBuilders: CalendarBuilders<DailyTotal>(
        defaultBuilder: (context, day, _) => _dayCell(context, day, totalsByDay, masked),
        todayBuilder: (context, day, _) => _dayCell(context, day, totalsByDay, masked),
        selectedBuilder: (context, day, _) => _dayCell(context, day, totalsByDay, masked),
        outsideBuilder: (context, day, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _dayCell(
    BuildContext context,
    DateTime day,
    Map<String, DailyTotal> totalsByDay,
    bool masked,
  ) {
    final theme = Theme.of(context);
    // 今天与选中态在 _dayCell 内统一判定，today/selected 两 builder 共用同一样式
    final isToday = isSameDay(day, DateTime.now());
    final isSelected = isSameDay(day, selectedDay);
    final key = _dayKey(day);
    final total = totalsByDay[key];
    final net = total == null ? 0 : total.incomeMinor - total.expenseMinor;
    final color = net > 0
        ? Colors.green
        : net < 0
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: isToday
          ? BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            )
          : isSelected
              ? BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${day.day}',
              style: TextStyle(
                fontSize: isToday ? 14 : 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? Colors.white : null,
              )),
          if (net != 0)
            Text(
              masked ? '*' : _compactMoney(net),
              style: TextStyle(
                fontSize: 8,
                color: isToday ? Colors.white : color,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
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
            builder: (context, scrollController) => ListView(
              controller: scrollController,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${day.year}-${day.month}-${day.day}  '
                    '净额 ${masked ? '***' : formatMoney(net)}（${txs.length} 笔）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final t in txs)
                  ListTile(
                    leading: Icon(
                      t.type == TransactionType.expense
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: t.type == TransactionType.expense ? Colors.red : Colors.green,
                    ),
                    title: Text(masked ? '***' : formatMoney(t.amountMinor)),
                    subtitle: Text(
                        '${t.note ?? '未命名'} · ${t.occurredAt.toLocal().hour}:${t.occurredAt.toLocal().minute.toString().padLeft(2, '0')}'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
