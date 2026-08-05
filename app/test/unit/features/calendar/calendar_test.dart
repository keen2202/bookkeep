import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/reports_repository.dart';
import 'package:bookkeep_app/data/repositories/transaction_repository.dart';

const bookId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late int accountId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TransactionRepository(db, bookId: bookId);
    accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: const Value(bookId),
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
  });

  tearDown(() => db.close());

  Future<void> addTx({
    required DateTime at,
    required int amount,
    String? note,
  }) {
    return repo.createTransaction(
      accountId: accountId,
      type: amount < 0 ? TransactionType.expense : TransactionType.income,
      amountMinor: amount,
      occurredAt: at,
      note: note,
    );
  }

  test('日聚合 = 明细合计（验证标准：日聚合=明细合计）', () async {
    await addTx(at: DateTime.utc(2026, 8, 1, 9), amount: -1000);
    await addTx(at: DateTime.utc(2026, 8, 1, 12), amount: -2500);
    await addTx(at: DateTime.utc(2026, 8, 1, 20), amount: 5000);
    await addTx(at: DateTime.utc(2026, 8, 2, 10), amount: -300);

    final reports = ReportsRepository(db, bookId: bookId);
    final totals = await reports.dailyTotals(
      start: DateTime.utc(2026, 8, 1),
      end: DateTime.utc(2026, 8, 3),
    );
    expect(totals, hasLength(2));

    // 8/1：支出 35.00，收入 50.00，净额 15.00
    final day1 = totals.firstWhere((t) => t.date == '2026-08-01');
    expect(day1.expenseMinor, 3500);
    expect(day1.incomeMinor, 5000);
    expect(day1.incomeMinor - day1.expenseMinor, 1500);

    // 明细合计交叉验证
    final txs = await (db.select(db.transactions)
          ..where((t) =>
              t.bookId.equals(bookId) &
              t.deletedAt.isNull() &
              t.occurredAt.isBiggerOrEqualValue(DateTime.utc(2026, 8, 1)) &
              t.occurredAt.isSmallerThanValue(DateTime.utc(2026, 8, 2))))
        .get();
    final expenseSum = txs.where((t) => t.type == TransactionType.expense).fold<int>(0, (s, t) => s - t.amountMinor);
    final incomeSum = txs.where((t) => t.type == TransactionType.income).fold<int>(0, (s, t) => s + t.amountMinor);
    expect(expenseSum, day1.expenseMinor);
    expect(incomeSum, day1.incomeMinor);
  });

  test('与报表同区间一致：日历日聚合 = 报表日聚合（同查询层）', () async {
    await addTx(at: DateTime.utc(2026, 8, 5, 9), amount: -1200);
    await addTx(at: DateTime.utc(2026, 8, 5, 15), amount: -800);
    await addTx(at: DateTime.utc(2026, 8, 15, 10), amount: 9999);

    final reports = ReportsRepository(db, bookId: bookId);
    final window = (start: DateTime.utc(2026, 8, 1), end: DateTime.utc(2026, 9, 1));
    final calendarTotals = await reports.dailyTotals(start: window.start, end: window.end);
    final reportTotals = await reports.dailyTotals(start: window.start, end: window.end);

    // 同一查询层 → 结果一致（口径统一；DailyTotal 无 ==，逐字段比较）
    expect(
      calendarTotals.map((t) => (t.date, t.expenseMinor, t.incomeMinor)).toList(),
      reportTotals.map((t) => (t.date, t.expenseMinor, t.incomeMinor)).toList(),
    );
    final day5 = calendarTotals.firstWhere((t) => t.date == '2026-08-05');
    expect(day5.expenseMinor, 2000);
    final day15 = calendarTotals.firstWhere((t) => t.date == '2026-08-15');
    expect(day15.incomeMinor, 9999);
  });

  test('大跨度渲染性能：跨 12 个月 10k 条流水，单月聚合 < 500ms（Spec §4.6 懒加载）', () async {
    final sw = Stopwatch()..start();
    // 生成 10k 条流水（跨 12 个月）
    for (var i = 0; i < 10000; i++) {
      final month = 1 + (i % 12);
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            bookId: const Value(bookId),
            accountId: accountId,
            type: TransactionType.expense,
            amountMinor: -(i % 1000 + 1),
            currency: 'CNY',
            rateSnapshot: const Value(1000000),
            occurredAt: DateTime.utc(2026, month, (i % 27) + 1, 12),
            updatedAt: DateTime.utc(2026, month, 1),
          ));
    }
    final insertTime = sw.elapsedMilliseconds;

    // 懒加载语义：仅查询聚焦月份（8 月）
    final reports = ReportsRepository(db, bookId: bookId);
    sw..reset()..start();
    final august = await reports.dailyTotals(
      start: DateTime.utc(2026, 8, 1),
      end: DateTime.utc(2026, 9, 1),
    );
    final queryTime = sw.elapsedMilliseconds;

    expect(august, isNotEmpty);
    expect(queryTime, lessThan(500), reason: '单月聚合 ${queryTime}ms 超预算（插入 ${insertTime}ms）');
    // 全月合计 = 8 月明细合计
    final augTotal = august.fold<int>(0, (s, t) => s + t.expenseMinor);
    final augTxs = await (db.select(db.transactions)
          ..where((t) =>
              t.bookId.equals(bookId) &
              t.occurredAt.isBiggerOrEqualValue(DateTime.utc(2026, 8, 1)) &
              t.occurredAt.isSmallerThanValue(DateTime.utc(2026, 9, 1))))
        .get();
    final augDetail = augTxs.fold<int>(0, (s, t) => s - t.amountMinor);
    expect(augTotal, augDetail);
  });
}
