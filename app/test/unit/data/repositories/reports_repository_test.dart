import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/categories_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/reports_repository.dart';

void main() {
  late AppDatabase db;
  late ReportsRepository repo;
  late int accountId;
  late int foodId;
  late int transportId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReportsRepository(db);
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
    transportId = await db.into(db.categories).insert(CategoriesCompanion.insert(
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

  Future<void> insertTx({
    required int categoryId,
    required int amountMinor,
    required DateTime occurredAt,
    TransactionType type = TransactionType.expense,
    bool deleted = false,
  }) {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: accountId,
          categoryId: Value(categoryId),
          type: type,
          amountMinor: amountMinor,
          currency: 'CNY',
          occurredAt: occurredAt,
          updatedAt: DateTime.utc(2026, 8, 1),
          deletedAt: deleted ? Value(DateTime.utc(2026, 8, 2)) : const Value.absent(),
        ));
  }

  test('daily totals aggregate by day, excluding deleted and transfers', () async {
    await insertTx(categoryId: foodId, amountMinor: -3000, occurredAt: DateTime.utc(2026, 8, 1, 10));
    await insertTx(categoryId: foodId, amountMinor: -2000, occurredAt: DateTime.utc(2026, 8, 1, 20));
    await insertTx(categoryId: transportId, amountMinor: -1000, occurredAt: DateTime.utc(2026, 8, 2));
    await insertTx(categoryId: foodId, amountMinor: 5000, occurredAt: DateTime.utc(2026, 8, 1, 12), type: TransactionType.income);
    await insertTx(categoryId: foodId, amountMinor: -9000, occurredAt: DateTime.utc(2026, 8, 1, 13), deleted: true);
    await insertTx(categoryId: foodId, amountMinor: -7000, occurredAt: DateTime.utc(2026, 9, 1));

    final totals = await repo.dailyTotals(
        start: DateTime.utc(2026, 8, 1), end: DateTime.utc(2026, 9, 1));

    expect(totals, hasLength(2));
    final day1 = totals.firstWhere((t) => t.date == '2026-08-01');
    expect(day1.expenseMinor, 5000);
    expect(day1.incomeMinor, 5000);
    expect(totals.firstWhere((t) => t.date == '2026-08-02').expenseMinor, 1000);
  });

  test('category breakdown sums expenses per category in range', () async {
    await insertTx(categoryId: foodId, amountMinor: -3000, occurredAt: DateTime.utc(2026, 8, 1));
    await insertTx(categoryId: foodId, amountMinor: -2000, occurredAt: DateTime.utc(2026, 8, 5));
    await insertTx(categoryId: transportId, amountMinor: -1500, occurredAt: DateTime.utc(2026, 8, 3));
    await insertTx(categoryId: foodId, amountMinor: -9000, occurredAt: DateTime.utc(2026, 9, 1));

    final slices = await repo.categoryBreakdown(
        start: DateTime.utc(2026, 8, 1), end: DateTime.utc(2026, 9, 1));

    expect(slices, hasLength(2));
    final food = slices.firstWhere((s) => s.categoryId == foodId);
    expect(food.amountMinor, 5000);
    expect(food.categoryName, '餐饮');
    final transport = slices.firstWhere((s) => s.categoryId == transportId);
    expect(transport.amountMinor, 1500);
  });

  test('period buckets group by week and month granularity', () async {
    await insertTx(categoryId: foodId, amountMinor: -1000, occurredAt: DateTime.utc(2026, 8, 3));
    await insertTx(categoryId: foodId, amountMinor: -2000, occurredAt: DateTime.utc(2026, 8, 10));
    await insertTx(categoryId: foodId, amountMinor: -4000, occurredAt: DateTime.utc(2026, 8, 17));

    final weeks = await repo.periodBuckets(
        start: DateTime.utc(2026, 8, 1), end: DateTime.utc(2026, 9, 1), granularity: BucketGranularity.week);

    expect(weeks, hasLength(3));
    expect(weeks.map((w) => w.amountMinor).toList(), [1000, 2000, 4000]);
    expect(weeks.first.label, '08-03 周');
  });

  test('report totals equal transaction totals for any range', () async {
    final rng = Random(7);
    var expected = 0;
    for (var i = 0; i < 100; i++) {
      final amount = -(rng.nextInt(10000) + 1);
      expected += amount;
      await insertTx(categoryId: foodId, amountMinor: amount, occurredAt: DateTime.utc(2026, 8, 1).add(Duration(minutes: i)));
    }

    final totals = await repo.dailyTotals(
        start: DateTime.utc(2026, 8, 1), end: DateTime.utc(2026, 9, 1));
    final sum = totals.fold<int>(0, (acc, t) => acc + t.expenseMinor);

    expect(sum, -expected);
  });

  test('10k transactions render in under 500ms (first screen budget)', () async {
    final rng = Random(42);
    await db.batch((b) {
      for (var i = 0; i < 10000; i++) {
        b.insert(db.transactions, TransactionsCompanion.insert(
              accountId: accountId,
              categoryId: Value(i.isEven ? foodId : transportId),
              type: TransactionType.expense,
              amountMinor: -(rng.nextInt(10000) + 1),
              currency: 'CNY',
              occurredAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i * 50)),
              updatedAt: DateTime.utc(2026, 8, 1),
            ));
      }
    });

    final sw = Stopwatch()..start();
    final totals = await repo.dailyTotals(
        start: DateTime.utc(2026, 1, 1), end: DateTime.utc(2026, 12, 31));
    final slices = await repo.categoryBreakdown(
        start: DateTime.utc(2026, 1, 1), end: DateTime.utc(2026, 12, 31));
    sw.stop();

    expect(totals.length, inInclusiveRange(340, 365));
    expect(slices, hasLength(2));
    expect(sw.elapsedMilliseconds, lessThan(500));
  });
}
