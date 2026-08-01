import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/budget_repository.dart';
import 'package:bookkeep_app/data/repositories/category_repository.dart';
import 'package:bookkeep_app/features/budgets/budgets_page.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';

import '../helpers/sqlite.dart';
import 'categories_page_test.dart' show testSeed;

void main() {
  ensureSqliteLoaded();

  Widget harness(AppDatabase db) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        categorySeedProvider.overrideWith((ref) async => testSeed),
      ],
      child: const MaterialApp(home: BudgetsPage()),
    );
  }

  testWidgets('creates a total budget and shows spent progress', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final categoryRepo = CategoryRepository(db);
    await categoryRepo.installSeeds(testSeed);
    final budgetRepo = BudgetRepository(db);
    await budgetRepo.createBudget(categoryId: null, period: '2026-08-01', amountMinor: 100000);

    await tester.pumpWidget(harness(db));
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('总预算').evaluate().isNotEmpty) break;
    }

    expect(find.text('总预算'), findsOneWidget);
    expect(find.textContaining('¥0.00 / ¥1000.00'), findsOneWidget);

    // 记账保存路径会 invalidate 预算 provider（Spec §3.4 记账后重算）
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: accountId,
          type: TransactionType.expense,
          amountMinor: -30000,
          currency: 'CNY',
          occurredAt: DateTime.utc(2026, 8, 10),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
    final container = ProviderScope.containerOf(tester.element(find.byType(BudgetsPage)));
    container.invalidate(budgetsViewModelProvider);

    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.textContaining('¥300.00 / ¥1000.00').evaluate().isNotEmpty) break;
    }
    expect(find.textContaining('¥300.00 / ¥1000.00'), findsOneWidget);
    expect(find.textContaining('剩余 ¥700.00'), findsOneWidget);
  });

  testWidgets('empty state prompts to create a budget', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('还没有预算，点击右下角 + 新建').evaluate().isNotEmpty) break;
    }

    expect(find.text('还没有预算，点击右下角 + 新建'), findsOneWidget);
  });
}
