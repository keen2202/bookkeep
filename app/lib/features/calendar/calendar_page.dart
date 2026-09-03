import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/ledger_version.dart';
import '../../core/utils/money_format.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/glass_tokens.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/utils/category_icon.dart';
import '../../shared/widgets/app_amount_text.dart';
import '../../shared/widgets/glass_panel.dart';
import '../../data/local/database.dart';
import '../../data/local/database_provider.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../data/repositories/reports_repository.dart';
import '../auth_lock/lock_controller.dart';
import '../books/books_providers.dart'
    show currentBookIdProvider, reportsRepositoryProvider;
import '../categories/categories_page.dart' show categoriesViewModelProvider;
import '../reports/reports_page.dart' show ReportWindow, reportRatesProvider;

/// 日历视图（BK-DOC-26 需求6：日历并入报表页；原 Spec §4.6 / BK-T-015）：
/// 月历日格显示收支净额（复用报表按日聚合），**点击日在下方滑动展开当日明细**
/// （BK-DOC-28 需求2）；月份切换懒加载（仅拉取可见月份区间）。
/// 原 30 天现金流趋势图已按 BK-DOC-28 需求1 移除，槽位由明细面板接管。
/// 以 [CalendarPage] 形式嵌入报表页「日历」视图（无内层 Scaffold/AppBar）。
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  /// 当日明细面板展开态（需求2）：进入日历默认选中今天且面板收起，
  /// 不占视觉焦点；点日展开、同日再点收起。
  bool _panelExpanded = false;

  /// 当前视图的按日聚合取数窗口：聚焦月整月（月份懒加载，Spec §4.6）。
  /// 月/双周切换已移除：双周视图需跨月取数、口径特殊且信息密度低，
  /// 月历已完整覆盖需求；固定单格式也避免误触导致视图跳变。
  ReportWindow get _window {
    return (
      start: DateTime(_focusedDay.year, _focusedDay.month),
      end: DateTime(_focusedDay.year, _focusedDay.month + 1),
    );
  }

  /// 点日 / 长按日（需求2）：更新选中日并展开面板；同一日再点则收起。
  /// 展开态下改选他日不收起，面板内容由 [AnimatedSwitcher] 平滑切换。
  void _activateDay(DateTime day) {
    setState(() {
      if (_panelExpanded && isSameDay(day, _selectedDay)) {
        _panelExpanded = false;
      } else {
        _selectedDay = day;
        _panelExpanded = true;
      }
    });
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
          onSelected: _activateDay,
          onFocused: (day) => setState(() => _focusedDay = day),
        ),
        // 需求1/2：现金流趋势图槽位由当日明细面板接管——自日历下缘滑动展开，
        // 收起时高度归零（下方留白，不显示空占位）
        Expanded(child: _detailPanelSlot()),
      ],
    );
  }

  /// 明细面板槽位：`Align` 提供松散约束使 [AnimatedSize] 得以按子高度补间
  /// （`Expanded` 的紧约束会令其尺寸恒定、动画失效）；`ClipRect` 把始终按
  /// 满高布局的面板裁到当前动画高度，形成自上而下的展开揭示。
  Widget _detailPanelSlot() {
    return LayoutBuilder(
      builder: (context, constraints) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedSize(
            duration: GlassMotion.state,
            curve: GlassMotion.curve,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth,
              height: _panelExpanded ? constraints.maxHeight : 0,
              // 展开态下改选日期：以日为 key 淡入淡出切换，内容不闪断（AC2-2）
              child: _panelExpanded
                  ? AnimatedSwitcher(
                      duration: GlassMotion.state,
                      switchInCurve: GlassMotion.curve,
                      switchOutCurve: GlassMotion.curve,
                      child: _DayDetailPanel(
                        key: ValueKey(_dayStamp(_selectedDay)),
                        day: _dayStamp(_selectedDay),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 当日零点：`dayTransactionsProvider` 的 family key 与面板内容切换 key 共用，
/// 避免携带时分秒（如初始 `DateTime.now()`）导致同一日重复取数
DateTime _dayStamp(DateTime day) => DateTime(day.year, day.month, day.day);

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
      // 单击 → 更新选中日并在日历下方展开当日明细（需求2；只读角色可查看）
      onDaySelected: (selected, focused) {
        onSelected(selected);
        onFocused(focused);
      },
      // 长按 → 与单击同语义（更新选中 + 展开面板），保留手势兼容
      onDayLongPressed: (day, focused) {
        onSelected(day);
        onFocused(focused);
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

/// 当日流水（需求2）：由原 `DayDetailSheet` 的内联查询抽出，供日历下方明细
/// 面板复用；口径与原弹窗一致——当前账本、未删除、当日 `[零点, 次日零点)`、
/// 按 `occurredAt` 升序。watch 账本版本号：保存/删除/同步合并后自动刷新。
final dayTransactionsProvider =
    FutureProvider.family<List<Transaction>, DateTime>((ref, day) async {
  ref.watch(ledgerVersionProvider);
  final db = ref.watch(databaseProvider);
  final bookId = ref.watch(currentBookIdProvider);
  final start = _dayStamp(day);
  final end = start.add(const Duration(days: 1));
  return (db.select(db.transactions)
        ..where((t) =>
            t.bookId.equals(bookId) &
            t.deletedAt.isNull() &
            t.occurredAt.isBiggerOrEqualValue(start) &
            t.occurredAt.isSmallerThanValue(end))
        ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
      .get();
});

const _weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 当日明细面板（需求2）：替代原底部弹窗，当日净额与逐笔流水原地可见、
/// 不打断月历浏览上下文。容器与图表区同规格（`GlassPanel` G2）；明细多时
/// 面板内独立滚动，不撑爆页面。`viewer` 只读——纯展示列表，无写入口。
class _DayDetailPanel extends ConsumerWidget {
  const _DayDetailPanel({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(dayTransactionsProvider(day));
    final masked = ref.watch(amountMaskProvider);
    // 分类名/图标客户端解析（与账单行同口径：「父类 / 子类」路径）
    final categories = ref.watch(categoriesViewModelProvider).maybeWhen(
          data: (list) => {for (final c in list) c.id: c},
          orElse: () => const <int, Category>{},
        );
    return GlassPanel(
      level: GlassLevel.g2,
      padding: EdgeInsets.zero,
      child: txsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('明细加载失败：$e')),
        data: (txs) {
          // 净额口径沿用原弹窗（支出取负、其余取正），与日格净额交叉一致
          final net = txs.fold<int>(
            0,
            (sum, t) => sum +
                (t.type == TransactionType.expense
                    ? -t.amountMinor.abs()
                    : t.amountMinor.abs()),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PanelHeader(day: day, count: txs.length, net: net, masked: masked),
              // 审查 U-10：当日明细惰性构建（大流水量下面板内滚动不卡顿）
              Expanded(
                child: txs.isEmpty
                    ? const _EmptyDay()
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        itemCount: txs.length,
                        itemBuilder: (context, i) => _DayTxTile(
                          tx: txs[i],
                          categories: categories,
                          masked: masked,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 面板头：「M月D日 周X」+ 净额（收入绿/支出红/零中性）+「（N 笔）」；
/// 与账单页日汇总行同视觉层级（titleSmall 加粗主文字色）
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.day,
    required this.count,
    required this.net,
    required this.masked,
  });

  final DateTime day;
  final int count;
  final int net;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final headerStyle = context.text.titleSmall;
    final tone = net > 0
        ? AppAmountTone.income
        : net < 0
            ? AppAmountTone.expense
            : AppAmountTone.neutral;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Row(
        children: [
          Text('${day.month}月${day.day}日 ${_weekdayNames[day.weekday - 1]}',
              style: headerStyle),
          const Spacer(),
          Text('净额', style: headerStyle),
          const SizedBox(width: AppSpacing.xs),
          AppAmountText.minor(
            net,
            masked: masked,
            signed: false,
            tone: tone,
            style: headerStyle,
          ),
          Text(
            '（$count 笔）',
            style: context.text.bodySmall
                ?.copyWith(color: context.palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 当日无记账（AC2-4）：面板仍展开，显示空态文案（净额 ¥0.00 / 0 笔由面板头承载）
class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          '当日无记账记录',
          style: context.text.bodyMedium
              ?.copyWith(color: context.palette.textSecondary),
        ),
      ),
    );
  }
}

/// 面板明细行（需求2：复用账单行视觉）——分类图标 + 名称（含父子路径）+
/// 时间/备注 + 收支语义色等宽金额
class _DayTxTile extends StatelessWidget {
  const _DayTxTile({
    required this.tx,
    required this.categories,
    required this.masked,
  });

  final Transaction tx;
  final Map<int, Category> categories;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final isTransfer = tx.type == TransactionType.transfer;
    final category = tx.categoryId == null ? null : categories[tx.categoryId];
    final parent = category == null ? null : categories[category.parentId];
    final name = isTransfer
        ? '转账'
        : category == null
            ? '未分类'
            : parent == null
                ? category.name
                : '${parent.name} / ${category.name}';
    final icon = isTransfer ? Icons.swap_horiz : categoryIcon(category?.icon ?? '');
    final iconColor =
        category == null ? context.palette.textSecondary : Color(category.color);
    final tone = switch (tx.type) {
      TransactionType.expense => AppAmountTone.expense,
      TransactionType.income => AppAmountTone.income,
      TransactionType.transfer => AppAmountTone.neutral,
    };
    final local = tx.occurredAt.toLocal();
    final time = '${local.hour.toString().padLeft(2, '0')}'
        ':${local.minute.toString().padLeft(2, '0')}';
    final note = tx.note;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.15),
        foregroundColor: iconColor,
        child: Icon(icon, size: 20),
      ),
      title: Text(name),
      subtitle: Text(note == null || note.isEmpty ? time : '$time · $note'),
      trailing: AppAmountText.minor(
        tx.amountMinor,
        masked: masked,
        tone: tone,
        // 与账单行金额同档（BK-DOC-28 需求10）：辅助字号加粗，不压过分类名
        style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
