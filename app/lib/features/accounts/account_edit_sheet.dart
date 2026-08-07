import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/tables/accounts_table.dart';
import '../books/books_providers.dart' show accountRepositoryProvider;
import '../currency/currency_providers.dart';
import 'account_card.dart' show accountTypeLabel;
import 'accounts_providers.dart';

/// 新增/编辑账户（Spec §3.2 / BK-P0-002）
class AccountEditSheet extends ConsumerStatefulWidget {
  const AccountEditSheet({super.key, this.account});

  final Account? account;

  static Future<void> show(BuildContext context, {Account? account}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AccountEditSheet(account: account),
      ),
    );
  }

  @override
  ConsumerState<AccountEditSheet> createState() => _AccountEditSheetState();
}

class _AccountEditSheetState extends ConsumerState<AccountEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late AccountType _type;
  // 审查 F-8：账户币种（转账/报表按账户币种记账与折算）
  late String _currency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.name ?? '');
    _balanceController = TextEditingController(
      text: account == null ? '' : (account.initialBalance / 100).toStringAsFixed(2),
    );
    _type = account?.accountType ?? AccountType.cash;
    _currency = account?.currency ?? 'CNY';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(accountRepositoryProvider);
    final initialBalance = (_parseMinor(_balanceController.text) ?? 0);
    final account = widget.account;
    try {
      if (account == null) {
        await repo.createAccount(
          name: _nameController.text.trim(),
          type: _type,
          currency: _currency,
          initialBalance: initialBalance,
        );
      } else {
        await repo.updateAccount(
          account.id,
          name: _nameController.text.trim(),
          type: _type,
          currency: _currency,
          initialBalance: initialBalance,
        );
      }
      ref.invalidate(accountsViewModelProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// "12.34" → 1234（分）；非法输入返回 null
  int? _parseMinor(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(trimmed);
    if (match == null) return null;
    final parts = trimmed.split('.');
    final yuan = int.parse(parts[0]);
    final cents = parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0;
    return yuan * 100 + cents;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.account == null ? '新建账户' : '编辑账户',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '账户名称'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入账户名称' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '账户类型'),
              items: [
                for (final t in [
                  AccountType.cash,
                  AccountType.savings,
                  AccountType.credit,
                  AccountType.storedValue,
                  AccountType.eWallet,
                ])
                  DropdownMenuItem(value: t, child: Text(accountTypeLabel(t))),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            // 审查 F-8：账户币种选择（转账/报表按币种记账折算）
            FutureBuilder<List<Currency>>(
              future: ref.read(currenciesViewModelProvider.future),
              builder: (context, snapshot) {
                final currencies = snapshot.data ?? const <Currency>[];
                return DropdownButtonFormField<String>(
                  initialValue: currencies.any((c) => c.code == _currency)
                      ? _currency
                      : null,
                  decoration: const InputDecoration(labelText: '币种'),
                  items: [
                    for (final c in currencies)
                      DropdownMenuItem(
                        value: c.code,
                        child: Text('${c.name}（${c.code}）'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _currency = v ?? 'CNY'),
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _balanceController,
              decoration: const InputDecoration(labelText: '初始余额（元）', prefixText: '¥ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              validator: (v) => _parseMinor(v ?? '') == null ? '金额格式不正确' : null,
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
