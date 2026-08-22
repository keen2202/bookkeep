import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/constants.dart';
import '../../core/ledger_version.dart';
import '../../data/local/database.dart';
import '../../shared/widgets/app_button.dart';
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
          final sorted = [...list]..sort(_byCode);
          return ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, i) => _CurrencyTile(currency: sorted[i]),
          );
        },
      ),
    );
  }

  /// 主币种 CNY 恒在首位，其余按币种代码排序（比较器须全序一致）
  static int _byCode(Currency a, Currency b) {
    const rankCny = 0;
    final ra = a.code == 'CNY' ? rankCny : 1;
    final rb = b.code == 'CNY' ? rankCny : 1;
    if (ra != rb) return ra - rb;
    return a.code.compareTo(b.code);
  }
}

class _CurrencyTile extends ConsumerWidget {
  const _CurrencyTile({required this.currency});

  final Currency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCny = currency.code == 'CNY';
    final rateSet = isCny || currency.rateScaled > 0;
    final rateText =
        isCny ? '1.0（主币种，不可改）' : (currency.rateScaled / kRateScale).toStringAsFixed(4);
    // 显示修复：此前 '$currency.code' 插值只取对象本身，「.code」成了字面量，
    // 副标题渲染成 "1 Currency(...).code = x CNY" 的错误文本。
    final subtitle = isCny
        ? '主币种 · 1 CNY = 1.0'
        : rateSet
            ? '1 ${currency.code} = $rateText CNY'
            // 未设置汇率的折算回退口径与报表一致（CurrencyRepository.rateScaled）
            : '未设置汇率 · 报表暂按 1:1 折算';
    return ListTile(
      leading: CircleAvatar(
        child: Text(currency.symbol.isEmpty ? currency.code[0] : currency.symbol),
      ),
      title: Text('${currency.name}（${currency.code}）'),
      subtitle: Text(subtitle),
      trailing: isCny
          ? null
          : TextButton(
              onPressed: () => _editRate(context, ref),
              child: Text(rateSet ? '修改' : '设置'),
            ),
    );
  }

  Future<void> _editRate(BuildContext context, WidgetRef ref) async {
    String? errorText;
    final controller = TextEditingController(
      text: currency.rateScaled > 0
          ? (currency.rateScaled / kRateScale).toStringAsFixed(4)
          : '',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('${currency.name}（${currency.code}）汇率'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              // 仅允许数字与单个小数点（防「1.2.3」等非法输入进入解析）
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (_) {
              if (errorText != null) setDialogState(() => errorText = null);
            },
            decoration: InputDecoration(
              labelText: '1 ${currency.code} = 多少 CNY',
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            AppButton.primary(
              onPressed: () {
                final raw = controller.text.trim();
                final rate = double.tryParse(raw);
                if (raw.isEmpty || rate == null || rate <= 0) {
                  setDialogState(() => errorText = '请输入大于 0 的数值');
                  return;
                }
                Navigator.pop(dialogContext, raw);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (value == null || !context.mounted) return;
    await ref.read(exchangeRateServiceProvider).setManualRate(currency.code, double.parse(value));
    // 手动汇率生效信号：报表/日历的汇率表 provider watch 此版本号后重建
    ref.read(ledgerVersionProvider.notifier).state++;
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已更新 ${currency.code} 汇率为 $value')));
    }
  }
}
