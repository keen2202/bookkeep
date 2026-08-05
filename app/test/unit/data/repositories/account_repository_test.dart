import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/core/errors/repository_exceptions.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/sync_ops_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/account_repository.dart';
import 'package:bookkeep_app/domain/services/account_balance_calculator.dart';

void main() {
  late AppDatabase db;
  late AccountRepository repo;
  const calc = AccountBalanceCalculator();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = AccountRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('creates and reads back an account', () async {
    final id = await repo.createAccount(name: '工资卡', type: AccountType.savings);
    final account = await repo.getAccount(id);

    expect(account.name, '工资卡');
    expect(account.accountType, AccountType.savings);
    expect(account.archived, isFalse);
  });

  test('updates account name and type', () async {
    final id = await repo.createAccount(name: '旧名', type: AccountType.cash);
    await repo.updateAccount(id, name: '新名', type: AccountType.eWallet);

    final account = await repo.getAccount(id);
    expect(account.name, '新名');
    expect(account.accountType, AccountType.eWallet);
  });

  test('archives an account (soft delete)', () async {
    final id = await repo.createAccount(name: '待归档', type: AccountType.cash);
    await repo.archiveAccount(id);

    expect((await repo.getAccount(id)).archived, isTrue);
    expect(await repo.listAccounts(includeArchived: false), isEmpty);
    expect(await repo.listAccounts(includeArchived: true), hasLength(1));
  });

  test('refuses to delete an account that has transactions', () async {
    final id = await repo.createAccount(name: '有流水', type: AccountType.cash);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: id,
          type: TransactionType.expense,
          amountMinor: 100,
          currency: 'CNY',
          occurredAt: DateTime.utc(2026, 8, 1),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));

    expect(() => repo.deleteAccount(id), throwsA(isA<AccountInUseException>()));
    expect((await repo.getAccount(id)).archived, isFalse);
  });

  test('archives an account without transactions instead of hard deleting', () async {
    final id = await repo.createAccount(name: '无流水', type: AccountType.cash);
    await repo.deleteAccount(id);

    expect((await repo.getAccount(id)).archived, isTrue);
  });

  test('transfer creates a paired transaction and moves balances', () async {
    final fromId = await repo.createAccount(name: 'A', type: AccountType.cash);
    final toId = await repo.createAccount(name: 'B', type: AccountType.savings);

    final transferId = await repo.createTransfer(
      fromAccountId: fromId,
      toAccountId: toId,
      amountMinor: 2500,
      occurredAt: DateTime.utc(2026, 8, 1),
    );

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(2));
    expect(txs.every((t) => t.transferId == transferId), isTrue);

    final balances = calc.balancesByAccount(
      accounts: await db.select(db.accounts).get(),
      transactions: txs,
    );
    expect(balances[fromId], -2500);
    expect(balances[toId], 2500);
  });

  test('daily snapshot refresh writes one row per account per day', () async {
    final id = await repo.createAccount(name: 'A', type: AccountType.cash);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: id,
          type: TransactionType.expense,
          amountMinor: -800,
          currency: 'CNY',
          occurredAt: DateTime.utc(2026, 8, 1, 10),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));

    await repo.refreshSnapshots(DateTime.utc(2026, 8, 1));

    final snapshots = await db.select(db.accountSnapshots).get();
    expect(snapshots, hasLength(1));
    expect(snapshots.single.balanceMinor, -800);
  });

  test('10k random transactions keep balances consistent (error = 0)', () async {
    final rng = Random(42);
    final ids = <int>[];
    for (var i = 0; i < 5; i++) {
      ids.add(await repo.createAccount(name: 'acc$i', type: AccountType.cash));
    }

    var expectedSum = 0;
    final batch = db.batch((b) {
      for (var i = 0; i < 10000; i++) {
        final amount = rng.nextInt(10000) - 5000;
        expectedSum += amount;
        b.insert(db.transactions, TransactionsCompanion.insert(
              accountId: ids[rng.nextInt(ids.length)],
              type: amount >= 0 ? TransactionType.income : TransactionType.expense,
              amountMinor: amount,
              currency: 'CNY',
              occurredAt: DateTime.utc(2026, 8, 1).add(Duration(minutes: i)),
              updatedAt: DateTime.utc(2026, 8, 1),
            ));
      }
    });
    await batch;

    final balances = calc.balancesByAccount(
      accounts: await db.select(db.accounts).get(),
      transactions: await db.select(db.transactions).get(),
    );
    final sum = balances.values.fold<int>(0, (a, b) => a + b);

    expect(sum, expectedSum);
  });

  test('createAccount enqueues a create op with uuid snapshot payload', () async {
    final id = await repo.createAccount(name: '钱包', type: AccountType.cash, initialBalance: 500);

    final ops = await db.select(db.syncOps).get();
    expect(ops, hasLength(1));
    expect(ops.single.entity, 'account');
    expect(ops.single.entityId, id);
    expect(ops.single.op, SyncOpCode.c);

    final payload = jsonDecode(ops.single.payload) as Map<String, dynamic>;
    expect(payload['name'], '钱包');
    expect(payload['type'], 'cash');
    expect(payload['initial_balance'], 500);
    expect(payload['archived'], false);
  });

  test('updateAccount enqueues an update op with the full snapshot', () async {
    final id = await repo.createAccount(name: '旧名', type: AccountType.cash);
    await repo.updateAccount(id, name: '新名', type: AccountType.savings);

    final ops = await db.select(db.syncOps).get();
    expect(ops, hasLength(2));
    expect(ops[1].op, SyncOpCode.u);
    final payload = jsonDecode(ops[1].payload) as Map<String, dynamic>;
    expect(payload['name'], '新名');
    expect(payload['type'], 'savings');
  });

  test('archiveAccount enqueues an update op with archived=true', () async {
    final id = await repo.createAccount(name: '待归档', type: AccountType.cash);
    await repo.archiveAccount(id);

    final ops = await db.select(db.syncOps).get();
    expect(ops.last.op, SyncOpCode.u);
    final payload = jsonDecode(ops.last.payload) as Map<String, dynamic>;
    expect(payload['archived'], true);
  });

  test('createTransfer enqueues paired transfer ops', () async {
    final toId = await repo.createAccount(name: '储蓄', type: AccountType.savings);
    await repo.createTransfer(
      fromAccountId: 1,
      toAccountId: toId,
      amountMinor: 5000,
      occurredAt: DateTime.utc(2026, 8, 1),
    );

    final ops = await db.select(db.syncOps).get();
    expect(ops.where((o) => o.entity == 'transaction'), hasLength(2));
    expect(ops.every((o) => o.op == SyncOpCode.c), isTrue);
  });
}
