import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/constants.dart';
import '../../core/ledger_version.dart';
import '../../core/utils/money.dart';
import '../../data/local/database.dart';
import '../../data/local/database_provider.dart';
import '../../domain/services/account_balance_calculator.dart';
import '../books/books_providers.dart' show accountRepositoryProvider, currentBookIdProvider;
import '../currency/exchange_rate_service.dart';

final accountBalanceCalculatorProvider = Provider<AccountBalanceCalculator>((ref) {
  return const AccountBalanceCalculator();
});

final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  return ExchangeRateService(ref.watch(databaseProvider));
});

/// 账户 + 余额 + 净资产视图模型（隐藏归档账户；仅当前账本，Spec §4.1；
/// 净资产按各账户币种汇率折算到主币种，Spec §4.5）
final accountsViewModelProvider = FutureProvider<AccountsViewModel>((ref) async {
  ref.watch(ledgerVersionProvider); // 账本写操作后自动重建（审查 F-1）
  final repo = ref.watch(accountRepositoryProvider);
  final db = ref.watch(databaseProvider);
  final bookId = ref.watch(currentBookIdProvider);
  final calc = ref.watch(accountBalanceCalculatorProvider);
  final rateService = ref.watch(exchangeRateServiceProvider);
  final accounts = await repo.listAccounts(includeArchived: false);
  final transactions = await (db.select(db.transactions)
        ..where((t) => t.bookId.equals(bookId)))
      .get();
  final balances = calc.balancesByAccount(
    accounts: accounts,
    transactions: transactions,
  );
  // 预取非主币种汇率，构建同步折算闭包（汇率失败降级 1:1）
  final rates = <String, int>{};
  for (final a in accounts) {
    if (a.currency == 'CNY') continue;
    rates[a.currency] = await rateService.rateScaled(a.currency);
  }
  final netWorth = calc.netWorth(
    types: {for (final a in accounts) a.id: a.accountType},
    balances: balances,
    currencies: {for (final a in accounts) a.id: a.currency},
    converter: (currency, amount) => Money.convert(
      amountMinor: amount,
      rateScaled: rates[currency] ?? kRateScale,
    ),
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
