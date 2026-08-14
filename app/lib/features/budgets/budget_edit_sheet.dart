import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../domain/services/budget_progress_calculator.dart';
import '../../features/quick_entry/amount_parser.dart';
import '../../shared/widgets/app_button.dart';
import '../books/books_providers.dart' show budgetRepositoryProvider;
import '../categories/categories_page.dart' show categoriesViewModelProvider;
import 'budget_providers.dart' show budgetsViewModelProvider, monthBudgetSummaryProvider;

/// 新建/编辑预算（Spec §3.4 / 审查 F-10）：总预算或一级分类预算，月起始日取自当前周期；
/// 编辑模式（[budget] 非空）可改金额/阈值/分类并删除
class BudgetEditSheet extends ConsumerStatefulWidget {
  const BudgetEditSheet({super.key, this.budget});

  final Budget? budget;

  static Future<void> show(BuildContext context, {Budget? budget}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: BudgetEditSheet(budget: budget),
      ),
    );
  }

  @override
  ConsumerState<BudgetEditSheet> createState() => _BudgetEditSheetState();
}

class _BudgetEditSheetState extends ConsumerState<BudgetEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _thresholdController;
  late bool _isTotal;
  int? _categoryId;
  bool _saving = false;

  static const _monthStartDay = 1;

  bool get _isEdit => widget.budget != null;

  @override
  void initState() {
    super.initState();
    final budget = widget.budget;
    _amountController = TextEditingController(
      text: budget == null ? '' : (budget.amountMinor / 100).toStringAsFixed(2),
    );
    _thresholdController = TextEditingController(
      text: (budget?.threshold ?? 80).toString(),
    );
    _isTotal = budget?.categoryId == null;
    _categoryId = budget?.categoryId;
  }

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
    final amount = AmountParser.parse(_amountController.text)!;
    final threshold = int.parse(_thresholdController.text);
    final categoryId = _isTotal ? null : _categoryId;
    try {
      // 审查 F-10：同分类唯一（总预算互斥）——同一分类/总预算只允许一条
      final existing = await repo.listBudgets();
      final conflict = existing.any(
        (b) => b.id != widget.budget?.id && b.categoryId == categoryId,
      );
      if (conflict) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('该分类已有预算，请先编辑或删除原预算')),
          );
        }
        return;
      }
      if (_isEdit) {
        await repo.updateBudget(
          widget.budget!.id,
          amountMinor: amount,
          threshold: threshold,
        );
      } else {
        await repo.createBudget(
          categoryId: categoryId,
          period: period,
          amountMinor: amount,
          threshold: threshold,
        );
      }
      ref.invalidate(budgetsViewModelProvider);
      ref.invalidate(monthBudgetSummaryProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除预算'),
        content: const Text('删除后该预算的提醒记录一并失效，确定删除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          AppButton.danger(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(budgetRepositoryProvider).deleteBudget(widget.budget!.id);
      ref.invalidate(budgetsViewModelProvider);
      ref.invalidate(monthBudgetSummaryProvider);
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
            Text(_isEdit ? '编辑预算' : '新建预算', style: Theme.of(context).textTheme.titleLarge),
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
                initialValue: _categoryId,
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
            AppButton.primary(
              block: true,
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存'),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              AppButton.danger(
                onPressed: _saving ? null : _delete,
                child: const Text('删除预算'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
