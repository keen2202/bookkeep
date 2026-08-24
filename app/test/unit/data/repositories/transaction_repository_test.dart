import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/categories_table.dart';
import 'package:bookkeep_app/data/local/tables/sync_ops_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/transaction_repository.dart';

void main() {
  late AppDatabase db;
  const testBookId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  late TransactionRepository repo;
  late int accountId;
  late int categoryId;
  late String accountRemoteId;
  late String categoryRemoteId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TransactionRepository(db, bookId: testBookId);
    accountRemoteId = repo.opLogger.newUuid();
    accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          remoteId: Value(accountRemoteId),
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    categoryRemoteId = repo.opLogger.newUuid();
    categoryId = await db.into(db.categories).insert(CategoriesCompanion.insert(
          bookId: testBookId,
          remoteId: Value(categoryRemoteId),
          name: '餐饮',
          icon: 'restaurant',
          color: 0xFF111111,
          kind: CategoryKind.expense,
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
  });

  tearDown(() async {
    await db.close();
  });

  test('creates a transaction and enqueues a create op in sync_ops', () async {
    final txId = await repo.createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      type: TransactionType.expense,
      amountMinor: -1250,
      occurredAt: DateTime.utc(2026, 8, 1, 12),
    );

    final tx = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingle();
    expect(tx.amountMinor, -1250);

    final ops = await db.select(db.syncOps).get();
    expect(ops, hasLength(1));
    expect(ops.single.entity, 'transaction');
    expect(ops.single.entityId, txId);
    expect(ops.single.op, SyncOpCode.c);
    expect(ops.single.lamport, 1);
    expect(ops.single.pushed, isFalse);

    final payload = jsonDecode(ops.single.payload) as Map<String, dynamic>;
    expect(payload['amount_minor'], -1250);
    // 跨设备引用 = 实体行的 remote_id（uuid）
    expect(payload['account_id'], accountRemoteId);
    expect(payload['category_id'], categoryRemoteId);
    expect(ops.single.remoteId, isNotNull);
  });

  test('lamport clock is monotonic across writes', () async {
    await repo.createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      type: TransactionType.expense,
      amountMinor: -100,
      occurredAt: DateTime.utc(2026, 8, 1),
    );
    await repo.createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      type: TransactionType.expense,
      amountMinor: -200,
      occurredAt: DateTime.utc(2026, 8, 1),
    );

    final ops = await db.select(db.syncOps).get();
    expect(ops.map((o) => o.lamport).toList(), [1, 2]);
    expect(ops.every((o) => o.clientId.isNotEmpty), isTrue);
  });

  test('soft deletes a transaction and enqueues a delete op', () async {
    final txId = await repo.createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      type: TransactionType.expense,
      amountMinor: -100,
      occurredAt: DateTime.utc(2026, 8, 1),
    );

    await repo.deleteTransaction(txId);

    final tx = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingle();
    expect(tx.deletedAt, isNotNull);

    final ops = await db.select(db.syncOps).get();
    expect(ops.map((o) => o.op).toList(), [SyncOpCode.c, SyncOpCode.d]);
  });

  test('updates a transaction and enqueues an update op with full snapshot', () async {
    final txId = await repo.createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      type: TransactionType.expense,
      amountMinor: -1250,
      occurredAt: DateTime.utc(2026, 8, 1, 12),
    );

    await repo.updateTransaction(
      id: txId,
      accountId: accountId,
      categoryId: categoryId,
      type: TransactionType.expense,
      amountMinor: -2500,
      occurredAt: DateTime.utc(2026, 8, 2, 9, 30),
      note: '加餐',
    );

    final tx = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingle();
    expect(tx.amountMinor, -2500);
    expect(tx.note, '加餐');
    expect(tx.occurredAt.toUtc(), DateTime.utc(2026, 8, 2, 9, 30));
    expect(tx.deletedAt, isNull);

    final ops = await db.select(db.syncOps).get();
    expect(ops.map((o) => o.op).toList(), [SyncOpCode.c, SyncOpCode.u]);
    expect(ops.last.entityId, txId);
    expect(ops.last.lamport, 2);

    // u op 为完整快照：跨设备引用 = remote_id（与 create payload 同构）
    final payload = jsonDecode(ops.last.payload) as Map<String, dynamic>;
    expect(payload['amount_minor'], -2500);
    expect(payload['note'], '加餐');
    expect(payload['type'], 'expense');
    expect(payload['account_id'], accountRemoteId);
    expect(payload['category_id'], categoryRemoteId);
  });

  test('updateTransfer rewrites both sides and enqueues two update ops', () async {
    final toAccountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.savings,
          name: '储蓄',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final fromRowId = await repo.createTransfer(
      fromAccountId: accountId,
      toAccountId: toAccountId,
      amountMinor: 5000,
      occurredAt: DateTime.utc(2026, 8, 1),
    );
    // 任一侧 id 均可作为入口：取对侧（转入行）
    final rows0 = await db.select(db.transactions).get();
    final toRowId = rows0.singleWhere((r) => r.id != fromRowId).id;

    // 交换转出/转入并改金额/日期（经对侧行 id 调用）
    await repo.updateTransfer(
      anySideId: toRowId,
      fromAccountId: toAccountId,
      toAccountId: accountId,
      amountMinor: 7000,
      occurredAt: DateTime.utc(2026, 8, 3),
      note: '房租',
    );

    final rows = await db.select(db.transactions).get();
    final out = rows.singleWhere((r) => r.amountMinor < 0);
    final inn = rows.singleWhere((r) => r.amountMinor > 0);
    expect(out.accountId, toAccountId); // 方向已交换
    expect(inn.accountId, accountId);
    expect(out.amountMinor, -7000);
    expect(inn.amountMinor, 7000);
    expect(out.note, '房租');
    expect(inn.note, '房租');
    expect(out.occurredAt.toUtc(), DateTime.utc(2026, 8, 3));
    expect(inn.occurredAt.toUtc(), DateTime.utc(2026, 8, 3));

    final ops = await db.select(db.syncOps).get();
    expect(
        ops.map((o) => o.op).toList(), [SyncOpCode.c, SyncOpCode.c, SyncOpCode.u, SyncOpCode.u]);
  });

  test('deleteTransferPair soft-deletes both sides with two delete ops', () async {
    final toAccountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.savings,
          name: '储蓄',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final fromRowId = await repo.createTransfer(
      fromAccountId: accountId,
      toAccountId: toAccountId,
      amountMinor: 5000,
      occurredAt: DateTime.utc(2026, 8, 1),
    );
    final rows0 = await db.select(db.transactions).get();
    final toRowId = rows0.singleWhere((r) => r.id != fromRowId).id;

    // 经任一侧删除，双边同事务软删
    await repo.deleteTransferPair(toRowId);

    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(2));
    expect(rows.every((r) => r.deletedAt != null), isTrue);

    final ops = await db.select(db.syncOps).get();
    expect(
        ops.map((o) => o.op).toList(), [SyncOpCode.c, SyncOpCode.c, SyncOpCode.d, SyncOpCode.d]);
  });

  test('loadTransferPair returns negative side first; null for non-transfer', () async {
    final toAccountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.savings,
          name: '储蓄',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final fromRowId = await repo.createTransfer(
      fromAccountId: accountId,
      toAccountId: toAccountId,
      amountMinor: 5000,
      occurredAt: DateTime.utc(2026, 8, 1),
    );

    // 从转入行（对侧）解析同样返回双边
    final all = await db.select(db.transactions).get();
    final toRowId = all.singleWhere((r) => r.id != fromRowId).id;
    final pair = await repo.loadTransferPair(toRowId);
    expect(pair, isNotNull);
    expect(pair!.from.amountMinor, -5000);
    expect(pair.from.accountId, accountId);
    expect(pair.to?.accountId, toAccountId);

    final expenseId = await repo.createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      type: TransactionType.expense,
      amountMinor: -100,
      occurredAt: DateTime.utc(2026, 8, 1),
    );
    expect(await repo.loadTransferPair(expenseId), isNull);
  });

  test('remembers and returns last-used defaults per transaction type', () async {    await repo.rememberDefaults(
      type: TransactionType.expense,
      categoryId: categoryId,
      accountId: accountId,
    );

    final defaults = await repo.lastDefaults(TransactionType.expense);
    expect(defaults?.categoryId, categoryId);
    expect(defaults?.accountId, accountId);

    expect(await repo.lastDefaults(TransactionType.income), isNull);
  });

  test('creates a transfer with paired ops', () async {
    final toAccountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.savings,
          name: '储蓄',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));

    final transferId = await repo.createTransfer(
      fromAccountId: accountId,
      toAccountId: toAccountId,
      amountMinor: 5000,
      occurredAt: DateTime.utc(2026, 8, 1),
    );

    final txs = await db.select(db.transactions).get();
    expect(txs.where((t) => t.transferId == transferId), hasLength(2));

    final ops = await db.select(db.syncOps).get();
    expect(ops, hasLength(2));
    expect(ops.every((o) => o.entity == 'transaction' && o.op == SyncOpCode.c), isTrue);
  });

  test('save latency stays within the P95 200ms budget for 100 writes', () async {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      await repo.createTransaction(
        accountId: accountId,
        categoryId: categoryId,
        type: TransactionType.expense,
        amountMinor: -i,
        occurredAt: DateTime.utc(2026, 8, 1),
      );
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / 100;

    expect(perOp, lessThan(200000), reason: '平均保存耗时 ${perOp ~/ 1000}ms 超过预算');
  });
}
