import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger_version.dart';
import '../../core/utils/money_format.dart';
import '../../data/local/database.dart';
import '../../data/local/tables/categories_table.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../domain/usecases/create_transaction.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/app_segmented_button.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/app_snack.dart';
import '../../shared/widgets/category_picker.dart';
import '../../shared/widgets/glass_nav.dart';
import '../accounts/account_card.dart' show accountTypeLabel;
import '../accounts/accounts_providers.dart';
import '../books/books_providers.dart'
    show accountRepositoryProvider, budgetRepositoryProvider, transactionRepositoryProvider;
import '../budgets/budget_alert_notifier.dart';
import '../budgets/budget_alert_service.dart';
import '../budgets/budget_summary_card.dart';
import '../categories/categories_page.dart' show categoriesViewModelProvider;
import 'amount_keyboard.dart';
import 'amount_parser.dart';
import 'quick_entry_controller.dart';

/// 共享导航：打开记账页（底栏中央「记一笔」/ 日历日期跳转共用），
/// 保存成功回传 true 弹「已保存」
Future<void> openQuickEntrySheet(BuildContext context, {DateTime? initialDate}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => QuickEntrySheet(initialDate: initialDate)),
  );
  if (saved == true && context.mounted) {
    AppSnack.success(context, '已保存');
  }
}

/// 共享导航：打开账单编辑页（账单详情页「修改」入口共用），
/// 预填既有记账数据，保存成功回传 true
Future<bool> openBillEditor(BuildContext context, EditTarget target) {
  return Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => QuickEntrySheet(editTarget: target)),
      ).then((saved) => saved == true);
}

/// 极速记账页（Spec §3.1 / BK-P0-001）：+ → 类型 → 数字键盘 → 分类/账户 → 保存；
/// [initialDate] 从日历跳转时预填记账日期（默认当前时刻）；
/// [editTarget] 编辑模式：预填既有流水，保存走更新路径（账单页「修改」入口）
class QuickEntrySheet extends ConsumerStatefulWidget {
  const QuickEntrySheet({super.key, this.initialDate, this.editTarget});

  final DateTime? initialDate;
  final EditTarget? editTarget;

  @override
  ConsumerState<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends ConsumerState<QuickEntrySheet> {
  late QuickEntryController _controller;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    // 经 provider 注入当前账本上下文（Spec §4.1：写路径归属当前账本）
    _controller = QuickEntryController(
      createTransaction: CreateTransaction(ref.read(transactionRepositoryProvider)),
      transactionRepository: ref.read(transactionRepositoryProvider),
      accountRepository: ref.read(accountRepositoryProvider),
      editTarget: widget.editTarget,
      initialOccurredAt: widget.initialDate,
    );
    _controller.addListener(_onController);
    _noteController = TextEditingController(text: _controller.note);
    // 编辑模式直接以既有数据为准，不加载/覆盖 lastDefaults 默认回填
    if (widget.editTarget == null) _loadDefaults();
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
    _noteController.dispose();
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
      AppSnack.error(context, message);
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

    return GlassScaffold(
      title: Text(widget.editTarget != null ? '编辑账单' : '记一笔'),
      // 需求：取消右上角「退出」按钮——返回由系统返回手势/导航返回键承担
      body: Column(
        children: [
          // BK-DOC-28 需求7：选中态去 ✔，改颜色突显（样式收敛于共享组件）；
          // 禁用段（编辑收支时的转账）不受选中色影响
          AppSegmentedButton<TransactionType>(
            segments: [
              ButtonSegment(
                value: TransactionType.expense,
                label: const Text('支出'),
                enabled: !_controller.typeLocked,
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: const Text('收入'),
                enabled: !_controller.typeLocked,
              ),
              ButtonSegment(
                value: TransactionType.transfer,
                label: const Text('转账'),
                // 编辑收支时禁选转账（单行流水不可转双边结构，需删除重记）
                enabled: _controller.transferOptionEnabled && !_controller.typeLocked,
              ),
            ],
            selected: {_controller.type},
            onSelectionChanged: (s) => _controller.setType(s.first),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              _displayAmount,
              // displayAmount 大数字档（设计文档 §3.2，等宽数字）
              style: context.tokens.displayAmountStyle.copyWith(
                color: _controller.error == QuickEntryError.invalidAmount
                    ? context.appColors.expense
                    : null,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (widget.editTarget == null) const BudgetSummaryCard(),
                // 需求：新增记账同样提供备注栏（编辑模式此前已有）
                _buildNoteField(),
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
            onBackspace: _controller.backspace,
            onClear: _controller.clear,
          ),
        ],
      ),
    );
  }

  /// 备注字段（新增/编辑通用）：账单列表展示备注，记一笔即可填写
  Widget _buildNoteField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      child: TextField(
        controller: _noteController,
        onChanged: _controller.setNote,
        decoration: const InputDecoration(
          labelText: '备注',
          hintText: '点击填写备注（可选）',
        ),
        textInputAction: TextInputAction.done,
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
          _DateTimeField(
            occurredAt: _controller.occurredAt,
            onChanged: _controller.setOccurredAt,
          ),
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
        _DateTimeField(
          occurredAt: _controller.occurredAt,
          onChanged: _controller.setOccurredAt,
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
    // AppSheet 统一底部弹层（拖拽柄 / 圆角 lg / scrim 54%，下滑关闭）
    await showAppSheet<void>(
      context,
      title: '选择分类',
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: CategoryPicker(
          categories: categories,
          kind: kind,
          initialCategoryId: selectedId,
          onSelected: (id) {
            onSelected(id);
            Navigator.pop(context);
          },
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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

/// 日期/时间字段：点按弹出 Material 选择器；改日期保留原时间、改时间保留原日期，
/// 秒精度从现有值保留（初始为当前时刻，全精度入库）
class _DateTimeField extends StatelessWidget {
  const _DateTimeField({required this.occurredAt, required this.onChanged});

  final DateTime occurredAt;
  final ValueChanged<DateTime> onChanged;

  String get _dateLabel => '${occurredAt.year}-'
      '${occurredAt.month.toString().padLeft(2, '0')}-'
      '${occurredAt.day.toString().padLeft(2, '0')}';
  String get _timeLabel => '${occurredAt.hour.toString().padLeft(2, '0')}:'
      '${occurredAt.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day,
          occurredAt.hour, occurredAt.minute, occurredAt.second));
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(occurredAt),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked != null) {
      onChanged(DateTime(occurredAt.year, occurredAt.month, occurredAt.day,
          picked.hour, picked.minute, occurredAt.second));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget field({required String label, required String text, required IconData icon, required VoidCallback onTap}) {
      return InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, suffixIcon: Icon(icon)),
          child: Text(text),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: field(
              label: '日期',
              text: _dateLabel,
              icon: Icons.calendar_today_outlined,
              onTap: () => _pickDate(context),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Expanded(
            child: field(
              label: '时间',
              text: _timeLabel,
              icon: Icons.schedule,
              onTap: () => _pickTime(context),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
