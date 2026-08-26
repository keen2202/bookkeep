import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/categories_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/reports_repository.dart';

import '../../../helpers/fixtures.dart';

String two(int v) => v.toString().padLeft(2, '0');

void main() {
  late AppDatabase db;
  late ReportsRepository repo;
  late int accountId;
  late int foodId;
  late int transportId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReportsRepository(db, bookId: testBookId);
    accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime(2026, 8, 1),
        ));
    foodId = await db.into(db.categories).insert(CategoriesCompanion.insert(
          bookId: testBookId,
          name: '餐饮',
          icon: 'restaurant',
          color: 0xFF111111,
          kind: CategoryKind.expense,
          updatedAt: DateTime(2026, 8, 1),
        ));
    transportId = await db.into(db.categories).insert(CategoriesCompanion.insert(
          bookId: testBookId,
          name: '交通',
          icon: 'bus',
          color: 0xFF222222,
          kind: CategoryKind.expense,
          updatedAt: DateTime(2026, 8, 1),
        ));
  });

  tearDown(() async {
    await db.close();
  });

  // 记账时存的是本地时间（DateTime.now()），种子一律用本地 DateTime，
  // 与 dailyTotals/periodBuckets 的 'localtime' 口径在任意时区自洽
  Future<void> insertTx({
    required int categoryId,
    required int amountMinor,
    required DateTime occurredAt,
    TransactionType type = TransactionType.expense,
    bool deleted = false,
  }) {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: accountId,
          categoryId: Value(categoryId),
          type: type,
          amountMinor: amountMinor,
          currency: 'CNY',
          occurredAt: occurredAt,
          updatedAt: DateTime(2026, 8, 1),
          deletedAt: deleted ? Value(DateTime(2026, 8, 2)) : const Value.absent(),
        ));
  }

  test('daily totals aggregate by day, excluding deleted and transfers', () async {
    await insertTx(categoryId: foodId, amountMinor: -3000, occurredAt: DateTime(2026, 8, 1, 10));
    await insertTx(categoryId: foodId, amountMinor: -2000, occurredAt: DateTime(2026, 8, 1, 20));
    await insertTx(categoryId: transportId, amountMinor: -1000, occurredAt: DateTime(2026, 8, 2));
    await insertTx(categoryId: foodId, amountMinor: 5000, occurredAt: DateTime(2026, 8, 1, 12), type: TransactionType.income);
    await insertTx(categoryId: foodId, amountMinor: -9000, occurredAt: DateTime(2026, 8, 1, 13), deleted: true);
    await insertTx(categoryId: foodId, amountMinor: -7000, occurredAt: DateTime(2026, 9, 2));

    final totals = await repo.dailyTotals(
        start: DateTime(2026, 8, 1), end: DateTime(2026, 9, 1));

    expect(totals, hasLength(2));
    final day1 = totals.firstWhere((t) => t.date == '2026-08-01');
    expect(day1.expenseMinor, 5000);
    expect(day1.incomeMinor, 5000);
    expect(totals.firstWhere((t) => t.date == '2026-08-02').expenseMinor, 1000);
  });

  test('daily totals attribute by device-local calendar day', () async {
    // 任一时区下：日标签必须等于该时刻在设备本地日历中的日期
    // （东八区 20:00 UTC 本地已属次日——此前按 UTC 日分组会错记前一天）
    final instant = DateTime.utc(2026, 8, 1, 20);
    final localDay = instant.toLocal();
    final key = '${localDay.year}-${two(localDay.month)}-${two(localDay.day)}';
    await insertTx(categoryId: foodId, amountMinor: -3000, occurredAt: instant);

    final totals = await repo.dailyTotals(
        start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 3));

    expect(totals.single.date, key);
    expect(totals.single.expenseMinor, 3000);
  });

  test('category breakdown sums expenses per category in range', () async {
    await insertTx(categoryId: foodId, amountMinor: -3000, occurredAt: DateTime(2026, 8, 1));
    await insertTx(categoryId: foodId, amountMinor: -2000, occurredAt: DateTime(2026, 8, 5));
    await insertTx(categoryId: transportId, amountMinor: -1500, occurredAt: DateTime(2026, 8, 3));
    await insertTx(categoryId: foodId, amountMinor: -9000, occurredAt: DateTime(2026, 9, 2));

    final slices = await repo.categoryBreakdown(
        start: DateTime(2026, 8, 1), end: DateTime(2026, 9, 1));

    expect(slices, hasLength(2));
    final food = slices.firstWhere((s) => s.categoryId == foodId);
    expect(food.amountMinor, 5000);
    expect(food.categoryName, '餐饮');
    final transport = slices.firstWhere((s) => s.categoryId == transportId);
    expect(transport.amountMinor, 1500);
  });

  test('period buckets group by week and month granularity', () async {
    await insertTx(categoryId: foodId, amountMinor: -1000, occurredAt: DateTime(2026, 8, 3));
    await insertTx(categoryId: foodId, amountMinor: -2000, occurredAt: DateTime(2026, 8, 10));
    await insertTx(categoryId: foodId, amountMinor: -4000, occurredAt: DateTime(2026, 8, 17));
    await insertTx(categoryId: foodId, amountMinor: 500, occurredAt: DateTime(2026, 8, 11), type: TransactionType.income);

    final weeks = await repo.periodBuckets(
        start: DateTime(2026, 8, 1), end: DateTime(2026, 9, 1), granularity: BucketGranularity.week);

    expect(weeks, hasLength(3));
    expect(weeks.map((w) => w.expenseMinor).toList(), [1000, 2000, 4000]);
    expect(weeks[1].incomeMinor, 500);
    expect(weeks.first.label, '08-03 周');
  });

  test('comparison buckets slice recent-year windows with expense/income', () async {
    await insertTx(categoryId: foodId, amountMinor: -1000, occurredAt: DateTime(2026, 1, 5));
    await insertTx(categoryId: foodId, amountMinor: 6000, occurredAt: DateTime(2026, 2, 5), type: TransactionType.income);
    await insertTx(categoryId: foodId, amountMinor: -3000, occurredAt: DateTime(2024, 12, 31));
    await insertTx(categoryId: foodId, amountMinor: -2000, occurredAt: DateTime(2024, 6, 15));
    await insertTx(categoryId: foodId, amountMinor: -4000, occurredAt: DateTime(2025, 3, 1));
    await insertTx(categoryId: foodId, amountMinor: -9999, occurredAt: DateTime(2020, 8, 1)); // 窗口外

    final windows = comparisonWindows(ReportRange.year, DateTime(2026, 8, 9));
    final buckets = await repo.comparisonBuckets(windows: windows);

    final byLabel = {for (final b in buckets) b.label: b};
    expect(buckets, hasLength(5));
    expect(byLabel['2026']!.expenseMinor, 1000);
    expect(byLabel['2026']!.incomeMinor, 6000);
    expect(byLabel['2025']!.expenseMinor, 4000);
    expect(byLabel['2024']!.expenseMinor, 5000);
    expect(byLabel['2023']!.expenseMinor, 0);
    expect(byLabel['2022']!.expenseMinor, 0);
  });

  test('comparison buckets slice consecutive month windows', () async {
    await insertTx(categoryId: foodId, amountMinor: -2000, occurredAt: DateTime(2026, 8, 3));
    await insertTx(categoryId: foodId, amountMinor: -3000, occurredAt: DateTime(2026, 7, 31));
    await insertTx(categoryId: foodId, amountMinor: 1500, occurredAt: DateTime(2026, 5, 10), type: TransactionType.income);
    await insertTx(categoryId: foodId, amountMinor: -4000, occurredAt: DateTime(2026, 2, 20)); // 窗口外

    final windows = comparisonWindows(ReportRange.month, DateTime(2026, 8, 9));
    final buckets = await repo.comparisonBuckets(windows: windows);

    final byLabel = {for (final b in buckets) b.label: b};
    expect(windows.map((w) => w.label).toList(),
        ['2026-04', '2026-05', '2026-06', '2026-07', '2026-08']);
    expect(byLabel['2026-08']!.expenseMinor, 2000);
    expect(byLabel['2026-07']!.expenseMinor, 3000);
    expect(byLabel['2026-05']!.incomeMinor, 1500);
    // 窗口外的 2 月不在最近 5 个月中
    expect(byLabel.containsKey('2026-02'), isFalse);
  });

  test('report totals equal transaction totals for any range', () async {
    final rng = Random(7);
    var expected = 0;
    for (var i = 0; i < 100; i++) {
      final amount = -(rng.nextInt(10000) + 1);
      expected += amount;
      await insertTx(categoryId: foodId, amountMinor: amount, occurredAt: DateTime(2026, 8, 1).add(Duration(minutes: i)));
    }

    final totals = await repo.dailyTotals(
        start: DateTime(2026, 8, 1), end: DateTime(2026, 9, 1));
    final sum = totals.fold<int>(0, (acc, t) => acc + t.expenseMinor);

    expect(sum, -expected);
  });

  test('10k transactions render in under 500ms (first screen budget)', () async {
    final rng = Random(42);
    await db.batch((b) {
      for (var i = 0; i < 10000; i++) {
        b.insert(db.transactions, TransactionsCompanion.insert(
              bookId: testBookId,
              accountId: accountId,
              categoryId: Value(i.isEven ? foodId : transportId),
              type: TransactionType.expense,
              amountMinor: -(rng.nextInt(10000) + 1),
              currency: 'CNY',
              occurredAt: DateTime(2026, 1, 1).add(Duration(minutes: i * 50)),
              updatedAt: DateTime(2026, 8, 1),
            ));
      }
    });

    final sw = Stopwatch()..start();
    final totals = await repo.dailyTotals(
        start: DateTime(2026, 1, 1), end: DateTime(2026, 12, 31));
    final slices = await repo.categoryBreakdown(
        start: DateTime(2026, 1, 1), end: DateTime(2026, 12, 31));
    sw.stop();

    expect(totals.length, inInclusiveRange(340, 365));
    expect(slices, hasLength(2));
    expect(sw.elapsedMilliseconds, lessThan(500));
  });

  group('report periods（纯函数）', () {
    test('window covers current day/week/month/year', () {
      final now = DateTime(2026, 8, 9); // 周日
      expect(ReportRange.day.window(now),
          (start: DateTime(2026, 8, 9), end: DateTime(2026, 8, 10)));
      expect(ReportRange.week.window(now),
          (start: DateTime(2026, 8, 3), end: DateTime(2026, 8, 10)));
      expect(ReportRange.month.window(now),
          (start: DateTime(2026, 8, 1), end: DateTime(2026, 9, 1)));
      expect(ReportRange.year.window(now),
          (start: DateTime(2026, 1, 1), end: DateTime(2027, 1, 1)));
    });

    test('comparison windows: year range spans last 5 years (incl. current)', () {
      final windows = comparisonWindows(ReportRange.year, DateTime(2026, 8, 9));
      expect(windows, hasLength(5));
      expect(windows.map((w) => w.label).toList(),
          ['2022', '2023', '2024', '2025', '2026']);
      expect(windows.last.start, DateTime(2026));
      expect(windows.last.end, DateTime(2027));
    });

    test('comparison windows: month range spans last 5 months', () {
      final windows = comparisonWindows(ReportRange.month, DateTime(2026, 8, 9));
      expect(windows.map((w) => w.label).toList(),
          ['2026-04', '2026-05', '2026-06', '2026-07', '2026-08']);
      expect(windows.last.start, DateTime(2026, 8));
      expect(windows.last.end, DateTime(2026, 9));
      // 跨年：1 月锚点 → 去年 9 月起
      final crossYear = comparisonWindows(ReportRange.month, DateTime(2026, 1, 9));
      expect(crossYear.first.label, '2025-09');
      expect(crossYear.last.label, '2026-01');
    });

    test('comparison windows: day range spans last 7 days', () {
      final windows = comparisonWindows(ReportRange.day, DateTime(2026, 8, 9));
      expect(windows, hasLength(7));
      expect(windows.first,
          (label: '08-03', start: DateTime(2026, 8, 3), end: DateTime(2026, 8, 4)));
      expect(windows.last,
          (label: '08-09', start: DateTime(2026, 8, 9), end: DateTime(2026, 8, 10)));
    });

    test('comparison windows: week range spans last 5 weeks (Mon-based)', () {
      final windows = comparisonWindows(ReportRange.week, DateTime(2026, 8, 9));
      // 2026-08-09 为周日，本周一为 08-03
      expect(windows.map((w) => w.label).toList(),
          ['07-06 周', '07-13 周', '07-20 周', '07-27 周', '08-03 周']);
      for (final w in windows) {
        expect(w.start.weekday, DateTime.monday);
        expect(w.end.difference(w.start), const Duration(days: 7));
      }
    });

    test('ISO week helpers: 53rd week exists only in long years', () {
      expect(isoWeekNumber(DateTime(2026, 8, 9)), 32);
      expect(mondayOfIsoWeek(2026, 32), DateTime(2026, 8, 3));
      expect(mondayOfIsoWeek(2021, 53), isNull); // 2021 只有 52 周
      expect(mondayOfIsoWeek(2020, 53), DateTime(2020, 12, 28)); // 2020 有 53 周
    });

    test('custom window is inclusive on both ends', () {
      final w = customWindow(DateTime(2026, 8, 15, 13), DateTime(2026, 8, 20, 22));
      expect(w, (start: DateTime(2026, 8, 15), end: DateTime(2026, 8, 21)));
    });
  });
}
