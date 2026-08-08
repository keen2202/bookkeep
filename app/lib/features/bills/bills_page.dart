import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money_format.dart';
import '../../data/local/database.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/category_icon.dart';
import '../auth_lock/lock_controller.dart';
import '../books/books_providers.dart' show currentRoleProvider;
import '../categories/categories_page.dart' show categoriesViewModelProvider;
import 'bills_grouping.dart';
import 'bills_providers.dart';

const _weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 账单详情页（默认主页）：按天分组展示每一笔记账（分类/时间/金额），
/// 组头显示当天支出与收入合计。无内层 Scaffold/AppBar/FAB（审查 U-1）
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
          return Center(child: Text(viewer ? '暂无账单' : '还没有账单，点击 + 记一笔'));
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
                : _BillTile(tx: row.tx!, categories: categories, masked: masked);
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
    final money = masked ? '***' : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text('${day.day.month}月${day.day.day}日 ${_weekdayNames[day.day.weekday - 1]}',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          if (day.expenseMinor > 0)
            Text('支出 ${money ?? formatMoney(day.expenseMinor)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: context.appColors.expense)),
          if (day.expenseMinor > 0 && day.incomeMinor > 0)
            Text(' · ', style: theme.textTheme.bodySmall),
          if (day.incomeMinor > 0)
            Text('收入 ${money ?? formatMoney(day.incomeMinor)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: context.appColors.income)),
        ],
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.tx, required this.categories, required this.masked});

  final Transaction tx;
  final Map<int, Category> categories;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
    final iconColor = category == null ? theme.colorScheme.onSurfaceVariant : Color(category.color);
    final amount = masked
        ? '***'
        : tx.amountMinor < 0
            ? formatMoney(tx.amountMinor)
            : '+${formatMoney(tx.amountMinor)}';
    final amountColor = switch (tx.type) {
      TransactionType.expense => context.appColors.expense,
      TransactionType.income => context.appColors.income,
      TransactionType.transfer => theme.colorScheme.onSurfaceVariant,
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
      trailing: Text(amount, style: theme.textTheme.titleSmall?.copyWith(color: amountColor)),
      dense: true,
    );
  }
}
