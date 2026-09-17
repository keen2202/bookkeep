import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money_format.dart';
import '../../data/local/database.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../shared/icons/bk_icon.dart';
import '../../shared/icons/bk_icons.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/glass_tokens.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/utils/category_icon.dart';
import '../../shared/widgets/app_amount_text.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_empty.dart';
import '../../shared/widgets/glass_panel.dart';
import '../auth_lock/lock_controller.dart';
import '../books/books_providers.dart' show currentRoleProvider;
import '../categories/categories_page.dart' show categoriesViewModelProvider;
import 'bill_detail_sheet.dart' show showBillDetailSheet;
import 'bill_filter_sheet.dart' show showBillFilterSheet;
import 'bills_grouping.dart';
import 'bills_providers.dart';

const _weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 账单详情页（默认主页）：按天分组展示每一笔记账（分类/时间/金额），
/// 组头显示当天支出与收入合计。点按行打开详情弹层可修改/删除（viewer 只读）。
/// 无内层 Scaffold/AppBar/FAB（审查 U-1）
class BillsPage extends ConsumerWidget {
  const BillsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(billsViewModelProvider);
    final filter = ref.watch(billFilterProvider);
    final viewer = ref.watch(currentRoleProvider) == 'viewer';
    return bills.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (vm) {
        final days = vm.days;
        if (days.isEmpty) {
          // 筛选后为空：提供一键清除；无流水空态：BK-IC-022 单层主形 + 底栏 CTA。
          if (filter.isActive) {
            return AppEmpty(
              bkName: BkIcons.billEmpty,
              title: '没有符合条件的账单',
              message: '试试清除筛选条件',
              actionLabel: '清除筛选',
              onAction: () =>
                  ref.read(billFilterProvider.notifier).state = filter.clear(),
            );
          }
          return AppEmpty(
            bkName: BkIcons.billEmpty,
            title: viewer ? '暂无账单' : '还没有账单',
            message: viewer ? null : '点击底部 + 记一笔',
          );
        }
        final categoriesAsync = ref.watch(categoriesViewModelProvider);
        final categoryList = categoriesAsync.maybeWhen(
          data: (c) => c,
          orElse: () => const <Category>[],
        );
        final categories = {for (final cat in categoryList) cat.id: cat};
        final masked = ref.watch(amountMaskProvider);
        final rows = <_BillRow>[
          for (final day in days) ...[
            _BillRow.day(day),
            for (final t in day.items) _BillRow.tx(t),
          ],
        ];
        // 审查 U-10：惰性构建；底部留白为末行提供滚动余量
        // Spec R-20：末尾可加载更早流水
        return Column(
          children: [
            _BillFilterBar(
              filter: filter,
              categories: categories,
              onTap: () async {
                final picked = await showBillFilterSheet(
                  context,
                  categories: categoryList,
                  initial: filter,
                );
                if (picked != null) {
                  ref.read(billFilterProvider.notifier).state = picked;
                }
              },
              onClear: () =>
                  ref.read(billFilterProvider.notifier).state = filter.clear(),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: rows.length + (vm.hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == rows.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: TextButton(
                          onPressed: () => ref
                              .read(billsPageSizeProvider.notifier)
                              .state += kBillsPageSize,
                          child: const Text('加载更早的账单'),
                        ),
                      ),
                    );
                  }
                  final row = rows[i];
                  return row.isHeader
                      ? _DayHeader(day: row.day!, masked: masked)
                      : _BillTile(
                          tx: row.tx!,
                          categories: categories,
                          masked: masked,
                          // viewer 权限矩阵：只读，不提供修改/删除入口
                          onTap: viewer
                              ? null
                              : () => showBillDetailSheet(context, tx: row.tx!),
                        );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BillRow {
  const _BillRow.day(this.day)
      : tx = null,
        isHeader = true;
  const _BillRow.tx(this.tx)
      : day = null,
        isHeader = false;

  final BillDay? day;
  final Transaction? tx;
  final bool isHeader;
}

class _BillFilterBar extends StatelessWidget {
  const _BillFilterBar({
    required this.filter,
    required this.categories,
    required this.onTap,
    required this.onClear,
  });

  final BillFilter filter;
  final Map<int, Category> categories;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = _label(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
      child: Row(
        children: [
          Expanded(
            child: GlassPanel(
              level: GlassLevel.g1,
              borderRadius: AppRadius.pillAll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onTap: onTap,
              child: Row(
                children: [
                  BkIcon(
                    BkIcons.billFilter,
                    size: 18,
                    color:
                        filter.isActive ? palette.primary : palette.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: context.text.bodyMedium?.copyWith(
                        color: filter.isActive
                            ? palette.primary
                            : palette.textPrimary,
                        fontWeight: filter.isActive ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (filter.isActive)
            AppButton.text(
              onPressed: onClear,
              child: const Text('清除'),
            ),
        ],
      ),
    );
  }

  String _label(BuildContext context) {
    final parts = <String>[
      if (filter.type != null)
        switch (filter.type!) {
          TransactionType.expense => '支出',
          TransactionType.income => '收入',
          TransactionType.transfer => '转账',
        },
      if (filter.categoryId != null)
        categories[filter.categoryId]?.name ?? '指定分类',
    ];
    return parts.isEmpty ? '筛选' : '筛选：${parts.join(' · ')}';
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.masked});

  final BillDay day;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 日汇总与明细区分（需求）：组头为「日汇总行」——日期与收支合计统一
    // 主文字色（黑色）加粗，金额数字与标题同字号；下方明细行保持常规
    // 列表样式（正文灰度层级），一眼可辨汇总与逐笔记录
    final headerStyle = theme.textTheme.titleSmall
        ?.copyWith(color: context.palette.textPrimary, fontWeight: FontWeight.w600);
    String money(int minor) => masked ? maskedMoney() : formatMoney(minor);
    final showExpense = day.expenseMinor > 0;
    final showIncome = day.incomeMinor > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: Row(
        children: [
          Text('${day.day.month}月${day.day.day}日 ${_weekdayNames[day.day.weekday - 1]}',
              style: headerStyle),
          const Spacer(),
          if (showExpense) ...[
            Text('支出：', style: headerStyle),
            Text(money(day.expenseMinor),
                style:
                    headerStyle?.copyWith(color: context.appColors.expense)),
          ],
          if (showExpense && showIncome)
            Text(' · ', style: headerStyle),
          if (showIncome) ...[
            Text('收入：', style: headerStyle),
            Text(money(day.incomeMinor),
                style:
                    headerStyle?.copyWith(color: context.appColors.income)),
          ],
        ],
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({
    required this.tx,
    required this.categories,
    required this.masked,
    this.onTap,
  });

  final Transaction tx;
  final Map<int, Category> categories;
  final bool masked;

  /// 点按打开账单详情（修改/删除）；null = 只读（viewer）
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isTransfer = tx.type == TransactionType.transfer;
    final category = tx.categoryId == null ? null : categories[tx.categoryId];
    final name = isTransfer
        ? '转账'
        : category == null
            ? '未分类'
            : category.parentId != null && categories[category.parentId] != null
                ? '${categories[category.parentId]!.name} / ${category.name}'
                : category.name;
    // BK-IC-021 产品决策：账单行列表/转账图标继续采用 Material。
    final icon = isTransfer
        ? Icons.swap_horiz
        : categoryIcon(category?.icon ?? '');
    final iconColor = isTransfer
        ? context.palette.textSecondary
        : category == null
            ? context.palette.textSecondary
            : Color(category.color);
    // 金额：等宽数字 + 按交易类型语义着色（UI 重构 Spec §6 AppAmountText）
    final amountTone = switch (tx.type) {
      TransactionType.expense => AppAmountTone.expense,
      TransactionType.income => AppAmountTone.income,
      TransactionType.transfer => AppAmountTone.neutral,
    };
    final local = tx.occurredAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final Widget leadingBody = Icon(icon, size: 20, color: iconColor);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.15),
        foregroundColor: iconColor,
        child: leadingBody,
      ),
      title: Text(name),
      subtitle: Text(tx.note == null || tx.note!.isEmpty ? time : '$time · ${tx.note}'),
      // BK-DOC-28 需求8（冲突 C3，反向调整 BK-DOC-26 需求1）：金额字号降到
      // 与同行分类名称一致（dense ListTile 标题 = bodyMedium），减轻列表压迫感；
      // 保留 w600 字重，等宽数字与收支语义着色由 AppAmountText 保持
      trailing: AppAmountText.minor(
        tx.amountMinor,
        masked: masked,
        tone: amountTone,
        style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      dense: true,
      onTap: onTap,
    );
  }
}
