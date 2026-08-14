import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger_version.dart';
import '../../core/utils/money_format.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../data/local/database.dart';
import '../../data/local/database_provider.dart';
import '../accounts/account_card.dart' show accountTypeLabel;
import '../accounts/accounts_providers.dart';
import '../books/books_providers.dart' show currentBookIdProvider, currentRoleProvider;
import 'anchor_resolver.dart';
import 'recurring_engine.dart';
import 'recurring_providers.dart';

/// 立即补跑全部到期规则（主 shell AppBar 动作；生成流水后 bump 刷新总线）
Future<void> runAllRecurringRules(WidgetRef ref) async {
  final bookId = ref.read(currentBookIdProvider);
  await ref.read(recurringServiceProvider).runAll(bookId: bookId);
  // 补跑生成了流水：规则 nextDue 前移 + 全页（账户/预算/报表）经总线刷新
  ref.invalidate(recurringRulesProvider);
  ref.read(ledgerVersionProvider.notifier).state++;
}

/// 主 shell AppBar 动作：新建规则 + 立即补跑（viewer 只读 → 空，Spec §4.1 双重拒绝）
List<Widget> recurringPageActions(BuildContext context, WidgetRef ref) {
  if (ref.watch(currentRoleProvider) == 'viewer') return const [];
  return [
    IconButton(
      tooltip: '新建规则',
      icon: const Icon(Icons.add),
      onPressed: () => RuleEditSheet.show(context),
    ),
    IconButton(
      tooltip: '立即补跑',
      icon: const Icon(Icons.play_arrow),
      onPressed: () => runAllRecurringRules(ref),
    ),
  ];
}

/// 周期/分期记账页（Spec §4.4 / BK-T-013）：规则列表 + 新建规则 + 立即补跑
class RecurringPage extends ConsumerStatefulWidget {
  const RecurringPage({super.key});

  @override
  ConsumerState<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends ConsumerState<RecurringPage> {
  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(recurringRulesProvider);
    return rulesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      // 审查 U-10：ListTile.builder 惰性构建
      data: (rules) => rules.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('还没有周期规则，点击右上角 + 新建')),
            )
          : ListView.builder(
              itemCount: rules.length,
              itemBuilder: (context, i) {
                final rule = rules[i];
                return ListTile(
                  leading: Icon(
                    rule.type == 'income' ? Icons.trending_up : Icons.repeat,
                    color: rule.type == 'income'
                        ? context.appColors.income
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                      '${_freqLabel(rule)} · ${rule.type == 'income' ? '收入' : '支出'} ${formatMoney(rule.amountMinor)}'),
                  subtitle: Text(_ruleSummary(rule)),
                  trailing: const Icon(Icons.schedule),
                );
              },
            ),
    );
  }

  String _freqLabel(RecurringRule rule) {
    final freq = RecurringFrequency.values
        .firstWhere((f) => f.name == rule.frequency, orElse: () => RecurringFrequency.month);
    return freq.label;
  }

  RecurringRuleSpec _ruleSpec(RecurringRule rule) {
    return RecurringRuleSpec(
      frequency: RecurringFrequency.values
          .firstWhere((f) => f.name == rule.frequency, orElse: () => RecurringFrequency.month),
      interval: rule.interval,
      anchorType: AnchorType.values
          .firstWhere((a) => a.name == rule.anchorType, orElse: () => AnchorType.start),
      anchorDay: rule.anchorDay,
      startDate: rule.startDate,
      endDate: rule.endDate,
    );
  }

  /// 下次记账时间：按规则实际频率/锚点计算（不依赖存储的 nextDue 游标）
  DateTime? _nextDue(RecurringRule rule) {
    return const RecurringEngine().firstDueAfter(_ruleSpec(rule), DateTime.now());
  }

  String _ruleSummary(RecurringRule rule) {
    final anchor = switch (rule.anchorType) {
      'start' => '期初',
      'middle' => '期中',
      'end' => '期末',
      _ => '第${rule.anchorDay}日',
    };
    final time = '${(rule.timeOfDay ~/ 60).toString().padLeft(2, '0')}:'
        '${(rule.timeOfDay % 60).toString().padLeft(2, '0')}';
    final next = _nextDue(rule);
    final nextLabel = next == null
        ? '已结束'
        : '下次 ${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
    return '锚点：$anchor · 入账 $time · $nextLabel';
  }
}

/// 新建周期规则（Spec §4.4）：频率 → 按频率渲染锚点选项（月/季含三项快捷锚点）
class RuleEditSheet extends ConsumerStatefulWidget {
  const RuleEditSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // 审查 U-4：键盘弹起时内容整体上移（viewInsets 补偿）
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: const SafeArea(child: RuleEditSheet()),
      ),
    );
  }

  @override
  ConsumerState<RuleEditSheet> createState() => _RuleEditSheetState();
}

class _RuleEditSheetState extends ConsumerState<RuleEditSheet> {
  RecurringFrequency _frequency = RecurringFrequency.month;
  AnchorType _anchor = AnchorType.start;
  int _anchorDay = 1;
  int? _accountId;
  // 审查 F-7：周期规则收支类型
  String _type = 'expense';
  final _amountCtrl = TextEditingController();

