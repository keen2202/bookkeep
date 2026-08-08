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

    final weeks = await repo.periodBuckets(
        start: DateTime(2026, 8, 1), end: DateTime(2026, 9, 1), granularity: BucketGranularity.week);

    expect(weeks, hasLength(3));
    expect(weeks.map((w) => w.amountMinor).toList(), [1000, 2000, 4000]);
    expect(weeks.first.label, '08-03 周');
  });

  test('comparison buckets slice labeled windows (cross-year)', () async {
    await insertTx(categoryId: foodId, amountMinor: -1000, occurredAt: DateTime(2026, 1, 5));
    await insertTx(categoryId: foodId, amountMinor: -3000, occurredAt: DateTime(2024, 12, 31));
    await insertTx(categoryId: foodId, amountMinor: -2000, occurredAt: DateTime(2024, 6, 15));
    await insertTx(categoryId: foodId, amountMinor: -4000, occurredAt: DateTime(2025, 3, 1));
    await insertTx(categoryId: foodId, amountMinor: -9999, occurredAt: DateTime(2020, 8, 1)); // 窗口外

    final windows = comparisonWindows(ReportRange.year, DateTime(2026, 8, 9));
    final buckets = await repo.comparisonBuckets(windows: windows);

    final byLabel = {for (final b in buckets) b.label: b.amountMinor};
    expect(buckets, hasLength(6));
    expect(byLabel['2026'], 1000);
    expect(byLabel['2025'], 4000);
    expect(byLabel['2024'], 5000);
    expect(byLabel['2023'], 0);
    expect(byLabel['2022'], 0);
    expect(byLabel['2021'], 0);
  });

  test('comparison buckets slice month windows (same month across years)', () async {
    await insertTx(categoryId: foodId, amountMinor: -1000, occurredAt: DateTime(2024, 8, 15));
    await insertTx(categoryId: foodId, amountMinor: -2000, occurredAt: DateTime(2026, 8, 3));
    await insertTx(categoryId: foodId, amountMinor: -3000, occurredAt: DateTime(2026, 7, 31));

    final windows = comparisonWindows(ReportRange.month, DateTime(2026, 8, 9));
    final buckets = await repo.comparisonBuckets(windows: windows);

    final byLabel = {for (final b in buckets) b.label: b.amountMinor};
    expect(byLabel['2026-08'], 2000);
    expect(byLabel['2024-08'], 1000);
    expect(byLabel['2026-07'], isNull); // 窗口外
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

    test('comparison windows: year range spans current + 5 prior years', () {
      final windows = comparisonWindows(ReportRange.year, DateTime(2026, 8, 9));
      expect(windows, hasLength(6));
      expect(windows.first.label, '2021');
      expect(windows.last.label, '2026');
      expect(windows.last.start, DateTime(2026));
      expect(windows.last.end, DateTime(2027));
    });

    test('comparison windows: month range uses same month across years', () {
      final windows = comparisonWindows(ReportRange.month, DateTime(2026, 8, 9));
      expect(windows.map((w) => w.label).toList(),
          ['2021-08', '2022-08', '2023-08', '2024-08', '2025-08', '2026-08']);
      expect(windows.last.start, DateTime(2026, 8));
      expect(windows.last.end, DateTime(2026, 9));
    });

    test('comparison windows: day range uses same day across years', () {
      final windows = comparisonWindows(ReportRange.day, DateTime(2026, 8, 9));
      expect(windows.first,
          (label: '2021-08-09', start: DateTime(2021, 8, 9), end: DateTime(2021, 8, 10)));
      expect(windows.last,
          (label: '2026-08-09', start: DateTime(2026, 8, 9), end: DateTime(2026, 8, 10)));
    });

    test('comparison windows: week range uses ISO week across years', () {
      final windows = comparisonWindows(ReportRange.week, DateTime(2026, 8, 9));
      expect(windows.map((w) => w.label).toList(),
          ['2021-W32', '2022-W32', '2023-W32', '2024-W32', '2025-W32', '2026-W32']);
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
