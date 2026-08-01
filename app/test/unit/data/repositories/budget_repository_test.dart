import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/categories_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/local/tables/sync_ops_table.dart';
import 'package:bookkeep_app/data/repositories/budget_repository.dart';

import '../../../helpers/sqlite.dart';

void main() {
  ensureSqliteLoaded();
  late AppDatabase db;
  late BudgetRepository repo;
  late int accountId;
  late int foodId;
  late int otherId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = BudgetRepository(db);
    accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    foodId = await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: '餐饮',
          icon: 'restaurant',
          color: 0xFF111111,
          kind: CategoryKind.expense,
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
    otherId = await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: '交通',
          icon: 'bus',
          color: 0xFF222222,
          kind: CategoryKind.expense,
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTx({required int categoryId, required int amountMinor, required DateTime occurredAt, bool deleted = false}) {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: accountId,
          categoryId: Value(categoryId),
          type: TransactionType.expense,
          amountMinor: amountMinor,
          currency: 'CNY',
          occurredAt: occurredAt,
          updatedAt: DateTime.utc(2026, 8, 1),
          deletedAt: deleted ? Value(DateTime.utc(2026, 8, 2)) : const Value.absent(),
        ));
  }

  test('creates, lists, updates and deletes budgets', () async {
    final id = await repo.createBudget(
      categoryId: null,
      period: '2026-08-01',
      amountMinor: 500000,
    );
    await repo.createBudget(categoryId: foodId, period: '2026-08-01', amountMinor: 200000);

    var budgets = await repo.listBudgets();
    expect(budgets, hasLength(2));

    await repo.updateBudget(id, amountMinor: 600000, threshold: 90);
    budgets = await repo.listBudgets();
    expect(budgets.firstWhere((b) => b.id == id).amountMinor, 600000);
    expect(budgets.firstWhere((b) => b.id == id).threshold, 90);

    await repo.deleteBudget(id);
    expect(await repo.listBudgets(), hasLength(1));
  });

  test('spent for period sums only expense transactions inside the window', () async {
    await insertTx(categoryId: foodId, amountMinor: -3000, occurredAt: DateTime.utc(2026, 8, 5));
    await insertTx(categoryId: foodId, amountMinor: -2000, occurredAt: DateTime.utc(2026, 8, 20));
    await insertTx(categoryId: otherId, amountMinor: -1000, occurredAt: DateTime.utc(2026, 8, 10));
    // 窗口外
    await insertTx(categoryId: foodId, amountMinor: -9000, occurredAt: DateTime.utc(2026, 9, 1));
    // 收入不计
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: accountId,
          categoryId: Value(foodId),
          type: TransactionType.income,
          amountMinor: 50000,
          currency: 'CNY',
          occurredAt: DateTime.utc(2026, 8, 10),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));

    final total = await repo.spentForPeriod(
        categoryId: null, start: DateTime.utc(2026, 8, 1), end: DateTime.utc(2026, 9, 1));
    final food = await repo.spentForPeriod(
        categoryId: foodId, start: DateTime.utc(2026, 8, 1), end: DateTime.utc(2026, 9, 1));

    expect(total, 6000);
    expect(food, 5000);
  });

  test('deleted transactions are excluded from spent', () async {
    await insertTx(categoryId: foodId, amountMinor: -3000, occurredAt: DateTime.utc(2026, 8, 5));
    await insertTx(categoryId: foodId, amountMinor: -2000, occurredAt: DateTime.utc(2026, 8, 6), deleted: true);

    final food = await repo.spentForPeriod(
        categoryId: foodId, start: DateTime.utc(2026, 8, 1), end: DateTime.utc(2026, 9, 1));
    expect(food, 3000);
  });

  test('threshold alerts fire exactly once per budget period and level', () async {
    final id = await repo.createBudget(categoryId: foodId, period: '2026-08-01', amountMinor: 100000);

    expect(await repo.shouldNotify(id, period: '2026-08', level: 'warning'), isTrue);
    await repo.markAlertNotified(id, period: '2026-08', level: 'warning');
    expect(await repo.shouldNotify(id, period: '2026-08', level: 'warning'), isFalse);

    // 新周期可再次提醒
    expect(await repo.shouldNotify(id, period: '2026-09', level: 'warning'), isTrue);
    // 不同级别独立
    expect(await repo.shouldNotify(id, period: '2026-08', level: 'exceeded'), isTrue);
  });

  test('budget create/update/delete enqueue ops', () async {
    final id = await repo.createBudget(categoryId: foodId, period: '2026-08-01', amountMinor: 300000);
    await repo.updateBudget(id, amountMinor: 500000, threshold: 90);
    await repo.deleteBudget(id);

    final ops = await db.select(db.syncOps).get();
    expect(ops.map((o) => o.op).toList(), [SyncOpCode.c, SyncOpCode.u, SyncOpCode.d]);
    expect(ops.first.entityId, id);

    final createPayload = jsonDecode(ops[0].payload) as Map<String, dynamic>;
    expect(createPayload['amount_minor'], 300000);
    expect(createPayload['threshold'], 80);
    final updatePayload = jsonDecode(ops[1].payload) as Map<String, dynamic>;
    expect(updatePayload['amount_minor'], 500000);
  });
}
