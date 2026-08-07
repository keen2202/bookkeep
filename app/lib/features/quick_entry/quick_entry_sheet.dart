import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger_version.dart';
import '../../core/utils/money_format.dart';
import '../../data/local/database.dart';
import '../../data/local/tables/categories_table.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../domain/usecases/create_transaction.dart';
import '../../shared/widgets/category_picker.dart';
import '../accounts/account_card.dart' show accountTypeLabel;
import '../accounts/accounts_providers.dart';
import '../books/books_providers.dart'
    show accountRepositoryProvider, budgetRepositoryProvider, transactionRepositoryProvider;
import '../budgets/budget_alert_notifier.dart';
import '../budgets/budget_alert_service.dart';
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
        _controller.selectCategory(defaults.categoryId);
        _controller.selectAccount(defaults.accountId);
      }
    }
    // 账户自动回填（需求：无需手动选账户）：
    // 1) 清理跨账本残留默认（lastDefaults 全局存储，切账本后可能指向他账本账户）
    // 2) 无有效默认 → 自动选当前账本第一个账户
    // 所有判断在 await 之后执行：若用户已手动选择则跳过，不覆盖用户操作
    try {
      final vm = await ref.read(accountsViewModelProvider.future);
      final ids = {for (final e in vm.accounts) e.account.id};
      if (_controller.accountId != null && !ids.contains(_controller.accountId)) {
        _controller.selectAccount(null);
      }
      if (_controller.accountId == null && vm.accounts.isNotEmpty) {
        _controller.selectAccount(vm.accounts.first.account.id);
      }
    } catch (_) {
      // 账户加载失败由页面错误态提示，此处静默
    }
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
    // 审查 U-4：保存 busy 锁——连点「确定」不重复入账（controller 内也有 saving 互斥）
    if (_controller.saving) return;
    final ok = await _controller.save();
    if (!mounted) return;
    if (!ok) {
      final message = switch (_controller.error) {
        QuickEntryError.missingSelection => '请选择账户和分类',
        QuickEntryError.saveFailed => '保存失败，请重试',
        _ => '金额无效，请重新输入',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    // 刷新总线：报表/日历/账户/预算 provider 均 watch，自动重建（审查 F-1）
    ref.read(ledgerVersionProvider.notifier).state++;
    // 预算阈值提醒（审查 F-5）：异步评估，失败静默不阻断记账；
    // 全部依赖同步捕获，pop 后 widget 销毁也不影响执行
    final repo = ref.read(budgetRepositoryProvider);
    final notifierFuture = ref.read(budgetAlertNotifierProvider.future);
    unawaited(notifierFuture
        .then((notifier) =>
            BudgetAlertService(repo: repo, notifier: notifier).evaluate())
        .catchError((_) => 0));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesViewModelProvider);
    final accountsAsync = ref.watch(accountsViewModelProvider);
    final categories = categoriesAsync.valueOrNull ?? const <Category>[];
    final accounts = accountsAsync.valueOrNull == null
        ? const <Account>[]
        : [for (final e in accountsAsync.valueOrNull!.accounts) e.account];

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
                _buildSelections(
                  accounts: accounts,
                  accountsLoading: accountsAsync.isLoading,
                  accountsError: accountsAsync.hasError,
                  categories: categories,
                  categoriesLoading: categoriesAsync.isLoading,
                  categoriesError: categoriesAsync.hasError,
                ),
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

  Widget _buildSelections({
    required List<Account> accounts,
    required bool accountsLoading,
    required bool accountsError,
    required List<Category> categories,
    required bool categoriesLoading,
    required bool categoriesError,
  }) {
    if (_controller.type == TransactionType.transfer) {
      return Column(
        children: [
          _AccountField(
            label: '转出账户',
            accounts: accounts,
            loading: accountsLoading,
            error: accountsError,
            onRetry: () => ref.invalidate(accountsViewModelProvider),
            value: _controller.accountId,
            onChanged: _controller.selectAccount,
          ),
          _AccountField(
            label: '转入账户',
            accounts: accounts,
            loading: accountsLoading,
            error: accountsError,
            onRetry: () => ref.invalidate(accountsViewModelProvider),
            value: _controller.toAccountId,
            onChanged: _controller.selectToAccount,
          ),
        ],
      );
    }
    final kind = _controller.type == TransactionType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final kindCategories = categories.where((c) => c.kind == kind).toList();
    return Column(
      children: [
        _AccountField(
          label: '账户',
          accounts: accounts,
          loading: accountsLoading,
          error: accountsError,
          onRetry: () => ref.invalidate(accountsViewModelProvider),
          value: _controller.accountId,
          onChanged: _controller.selectAccount,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CategoryField(
                categories: kindCategories,
                kind: kind,
                loading: categoriesLoading,
                error: categoriesError,
                onRetry: () => ref.invalidate(categoriesViewModelProvider),
                selectedId: _controller.categoryId,
                onSelected: _controller.selectCategory,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 账户选择字段：加载/错误/空态有明确占位，避免空 items 时下拉被禁用而无反馈
class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.label,
    required this.accounts,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<Account> accounts;
  final bool loading;
  final bool error;
  final VoidCallback onRetry;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _LoadingField(label: label);
    }
    if (error) {
      return _MessageField(label: label, message: '账户加载失败，点按重试', onTap: onRetry);
    }
    if (accounts.isEmpty) {
      return const _MessageField(label: '账户', message: '暂无账户，请先在账户页创建');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<int>(
        // initialValue 只在 FormField 首次建树时生效，异步回填默认账户后需换 key 重建 State 才能回显
        key: ValueKey(value),
        // 默认账户可能来自其他账本（不在当前下拉 items 中），此时置空避免 debug assert
        initialValue: accounts.any((a) => a.id == value) ? value : null,
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

/// 分类选择字段：点击弹出两级分类选择器（底部弹层）
class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.categories,
    required this.kind,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final CategoryKind kind;
  final bool loading;
  final bool error;
  final VoidCallback onRetry;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  String? get _selectedLabel {
    final id = selectedId;
    if (id == null) return null;
    for (final c in categories) {
      if (c.id != id) continue;
      final parent = c.parentId == null
          ? null
          : categories.where((x) => x.id == c.parentId).firstOrNull;
      return parent == null ? c.name : '${parent.name} / ${c.name}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _LoadingField(label: '分类');
    }
    if (error) {
      return _MessageField(label: '分类', message: '分类加载失败，点按重试', onTap: onRetry);
    }
    if (categories.isEmpty) {
      return const _MessageField(label: '分类', message: '暂无分类，请先创建');
    }
    final label = _selectedLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _openPicker(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: '分类',
            suffixIcon: const Icon(Icons.expand_more),
          ),
          child: Text(
            label ?? '选择分类',
            style: TextStyle(color: label == null ? Theme.of(context).hintColor : null),
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      Text('选择分类', style: Theme.of(sheetContext).textTheme.titleMedium),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: CategoryPicker(
                      categories: categories,
                      kind: kind,
                      initialCategoryId: selectedId,
                      onSelected: (id) {
                        onSelected(id);
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 加载中占位（与 InputDecorator 视觉一致）
class _LoadingField extends StatelessWidget {
  const _LoadingField({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// 错误/空态占位（可点按重试）
class _MessageField extends StatelessWidget {
  const _MessageField({required this.label, required this.message, this.onTap});

  final String label;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
