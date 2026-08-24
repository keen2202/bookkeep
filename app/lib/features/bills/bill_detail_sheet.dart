import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger_version.dart';
import '../../data/local/database.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/utils/category_icon.dart';
import '../../shared/widgets/app_amount_text.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/app_snack.dart';
import '../accounts/accounts_providers.dart';
import '../books/books_providers.dart' show transactionRepositoryProvider;
import '../categories/categories_page.dart' show categoriesViewModelProvider;
import '../quick_entry/quick_entry_controller.dart';
import '../quick_entry/quick_entry_sheet.dart' show openBillEditor;

/// 打开账单详情弹层（账单页行点按入口）：展示明细并提供「修改 / 删除」
Future<void> showBillDetailSheet(BuildContext context, {required Transaction tx}) {
  return showAppSheet(
    context,
    title: '账单详情',
    child: BillDetailSheet(tx: tx),
  );
}

/// 账单详情弹层（账单页「修改/删除」功能入口）：
/// 展示分类/账户/时间/备注明细；修改复用极速记账编辑页，
/// 删除经确认后软删（收支单行 / 转账双边），经刷新总线自动重建各页面。
class BillDetailSheet extends ConsumerStatefulWidget {
  const BillDetailSheet({super.key, required this.tx});

  final Transaction tx;

  @override
  ConsumerState<BillDetailSheet> createState() => _BillDetailSheetState();
}

class _BillDetailSheetState extends ConsumerState<BillDetailSheet> {
  /// 转账对侧行解析（收支行恒为 null）；initState 异步加载，失败不阻断详情展示
  late final Future<({Transaction from, Transaction? to})?> _pairFuture;

  @override
  void initState() {
    super.initState();
    _pairFuture = widget.tx.type == TransactionType.transfer
        ? ref.read(transactionRepositoryProvider).loadTransferPair(widget.tx.id)
        : Future.value(null);
  }

  bool get _isTransfer => widget.tx.type == TransactionType.transfer;

  String get _typeLabel => switch (widget.tx.type) {
        TransactionType.expense => '支出',
        TransactionType.income => '收入',
        TransactionType.transfer => '转账',
      };

  String get _timeLabel {
    final t = widget.tx.occurredAt.toLocal();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${p(t.month)}-${p(t.day)} ${p(t.hour)}:${p(t.minute)}';
  }

  Future<void> _edit() async {
    final pair = await _pairFuture;
    if (!mounted) return;
    final saved = await openBillEditor(
      context,
      EditTarget(tx: widget.tx, pair: pair?.to),
    );
    if (!mounted) return;
    if (saved) {
      // 刷新总线（审查 F-1）：账单/报表/日历/账户 provider 均 watch 自动重建
      ref.read(ledgerVersionProvider.notifier).state++;
      AppSnack.success(context, '已保存');
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final ok = await showAppConfirm(
      context,
      title: '删除账单',
      content: _isTransfer ? '将删除该笔转账的双边流水，确定删除？' : '确定删除这笔账单？',
      confirmText: '确认删除',
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      final repo = ref.read(transactionRepositoryProvider);
      if (_isTransfer) {
        await repo.deleteTransferPair(widget.tx.id);
      } else {
        await repo.deleteTransaction(widget.tx.id);
      }
      ref.read(ledgerVersionProvider.notifier).state++;
      if (!mounted) return;
      AppSnack.success(context, '已删除');
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) AppSnack.error(context, '删除失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesViewModelProvider);
    final categories = categoriesAsync.maybeWhen(
      data: (c) => {for (final cat in c) cat.id: cat},
      orElse: () => const <int, Category>{},
    );
    final accountsAsync = ref.watch(accountsViewModelProvider);
    final accounts = accountsAsync.maybeWhen(
      data: (vm) => {for (final e in vm.accounts) e.account.id: e.account.name},
      orElse: () => const <int, String>{},
    );

    final category =
        widget.tx.categoryId == null ? null : categories[widget.tx.categoryId];
    final name = _isTransfer
        ? '转账'
        : category == null
            ? '未分类'
            : category.parentId != null && categories[category.parentId] != null
                ? '${categories[category.parentId]!.name} / ${category.name}'
                : category.name;
    final icon = _isTransfer ? Icons.swap_horiz : categoryIcon(category?.icon ?? '');
    final iconColor =
        category == null ? context.palette.textSecondary : Color(category.color);
    final amountTone = switch (widget.tx.type) {
      TransactionType.expense => AppAmountTone.expense,
      TransactionType.income => AppAmountTone.income,
      TransactionType.transfer => AppAmountTone.neutral,
    };
    final note = (widget.tx.note == null || widget.tx.note!.isEmpty)
        ? '—'
        : widget.tx.note!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 头部：分类图标 + 名称/类型 · 时间 + 大金额
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: iconColor.withValues(alpha: 0.15),
                foregroundColor: iconColor,
                child: Icon(icon, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('$_typeLabel · $_timeLabel',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: context.palette.textSecondary)),
                  ],
                ),
              ),
              AppAmountText.minor(widget.tx.amountMinor,
                  masked: false, tone: amountTone, large: true),
            ],
          ),
        ),
        // 转账：两侧账户均按配对流水解析（点按行可能任一侧）
        if (_isTransfer)
          FutureBuilder<({Transaction from, Transaction? to})?>(
            future: _pairFuture,
            builder: (context, snap) {
              final from = snap.data?.from;
              final to = snap.data?.to;
              return Column(
                children: [
                  _InfoRow(
                      label: '转出账户',
                      value: from == null ? '…' : accounts[from.accountId] ?? '未知账户'),
                  _InfoRow(
                      label: '转入账户',
                      value: to == null ? '…' : accounts[to.accountId] ?? '未知账户'),
                ],
              );
            },
          )
        else ...[
          _InfoRow(label: '账户', value: accounts[widget.tx.accountId] ?? '未知账户'),
          _InfoRow(label: '分类', value: name),
        ],
        _InfoRow(label: '备注', value: note),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                onPressed: _edit,
                child: const Text('修改'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton.danger(
                onPressed: _delete,
                child: const Text('删除'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: context.palette.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
