import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/categories_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/account_repository.dart';
import 'package:bookkeep_app/data/repositories/transaction_repository.dart';
import 'package:bookkeep_app/domain/usecases/create_transaction.dart';
import 'package:bookkeep_app/features/quick_entry/quick_entry_controller.dart';

void main() {
  late AppDatabase db;
  const testBookId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  late QuickEntryController controller;
  late int accountId;
  late int categoryId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    categoryId = await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: '餐饮',
          icon: 'restaurant',
          color: 0xFF111111,
          kind: CategoryKind.expense,
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
    final repo = TransactionRepository(db, bookId: testBookId);
    controller = QuickEntryController(
      createTransaction: CreateTransaction(repo),
      transactionRepository: repo,
      accountRepository: AccountRepository(db),
    );
    controller.categoryId = categoryId;
    controller.accountId = accountId;
  });

  tearDown(() async {
    await db.close();
  });

  group('key input', () {
    test('digit keys append to the input', () {
      controller.pressKey('1');
      controller.pressKey('2');
      controller.pressKey('.');
      controller.pressKey('5');

      expect(controller.input, '12.5');
    });

    test('a second dot is rejected within the same term', () {
      controller.pressKey('1');
      controller.pressKey('.');
      controller.pressKey('2');
      controller.pressKey('.');
      controller.pressKey('3');

      expect(controller.input, '1.23');
    });

    test('operators append only after a complete term', () {
      controller.pressKey('1');
      controller.pressKey('+');
      controller.pressKey('2');

      expect(controller.input, '1+2');

      controller.pressKey('+');
      expect(controller.input, '1+2'); // 运算符不连续
    });

    test('backspace removes the last character and clear empties', () {
      controller.pressKey('1');
      controller.pressKey('2');
      controller.backspace();
      expect(controller.input, '1');

      controller.clear();
      expect(controller.input, '');
    });
  });

  group('save', () {
    test('saves an expense and records the amount as negative', () async {
      controller.pressKey('2');
      controller.pressKey('5');
      controller.pressKey('.');

      final ok = await controller.save();

      expect(ok, isTrue);
      expect(controller.error, QuickEntryError.none);
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
      expect(txs.single.amountMinor, -2500);
      expect(txs.single.type, TransactionType.expense);
    });

    test('saves an income as positive', () async {
      controller.setType(TransactionType.income);
      controller.pressKey('1');
      controller.pressKey('0');

      final ok = await controller.save();

      expect(ok, isTrue);
      final txs = await db.select(db.transactions).get();
      expect(txs.single.amountMinor, 1000);
    });

    test('审查 U-4：保存 busy 锁——连点不重复入账', () async {
      controller.pressKey('2');
      controller.pressKey('5');

      // 首击进入 saving 后，第二击立即返回 false 且不产生第二条流水
      final first = controller.save();
      final second = await controller.save();
      final firstResult = await first;

      expect(firstResult, isTrue);
      expect(second, isFalse);
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
    });

    test('invalid amount fails and flags the error', () async {
      controller.pressKey('0');

      final ok = await controller.save();

      expect(ok, isFalse);
      expect(controller.error, QuickEntryError.invalidAmount);
      expect(await db.select(db.transactions).get(), isEmpty);
    });

    test('saving without an account or category is rejected', () async {
      controller.accountId = null;
      controller.pressKey('5');

      expect(await controller.save(), isFalse);
      expect(controller.error, QuickEntryError.missingSelection);
    });

    test('transfer mode moves money between two accounts', () async {
      final toId = await db.into(db.accounts).insert(AccountsCompanion.insert(
            accountType: AccountType.savings,
            name: '储蓄',
            currency: 'CNY',
            createdAt: DateTime.utc(2026, 8, 1),
          ));
      controller.setType(TransactionType.transfer);
      controller.toAccountId = toId;
      controller.pressKey('3');
      controller.pressKey('0');

      final ok = await controller.save();

      expect(ok, isTrue);
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(2));
      expect(txs.map((t) => t.amountMinor).toSet(), {-3000, 3000});
    });
  });
}
