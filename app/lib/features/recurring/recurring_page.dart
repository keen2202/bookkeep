import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/database_provider.dart';
import 'anchor_resolver.dart';
import 'recurring_service.dart';

/// 周期/分期记账页（Spec §4.4 / BK-T-013）：规则列表 + 新建规则 + 立即补跑
class RecurringPage extends ConsumerStatefulWidget {
  const RecurringPage({super.key});

  @override
  ConsumerState<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends ConsumerState<RecurringPage> {
  String? _message;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('周期记账'),
        actions: [
          IconButton(
            tooltip: '立即补跑',
            icon: const Icon(Icons.play_arrow),
            onPressed: () async {
              final count = await RecurringService(db).runAll();
              setState(() => _message = '已补跑 $count 笔');
              setState(() {});
            },
          ),
        ],
      ),
      body: FutureBuilder<List<RecurringRule>>(
        future: db.select(db.recurringRules).get(),
        builder: (context, snapshot) {
          final rules = snapshot.data ?? const <RecurringRule>[];
          return ListView(
            children: [
              if (rules.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('还没有周期规则，点击右下角 + 新建')),
                )
              else
                for (final rule in rules)
                  ListTile(
                    leading: const Icon(Icons.repeat),
                    title: Text('${_freqLabel(rule)} · ¥${rule.amountMinor / 100}'),
                    subtitle: Text(_ruleSummary(rule)),
                    trailing: const Icon(Icons.schedule),
                  ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_message!),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => RuleEditSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('新建规则'),
      ),
    );
  }

  String _freqLabel(RecurringRule rule) {
    final freq = RecurringFrequency.values
        .firstWhere((f) => f.name == rule.frequency, orElse: () => RecurringFrequency.month);
    return freq.label;
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
    return '锚点：$anchor · 入账 $time · 下次 ${rule.nextDue.toLocal().toString().substring(0, 10)}';
  }
}

/// 新建周期规则（Spec §4.4）：频率 → 按频率渲染锚点选项（月/季含三项快捷锚点）
class RuleEditSheet extends ConsumerStatefulWidget {
  const RuleEditSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SafeArea(child: RuleEditSheet()),
    );
  }

  @override
  ConsumerState<RuleEditSheet> createState() => _RuleEditSheetState();
}

class _RuleEditSheetState extends ConsumerState<RuleEditSheet> {
  RecurringFrequency _frequency = RecurringFrequency.month;
  AnchorType _anchor = AnchorType.start;
  int _anchorDay = 1;
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
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 周：选项即周一~周日（anchorDay=1~7）
    final anchorDay =
        _frequency == RecurringFrequency.week ? _anchorDay.clamp(1, 7) : _anchorDay;
    await db.into(db.recurringRules).insert(RecurringRulesCompanion.insert(
          frequency: _frequency.name,
          interval: const Value(1),
          anchorType: _anchor.name,
          anchorDay: Value(anchorDay),
          amountMinor: (amount * 100).round(),
          accountId: 1,
          categoryId: const Value(null),
          nextDue: today,
          startDate: today,
          updatedAt: DateTime.now().toUtc(),
        ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final options = _anchorOptions;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('新建周期规则', style: Theme.of(context).textTheme.titleMedium),
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
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '每期金额（元）'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text('保存规则'),
          ),
        ],
      ),
    );
  }
}
