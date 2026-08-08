import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/categories_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/reports/reports_page.dart';

import '../helpers/fixtures.dart';

void main() {
  Widget harness(AppDatabase db) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
      ],
      // 与真实 App 一致：ReportsPage 置于 Scaffold 内（ActionChip 需 Material 祖先）
      child: const MaterialApp(home: Scaffold(body: ReportsPage())),
    );
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $finder');
  }

  testWidgets('renders pie, bar and line charts with seeded data', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final foodId = await db.into(db.categories).insert(CategoriesCompanion.insert(
          bookId: testBookId,
          name: '餐饮',
          icon: 'restaurant',
          color: 0xFF111111,
          kind: CategoryKind.expense,
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
    final now = DateTime.now();
    final inMonth = DateTime(now.year, now.month, 1);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: accountId,
          categoryId: Value(foodId),
          type: TransactionType.expense,
          amountMinor: -3000,
          currency: 'CNY',
          occurredAt: inMonth,
          updatedAt: now,
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: accountId,
          categoryId: Value(foodId),
          type: TransactionType.income,
          amountMinor: 5000,
          currency: 'CNY',
          occurredAt: inMonth.add(const Duration(hours: 1)),
          updatedAt: now,
        ));

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('分类占比'));

    expect(find.text('分类占比'), findsOneWidget);
    expect(find.text('周期对比'), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);

    await tester.scrollUntilVisible(find.text('收支趋势'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('收支趋势'), findsOneWidget);

    // 切换区间
    await tester.tap(find.text('年'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('分类占比'), findsOneWidget);
  });

  testWidgets('empty state shows no-data placeholders', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('暂无数据'));

    expect(find.text('暂无数据'), findsWidgets);
  });

  testWidgets('custom range picker opens and applies a date window', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('分类占比'));

    await tester.tap(find.byIcon(Icons.date_range_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);

    // 昨天永远可用（lastDate=今天禁用未来日）；连点两次得到单日范围。
    // 今天为 1 号时昨天在上月（滚动后出现两个月、文本歧义），跳过交互仅验证对话框
    final now = DateTime.now();
    if (now.day > 1) {
      final day = (now.day - 1).toString();
      await tester.tap(find.text(day));
      await tester.pumpAndSettle();
      await tester.tap(find.text(day));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      final yesterday = DateTime(now.year, now.month, now.day - 1);
      String fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final expected = '${fmt(yesterday)} ~ ${fmt(yesterday)}';
      expect(find.text(expected), findsOneWidget);
    }
  });

  testWidgets('year comparison renders current and prior-year buckets', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final foodId = await db.into(db.categories).insert(CategoriesCompanion.insert(
          bookId: testBookId,
          name: '餐饮',
          icon: 'restaurant',
          color: 0xFF111111,
          kind: CategoryKind.expense,
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
    final now = DateTime.now();
    final lastYear = now.year - 2;
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: accountId,
          categoryId: Value(foodId),
          type: TransactionType.expense,
          amountMinor: -3000,
          currency: 'CNY',
          occurredAt: DateTime(now.year, 1, 5),
          updatedAt: now,
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: accountId,
          categoryId: Value(foodId),
          type: TransactionType.expense,
          amountMinor: -8000,
          currency: 'CNY',
          occurredAt: DateTime(lastYear, 6, 15),
          updatedAt: now,
        ));

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('分类占比'));

    await tester.tap(find.text('年'));
    await pumpUntilFound(tester, find.text('${now.year}'));

    expect(find.text('${now.year}'), findsOneWidget);
    expect(find.text('$lastYear'), findsOneWidget);
  });
}
