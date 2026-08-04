import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/budget_progress_calculator.dart';
import '../../features/quick_entry/amount_parser.dart';
import '../books/books_providers.dart' show budgetRepositoryProvider;
import '../categories/categories_page.dart' show categoriesViewModelProvider;
import 'budgets_page.dart' show budgetsViewModelProvider;

/// 新建/编辑预算（Spec §3.4）：总预算或一级分类预算，月起始日取自当前周期
class BudgetEditSheet extends ConsumerStatefulWidget {
  const BudgetEditSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const BudgetEditSheet(),
      ),
    );
  }

  @override
  ConsumerState<BudgetEditSheet> createState() => _BudgetEditSheetState();
}

class _BudgetEditSheetState extends ConsumerState<BudgetEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _thresholdController = TextEditingController(text: '80');
  bool _isTotal = true;
  int? _categoryId;
  bool _saving = false;

  static const _monthStartDay = 1;

  @override
  void dispose() {
    _amountController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isTotal && _categoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请选择分类')));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(budgetRepositoryProvider);
    final window = BudgetProgressCalculator.periodWindow(
      DateTime.now(),
      monthStartDay: _monthStartDay,
    );
    final period = _dayKey(window.start);
    try {
      await repo.createBudget(
        categoryId: _isTotal ? null : _categoryId,
        period: period,
        amountMinor: AmountParser.parse(_amountController.text)!,
        threshold: int.parse(_thresholdController.text),
      );
      ref.invalidate(budgetsViewModelProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _dayKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesViewModelProvider);
    final parents = categoriesAsync.maybeWhen(
      data: (list) =>
          list.where((c) => c.parentId == null && c.kind.name == 'expense').toList(),
      orElse: () => const [],
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('新建预算', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('总预算')),
                ButtonSegment(value: false, label: Text('分类预算')),
              ],
              selected: {_isTotal},
              onSelectionChanged: (s) => setState(() => _isTotal = s.first),
            ),
            const SizedBox(height: 12),
            if (!_isTotal)
              DropdownButtonFormField<int>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: '分类'),
                items: [
                  for (final c in parents)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: '预算金额（元）', prefixText: '¥ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) =>
                  AmountParser.parse(v ?? '') == null ? '金额格式不正确' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _thresholdController,
              decoration: const InputDecoration(labelText: '预警阈值（%）'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 1 || n > 100) ? '阈值应为 1-100' : null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}
