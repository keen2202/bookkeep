import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money_format.dart';
import '../../data/local/database.dart';
import '../../data/local/tables/accounts_table.dart';
import '../auth_lock/lock_controller.dart';

const _typeIcons = {
  AccountType.cash: Icons.payments_outlined,
  AccountType.savings: Icons.savings_outlined,
  AccountType.credit: Icons.credit_card,
  AccountType.storedValue: Icons.card_giftcard,
  AccountType.eWallet: Icons.account_balance_wallet_outlined,
  AccountType.liability: Icons.trending_down,
};

const _typeLabels = {
  AccountType.cash: '现金',
  AccountType.savings: '储蓄卡',
  AccountType.credit: '信用卡',
  AccountType.storedValue: '储值卡',
  AccountType.eWallet: '电子钱包',
  AccountType.liability: '负债',
};

IconData accountTypeIcon(AccountType type) => _typeIcons[type] ?? Icons.account_balance;

String accountTypeLabel(AccountType type) => _typeLabels[type] ?? type.name;

/// 账户卡片（Spec §3.2；金额脱敏由隐私锁模块注入，BK-T-008）
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key, required this.account, required this.balance});

  final Account account;
  final int balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(accountTypeIcon(account.accountType)),
        ),
        title: Text(account.name),
        subtitle: Text(accountTypeLabel(account.accountType)),
        trailing: Text(
          ref.watch(amountMaskProvider) ? maskedMoney() : formatMoney(balance),
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
