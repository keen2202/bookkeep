import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../data/local/tables/categories_table.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_choice_chip.dart';
import '../../shared/widgets/app_sheet.dart';
import 'bills_providers.dart';

/// 打开账单筛选弹层（BK-IC-023）。
Future<BillFilter?> showBillFilterSheet(
  BuildContext context, {
  required List<Category> categories,
  required BillFilter initial,
}) {
  return showAppSheet<BillFilter>(
    context,
    title: '筛选账单',
    child: _BillFilterSheet(categories: categories, initial: initial),
  );
}

class _BillFilterSheet extends StatefulWidget {
  const _BillFilterSheet({required this.categories, required this.initial});

  final List<Category> categories;
  final BillFilter initial;

  @override
  State<_BillFilterSheet> createState() => _BillFilterSheetState();
}

class _BillFilterSheetState extends State<_BillFilterSheet> {
  late TransactionType? _type = widget.initial.type;
  late int? _categoryId = widget.initial.categoryId;

  @override
  Widget build(BuildContext context) {
    final parentNames = <int, String>{
      for (final category in widget.categories)
        if (category.parentId == null) category.id: category.name,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('类型', style: context.text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppChoiceChip(
              label: const Text('全部'),
              selected: _type == null,
              onSelected: (_) => setState(() => _type = null),
            ),
            AppChoiceChip(
              label: const Text('支出'),
              selected: _type == TransactionType.expense,
              onSelected: (_) => setState(() {
                _type = TransactionType.expense;
                _categoryId = null;
              }),
            ),
            AppChoiceChip(
              label: const Text('收入'),
              selected: _type == TransactionType.income,
              onSelected: (_) => setState(() {
                _type = TransactionType.income;
                _categoryId = null;
              }),
            ),
            AppChoiceChip(
              label: const Text('转账'),
              selected: _type == TransactionType.transfer,
              onSelected: (_) => setState(() {
                _type = TransactionType.transfer;
                _categoryId = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_type == TransactionType.transfer)
          Text(
            '转账流水不参与分类筛选',
            style: context.text.bodySmall,
          )
        else ...[
          Text('分类', style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          AppChoiceChip(
            label: const Text('全部分类'),
            selected: _categoryId == null,
            onSelected: (_) => setState(() => _categoryId = null),
          ),
          const SizedBox(height: AppSpacing.sm),
          _categorySection(parentNames, CategoryKind.expense, '支出分类'),
          if (widget.categories.any((c) => c.kind == CategoryKind.income)) ...[
            const SizedBox(height: AppSpacing.md),
            _categorySection(parentNames, CategoryKind.income, '收入分类'),
          ],
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                block: true,
                onPressed: () => Navigator.pop(context, const BillFilter()),
                child: const Text('重置'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton.primary(
                block: true,
                onPressed: () => Navigator.pop(
                  context,
                  BillFilter(type: _type, categoryId: _categoryId),
                ),
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _categorySection(
    Map<int, String> parentNames,
    CategoryKind kind,
    String title,
  ) {
    final categories = widget.categories.where((c) => c.kind == kind).toList();
    if (categories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final category in categories)
              AppChoiceChip(
                label: Text(
                  category.parentId == null
                      ? category.name
                      : '${parentNames[category.parentId] ?? ''} / ${category.name}',
                ),
                selected: _categoryId == category.id,
                onSelected: (_) => setState(() {
                  _categoryId = category.id;
                  _type = kind == CategoryKind.expense
                      ? TransactionType.expense
                      : TransactionType.income;
                }),
              ),
          ],
        ),
      ],
    );
  }
}
