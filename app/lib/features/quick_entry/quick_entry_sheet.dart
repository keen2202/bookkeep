import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money_format.dart';
import '../../data/local/database.dart';
import '../../data/local/tables/categories_table.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../domain/usecases/create_transaction.dart';
import '../accounts/account_card.dart' show accountTypeLabel;
import '../accounts/accounts_providers.dart';
import '../books/books_providers.dart' show accountRepositoryProvider, transactionRepositoryProvider;
import '../budgets/budgets_page.dart' show budgetsViewModelProvider;
import '../categories/categories_page.dart' show categoriesViewModelProvider;
import 'amount_keyboard.dart';
import 'amount_parser.dart';
import 'quick_entry_controller.dart';

/// 极速记账页（Spec §3.1 / BK-P0-001）：+ → 类型 → 数字键盘 → 分类/账户 → 保存
class QuickEntrySheet extends ConsumerStatefulWidget {
  const QuickEntrySheet({super.key});

  @override
  ConsumerState<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends ConsumerState<QuickEntrySheet> {
  late QuickEntryController _controller;

  @override
  void initState() {
    super.initState();
    // 经 provider 注入当前账本上下文（Spec §4.1：写路径归属当前账本）
    _controller = QuickEntryController(
      createTransaction: CreateTransaction(ref.read(transactionRepositoryProvider)),
      transactionRepository: ref.read(transactionRepositoryProvider),
      accountRepository: ref.read(accountRepositoryProvider),
    );
    _controller.addListener(_onController);
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final repo = ref.read(transactionRepositoryProvider);
    for (final type in [TransactionType.expense, TransactionType.income]) {
      final defaults = await repo.lastDefaults(type);
      if (defaults == null) continue;
      if (type == TransactionType.expense && _controller.categoryId == null) {
        _controller.categoryId = defaults.categoryId;
        _controller.accountId = defaults.accountId;
      }
    }
    if (mounted) setState(() {});
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onController);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await _controller.save();
    if (!mounted) return;
    if (!ok) {
      final message = _controller.error == QuickEntryError.missingSelection
          ? '请选择账户和分类'
          : '金额无效，请重新输入';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    // 记账保存后触发预算重算（Spec §3.4）
    ref.invalidate(budgetsViewModelProvider);
    ref.invalidate(accountsViewModelProvider);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesViewModelProvider);
    final accountsAsync = ref.watch(accountsViewModelProvider);
    final categories =
        categoriesAsync.maybeWhen(data: (c) => c, orElse: () => const <Category>[]);
    final accounts = accountsAsync.maybeWhen(
        data: (vm) => [for (final e in vm.accounts) e.account],
        orElse: () => const <Account>[]);

    return Scaffold(
      appBar: AppBar(title: const Text('记一笔')),
      body: Column(
        children: [
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(value: TransactionType.expense, label: Text('支出')),
              ButtonSegment(value: TransactionType.income, label: Text('收入')),
              ButtonSegment(value: TransactionType.transfer, label: Text('转账')),
            ],
            selected: {_controller.type},
            onSelectionChanged: (s) => _controller.setType(s.first),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _displayAmount,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _controller.error == QuickEntryError.invalidAmount
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildSelections(accounts, categories),
              ],
            ),
          ),
          AmountKeyboard(
            onKey: _controller.pressKey,
            onConfirm: _save,
          ),
        ],
      ),
    );
  }

  String get _displayAmount {
    final parsed = AmountParser.parse(_controller.input);
    if (parsed == null && _controller.input.isNotEmpty) {
      return _controller.input;
    }
    final minor = _controller.type == TransactionType.expense
        ? -(parsed ?? 0)
        : (parsed ?? 0);
    return parsed == null ? '¥0.00' : formatMoney(minor);
  }

  Widget _buildSelections(List<Account> accounts, List<Category> categories) {
    if (_controller.type == TransactionType.transfer) {
      return Column(
        children: [
          _AccountDropdown(
            label: '转出账户',
            accounts: accounts,
            value: _controller.accountId,
            onChanged: (v) => _controller.accountId = v,
          ),
          _AccountDropdown(
            label: '转入账户',
            accounts: accounts,
            value: _controller.toAccountId,
            onChanged: (v) => _controller.toAccountId = v,
          ),
        ],
      );
    }
    final kind = _controller.type == TransactionType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final expenseCategories =
        categories.where((c) => c.kind == kind).toList();
    return Column(
      children: [
        _AccountDropdown(
          label: '账户',
          accounts: accounts,
          value: _controller.accountId,
          onChanged: (v) => _controller.accountId = v,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('分类', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              for (final parent in expenseCategories.where((c) => c.parentId == null))
                _CategoryGroup(
                  parent: parent,
                  categories: expenseCategories,
                  selectedId: _controller.categoryId,
                  onSelected: (id) => _controller.categoryId = id,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({
    required this.label,
    required this.accounts,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<Account> accounts;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<int>(
        // initialValue 只在 FormField 首次建树时生效，异步回填默认账户后需换 key 重建 State 才能回显
        key: ValueKey(value),
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final a in accounts)
            DropdownMenuItem(value: a.id, child: Text('${a.name}（${accountTypeLabel(a.accountType)}）')),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.parent,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final Category parent;
  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final children = categories.where((c) => c.parentId == parent.id).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(parent.name, style: Theme.of(context).textTheme.labelMedium),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final child in children)
              ChoiceChip(
                label: Text(child.name),
                selected: selectedId == child.id,
                onSelected: (_) => onSelected(child.id),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
