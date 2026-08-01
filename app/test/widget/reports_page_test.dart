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
import 'package:bookkeep_app/features/reports/reports_page.dart';

import '../helpers/sqlite.dart';

void main() {
  ensureSqliteLoaded();

  Widget harness(AppDatabase db) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: ReportsPage()),
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
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final foodId = await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: '餐饮',
          icon: 'restaurant',
          color: 0xFF111111,
          kind: CategoryKind.expense,
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
    final now = DateTime.now();
    final inMonth = DateTime(now.year, now.month, 1);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: accountId,
          categoryId: Value(foodId),
          type: TransactionType.expense,
          amountMinor: -3000,
          currency: 'CNY',
          occurredAt: inMonth,
          updatedAt: now,
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
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
}
