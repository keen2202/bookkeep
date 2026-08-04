import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money_format.dart';
import '../../data/local/database.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../domain/services/capture_candidate.dart';
import '../books/books_providers.dart' show accountRepositoryProvider, transactionRepositoryProvider;
import 'import_service.dart';

/// 自动记账确认页（Spec §4.2 / BK-T-011）：解析结果必须经此页确认才可入账，
/// 禁止静默写入。可调整账户/分类后批量提交（auto_generated 标记）。
class CaptureConfirmPage extends ConsumerStatefulWidget {
  const CaptureConfirmPage({
    super.key,
    required this.candidates,
    this.categoryNameFor,
    this.source,
  });

  final List<CaptureCandidate> candidates;

  /// 建议分类映射（语音/短信可用规则引擎结果；CSV 为空）
  final String? Function(CaptureCandidate)? categoryNameFor;
  final String? source;

  static Future<int> show(
    BuildContext context, {
    required List<CaptureCandidate> candidates,
    String? Function(CaptureCandidate)? categoryNameFor,
    String? source,
  }) async {
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => CaptureConfirmPage(
          candidates: candidates,
          categoryNameFor: categoryNameFor,
          source: source,
        ),
      ),
    );
    return result ?? 0;
  }

  @override
  ConsumerState<CaptureConfirmPage> createState() => _CaptureConfirmPageState();
}

class _CaptureConfirmPageState extends ConsumerState<CaptureConfirmPage> {
  int? _accountId;
  final Map<int, int?> _categoryOverrides = {};

  @override
  void initState() {
    super.initState();
    _loadDefaultAccount();
  }

  Future<void> _loadDefaultAccount() async {
    final accounts = await ref.read(accountRepositoryProvider).listAccounts();
    if (accounts.isNotEmpty && mounted) {
      setState(() => _accountId = accounts.first.id);
    }
  }

  Future<void> _commit() async {
    final accountId = _accountId;
    if (accountId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先选择账户')));
      return;
    }
    final saved = await CsvImportService(ref.read(transactionRepositoryProvider)).commit(
      widget.candidates,
      accountId: accountId,
      categoryResolver: (c) {
        final idx = widget.candidates.indexOf(c);
        return _categoryOverrides[idx];
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已入账 $saved 笔（可在明细中追溯/撤销）')));
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('确认入账（${widget.candidates.length} 笔）'),
        actions: [
          TextButton(
            onPressed: _commit,
            child: const Text('全部入账'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: FutureBuilder<List<Account>>(
              future: ref.read(accountRepositoryProvider).listAccounts(),
              builder: (context, snapshot) {
                final accounts = snapshot.data ?? const <Account>[];
                return DropdownButtonFormField<int>(
                  key: ValueKey(_accountId),
                  initialValue: _accountId,
                  items: [
                    for (final a in accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _accountId = v),
                  decoration: const InputDecoration(labelText: '入账账户'),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.candidates.length,
              itemBuilder: (context, i) {
                final c = widget.candidates[i];
                final suggested = widget.categoryNameFor?.call(c);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    title: Text(
                      '${c.counterparty.isEmpty ? '未命名' : c.counterparty}  '
                      '${_formatAmount(c.amountMinor)}',
                      style: theme.textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      '${c.occurredAt.toLocal()}  '
                      '${suggested == null ? '' : '分类：$suggested'}',
                      style: theme.textTheme.bodySmall,
                    ),
                    leading: Icon(
                      c.type == TransactionType.expense
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: c.type == TransactionType.expense
                          ? theme.colorScheme.error
                          : Colors.green,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(int minor) {
    final sign = minor < 0 ? '-' : '+';
    return '$sign${formatMoney(minor.abs())}';
  }
}
