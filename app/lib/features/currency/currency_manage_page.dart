import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/constants.dart';
import '../../core/ledger_version.dart';
import '../../data/local/database.dart';
import 'currency_providers.dart';

/// 汇率管理（审查 F-8）：手动录入/修改汇率；未设置汇率显式标注，
/// 不再静默按 0.1 占位折算。CNY 为主币种恒为 1.0 不可改。
class CurrencyManagePage extends ConsumerWidget {
  const CurrencyManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencies = ref.watch(currenciesViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('汇率管理')),
      body: currencies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) {
          final sorted = [...list]..sort((a, b) {
              if (a.code == 'CNY') return -1;
              if (b.code == 'CNY') return 1;
              return a.code.compareTo(b.code);
            });
          return ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, i) => _CurrencyTile(currency: sorted[i]),
          );
        },
      ),
    );
  }
}

class _CurrencyTile extends ConsumerWidget {
  const _CurrencyTile({required this.currency});

  final Currency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCny = currency.code == 'CNY';
    final rateSet = isCny || currency.rateScaled > 0;
    final rateText = isCny
        ? '1.0（主币种）'
        : rateSet
            ? (currency.rateScaled / kRateScale).toStringAsFixed(4)
            : '未设置汇率';
    return ListTile(
      leading: CircleAvatar(
        child: Text(currency.symbol.isEmpty ? currency.code[0] : currency.symbol),
      ),
      title: Text('${currency.name}（${currency.code}）'),
      subtitle: Text(rateSet ? '1 $currency.code = $rateText CNY' : rateText),
      trailing: isCny
          ? null
          : TextButton(
              onPressed: () => _editRate(context, ref),
              child: Text(rateSet ? '修改' : '设置'),
            ),
    );
  }

  Future<void> _editRate(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: currency.rateScaled > 0
          ? (currency.rateScaled / kRateScale).toStringAsFixed(4)
          : '',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${currency.name}（${currency.code}）汇率'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          decoration: const InputDecoration(labelText: '1 币种 = 多少 CNY'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value == null || !context.mounted) return;
    final rate = double.tryParse(value.trim());
    if (rate == null || rate <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入大于 0 的汇率')));
      return;
    }
    await ref.read(exchangeRateServiceProvider).setManualRate(currency.code, rate);
    ref.read(ledgerVersionProvider.notifier).state++;
  }
}