  /// 各频率的锚点选项（Spec §4.4 验证标准清单）
  List<(AnchorType, String)> get _anchorOptions => switch (_frequency) {
        RecurringFrequency.day => const [(AnchorType.start, '每天')],
        RecurringFrequency.week => const [
            (AnchorType.custom, '周一'),
            (AnchorType.custom, '周二'),
            (AnchorType.custom, '周三'),
            (AnchorType.custom, '周四'),
            (AnchorType.custom, '周五'),
            (AnchorType.custom, '周六'),
            (AnchorType.custom, '周日'),
          ],
        RecurringFrequency.month => const [
            (AnchorType.start, '月初（1日）'),
            (AnchorType.middle, '月中（15日）'),
            (AnchorType.end, '月末（最后一日）'),
            (AnchorType.custom, '自定义日期'),
          ],
        RecurringFrequency.quarter => const [
            (AnchorType.start, '季度初（季度首月1日）'),
            (AnchorType.middle, '季度中（季度次月15日）'),
            (AnchorType.end, '季度末（季度末月最后一日）'),
            (AnchorType.custom, '自定义日期'),
          ],
        RecurringFrequency.year => const [
            (AnchorType.start, '年初（1月1日）'),
            (AnchorType.middle, '年中（7月1日）'),
            (AnchorType.end, '年末（12月31日）'),
            (AnchorType.custom, '自定义日期'),
          ],
      };

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    final vm = ref.read(accountsViewModelProvider).valueOrNull;
    final accountId = _accountId ??
        (vm == null || vm.accounts.isEmpty ? null : vm.accounts.first.account.id);
    if (accountId == null) return;
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 周：选项即周一~周日（anchorDay=1~7）
    final anchorDay =
        _frequency == RecurringFrequency.week ? _anchorDay.clamp(1, 7) : _anchorDay;
    final spec = RecurringRuleSpec(
      frequency: _frequency,
      interval: 1,
      anchorType: _anchor,
      anchorDay: anchorDay,
      startDate: today,
    );
    // 首次到期日作为补跑游标（未来时 catchUp 窗口为空，不会误生成）
    final nextDue = const RecurringEngine().firstDueAfter(spec, today) ?? today;
    await db.into(db.recurringRules).insert(RecurringRulesCompanion.insert(
          frequency: _frequency.name,
          interval: const Value(1),
          anchorType: _anchor.name,
          anchorDay: Value(anchorDay),
          amountMinor: (amount * 100).round(),
          type: Value(_type),
          accountId: accountId,
          categoryId: const Value(null),
          nextDue: nextDue,
          startDate: today,
          bookId: ref.read(currentBookIdProvider),
          updatedAt: DateTime.now().toUtc(),
        ));
    if (!mounted) return;
    // 实时刷新列表（需求：新建后立即显示，无需退出重进）
    ref.invalidate(recurringRulesProvider);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final options = _anchorOptions;
    final accountsAsync = ref.watch(accountsViewModelProvider);
    final accounts = accountsAsync.valueOrNull?.accounts ?? const <({Account account, int balance})>[];
    final effectiveAccountId = _accountId ??
        (accounts.isEmpty ? null : accounts.first.account.id);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('新建周期规则', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('支出')),
              ButtonSegment(value: 'income', label: Text('收入')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          SegmentedButton<RecurringFrequency>(
            segments: [
              for (final f in RecurringFrequency.values)
                ButtonSegment(value: f, label: Text(f.label)),
            ],
            selected: {_frequency},
            onSelectionChanged: (s) => setState(() {
              _frequency = s.first;
              _anchor = AnchorType.start;
            }),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (type, label) in options)
                ChoiceChip(
                  label: Text(label),
                  selected: _anchor == type,
                  onSelected: (_) {
                    setState(() {
                      _anchor = type;
                      if (type == AnchorType.custom) {
                        _anchorDay = _frequency == RecurringFrequency.week ? 1 : 15;
                      }
                    });
                  },
                ),
            ],
          ),
          if (_anchor == AnchorType.custom && _frequency != RecurringFrequency.week) ...[
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '自定义日期（1~31，超月末自动回退）'),
              onChanged: (v) => _anchorDay = int.tryParse(v) ?? 15,
            ),
          ],
          const SizedBox(height: 8),
          if (accounts.isEmpty)
            Text(
              '暂无账户，请先在账户管理中创建',
              style: TextStyle(color: context.appColors.warning),
            )
          else
            DropdownButtonFormField<int>(
              // 异步回填后换 key 重建 State 才能回显（同 quick_entry 的账户字段）
              key: ValueKey(effectiveAccountId),
              initialValue: effectiveAccountId,
              decoration: const InputDecoration(labelText: '入账账户'),
              items: [
                for (final e in accounts)
                  DropdownMenuItem(
                    value: e.account.id,
                    child: Text(
                        '${e.account.name}（${accountTypeLabel(e.account.accountType)}）'),
                  ),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '每期金额（元）'),
          ),
          const SizedBox(height: 16),
          AppButton.primary(
            block: true,
            onPressed: accounts.isEmpty ? null : _save,
            child: const Text('保存规则'),
          ),
        ],
      ),
    );
  }
}
