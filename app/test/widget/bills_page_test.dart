import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/category_repository.dart';
import 'package:bookkeep_app/features/auth_lock/lock_controller.dart';
import 'package:bookkeep_app/features/bills/bills_page.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';

import '../helpers/fixtures.dart';
import 'categories_page_test.dart' show testSeed;

/// 账单详情页（默认主页）：按天分组 + 组头收支合计 + 分类行/转账行/脱敏
void main() {
  Widget harness(AppDatabase db, {bool masked = false}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        categorySeedProvider.overrideWith((ref) async => testSeed),
        if (masked) amountMaskProvider.overrideWith((ref) => true),
      ],
      child: const MaterialApp(home: Scaffold(body: BillsPage())),
    );
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $finder');
  }

  Future<({int accountId, int breakfastId, int lunchId})> seedDb(
      AppDatabase db) async {
    final catRepo = CategoryRepository(db, bookId: testBookId);
    await catRepo.installSeeds(testSeed);
    final cats = await catRepo.listCategories();
    final breakfastId = cats.firstWhere((c) => c.name == '早餐').id;
    final lunchId = cats.firstWhere((c) => c.name == '晚餐').id;
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    return (accountId: accountId, breakfastId: breakfastId, lunchId: lunchId);
  }

  testWidgets('empty state', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('还没有账单，点击 + 记一笔'));
    expect(find.text('还没有账单，点击 + 记一笔'), findsOneWidget);
  });

  testWidgets('groups bills by day with totals and category rows', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ids = await seedDb(db);
    final now = DateTime.now();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: ids.accountId,
          categoryId: Value(ids.breakfastId),
          type: TransactionType.expense,
          amountMinor: -2550,
          currency: 'CNY',
          occurredAt: DateTime(now.year, now.month, now.day, 8, 30),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: ids.accountId,
          categoryId: Value(ids.lunchId),
          type: TransactionType.income,
          amountMinor: 10000,
          currency: 'CNY',
          occurredAt: DateTime(now.year, now.month, now.day, 12, 0),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: ids.accountId,
          type: TransactionType.transfer,
          amountMinor: -3000,
          currency: 'CNY',
          occurredAt: DateTime(now.year, now.month, now.day, 18, 5),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('餐饮 / 早餐'));

    // 组头：当天支出 ¥25.50 · 收入 ¥100.00（转账不计入）
    expect(find.textContaining('支出 ¥25.50'), findsOneWidget);
    expect(find.textContaining('收入 ¥100.00'), findsOneWidget);
    // 分类行（父/子拼接）+ 时间
    expect(find.text('餐饮 / 早餐'), findsOneWidget);
    expect(find.text('餐饮 / 晚餐'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    // 转账行
    expect(find.text('转账'), findsOneWidget);
    expect(find.text('-¥30.00'), findsOneWidget);
  });

  testWidgets('masked mode hides amounts', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ids = await seedDb(db);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: ids.accountId,
          categoryId: Value(ids.breakfastId),
          type: TransactionType.expense,
          amountMinor: -2550,
          currency: 'CNY',
          occurredAt: DateTime(2026, 8, 3, 8, 30),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));

    await tester.pumpWidget(harness(db, masked: true));
    await pumpUntilFound(tester, find.text('餐饮 / 早餐'));

    expect(find.text('支出 ***'), findsOneWidget);
    expect(find.text('***'), findsWidgets);
    expect(find.textContaining('¥25.50'), findsNothing);
  });
}
