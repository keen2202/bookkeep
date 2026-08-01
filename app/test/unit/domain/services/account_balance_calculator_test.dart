import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/domain/services/account_balance_calculator.dart';

import '../../../helpers/fixtures.dart';

void main() {
  const calc = AccountBalanceCalculator();

  group('balancesByAccount', () {
    test('empty transactions leaves balances at initial values', () {
      final balances = calc.balancesByAccount(accounts: [
        account(1, 'A', 1000),
        account(2, 'B', 500),
      ], transactions: const []);

      expect(balances, {1: 1000, 2: 500});
    });

    test('expense and income transactions adjust balances', () {
      final balances = calc.balancesByAccount(accounts: [account(1, 'A', 1000)], transactions: [
        txn(accountId: 1, amountMinor: -300),
        txn(accountId: 1, amountMinor: 1200),
      ]);

      expect(balances, {1: 1900});
    });

    test('a transfer pair nets to zero across the two accounts', () {
      final balances = calc.balancesByAccount(accounts: [
        account(1, 'A', 1000),
        account(2, 'B', 1000),
      ], transactions: [
        txn(accountId: 1, amountMinor: -400, transferId: 99),
        txn(accountId: 2, amountMinor: 400, transferId: 99),
      ]);

      expect(balances, {1: 600, 2: 1400});
    });

    test('deleted transactions are excluded', () {
      final balances = calc.balancesByAccount(accounts: [account(1, 'A', 1000)], transactions: [
        txn(accountId: 1, amountMinor: -300, deletedAt: DateTime.utc(2026, 8, 2)),
      ]);

      expect(balances, {1: 1000});
    });
  });

  group('netWorth', () {
    test('assets minus liabilities', () {
      final worth = calc.netWorth(types: {
        1: AccountType.savings,
        2: AccountType.credit,
      }, balances: {
        1: 10000,
        2: 3000,
      });

      expect(worth, 7000);
    });

    test('all-asset accounts sum directly', () {
      final worth = calc.netWorth(types: {
        1: AccountType.cash,
        2: AccountType.eWallet,
      }, balances: {
        1: 100,
        2: 200,
      });

      expect(worth, 300);
    });
  });
}
