import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/database_provider.dart';
import '../../data/repositories/account_repository.dart';
import '../../domain/services/account_balance_calculator.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(databaseProvider));
});

final accountBalanceCalculatorProvider = Provider<AccountBalanceCalculator>((ref) {
  return const AccountBalanceCalculator();
});

/// 账户 + 余额 + 净资产视图模型（隐藏归档账户）
final accountsViewModelProvider = FutureProvider<AccountsViewModel>((ref) async {
  final repo = ref.watch(accountRepositoryProvider);
  final db = ref.watch(databaseProvider);
  final calc = ref.watch(accountBalanceCalculatorProvider);
  final accounts = await repo.listAccounts(includeArchived: false);
  final balances = calc.balancesByAccount(
    accounts: accounts,
    transactions: await db.select(db.transactions).get(),
  );
  final netWorth = calc.netWorth(
    types: {for (final a in accounts) a.id: a.accountType},
    balances: balances,
  );
  return AccountsViewModel(
    accounts: [for (final a in accounts) (account: a, balance: balances[a.id] ?? 0)],
    netWorth: netWorth,
  );
});

class AccountsViewModel {
  const AccountsViewModel({required this.accounts, required this.netWorth});
  final List<({Account account, int balance})> accounts;
  final int netWorth;
}
