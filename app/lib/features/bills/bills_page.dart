import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money_format.dart';
import '../../data/local/database.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/utils/category_icon.dart';
import '../../shared/widgets/app_amount_text.dart';
import '../../shared/widgets/app_empty.dart';
import '../auth_lock/lock_controller.dart';
import '../books/books_providers.dart' show currentRoleProvider;
import '../categories/categories_page.dart' show categoriesViewModelProvider;
import 'bill_detail_sheet.dart' show showBillDetailSheet;
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
    final viewer = ref.watch(currentRoleProvider) == 'viewer';
    return bills.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (days) {
        if (days.isEmpty) {
          // 统一空态（Spec §6 AppEmpty）
          return AppEmpty(
            icon: Icons.receipt_long_outlined,
            title: viewer ? '暂无账单' : '还没有账单',
            message: viewer ? null : '点击右下角 + 记一笔',
          );
        }
        final categoriesAsync = ref.watch(categoriesViewModelProvider);
        final categories = categoriesAsync.maybeWhen(
          data: (c) => {for (final cat in c) cat.id: cat},
          orElse: () => const <int, Category>{},
        );
        final masked = ref.watch(amountMaskProvider);
        final rows = <_BillRow>[
          for (final day in days) ...[
            _BillRow.day(day),
            for (final t in day.items) _BillRow.tx(t),
          ],
        ];
        // 审查 U-10：惰性构建；底部留白防 FAB 遮挡
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = rows[i];
            return row.isHeader
                ? _DayHeader(day: row.day!, masked: masked)
                : _BillTile(
                    tx: row.tx!,
                    categories: categories,
                    masked: masked,
                    // viewer 权限矩阵：只读，不提供修改/删除入口
                    onTap: viewer ? null : () => showBillDetailSheet(context, tx: row.tx!),
                  );
          },
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
    final icon = isTransfer
        ? Icons.swap_horiz
        : categoryIcon(category?.icon ?? '');
    final iconColor = category == null ? context.palette.textSecondary : Color(category.color);
    // 金额：等宽数字 + 按交易类型语义着色（UI 重构 Spec §6 AppAmountText）
    final amountTone = switch (tx.type) {
      TransactionType.expense => AppAmountTone.expense,
      TransactionType.income => AppAmountTone.income,
      TransactionType.transfer => AppAmountTone.neutral,
    };
    final local = tx.occurredAt.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.15),
        foregroundColor: iconColor,
        child: Icon(icon, size: 20),
      ),
      title: Text(name),
      subtitle: Text(tx.note == null || tx.note!.isEmpty ? time : '$time · ${tx.note}'),
      trailing: AppAmountText.minor(tx.amountMinor, masked: masked, tone: amountTone),
      dense: true,
      onTap: onTap,
    );
  }
}
