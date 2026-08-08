import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/repositories/budget_repository.dart';
import 'package:bookkeep_app/data/repositories/category_repository.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/budgets/budget_manage_sheet.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';

import '../helpers/fixtures.dart';
import 'categories_page_test.dart' show testSeed;

/// 预算管理弹层（预算 tab 移除后的管理入口）
void main() {
  Widget harness(AppDatabase db) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        categorySeedProvider.overrideWith((ref) async => testSeed),
      ],
      child: const MaterialApp(home: Scaffold(body: BudgetManageSheet())),
    );
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $finder');
  }

  testWidgets('empty state prompts to create a budget', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('还没有预算，点击 + 新建'));
    expect(find.text('还没有预算，点击 + 新建'), findsOneWidget);
  });

  testWidgets('renders total and category budgets with progress', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catRepo = CategoryRepository(db, bookId: testBookId);
    await catRepo.installSeeds(testSeed);
    final repo = BudgetRepository(db, bookId: testBookId);
    await repo.createBudget(categoryId: null, period: '2026-08-01', amountMinor: 100000);
    final cat = (await catRepo.listCategories()).first;
    await repo.createBudget(categoryId: cat.id, period: '2026-08-01', amountMinor: 50000);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('总预算'));
    expect(find.text('总预算'), findsOneWidget);
    await pumpUntilFound(tester, find.text(cat.name));
    expect(find.text(cat.name), findsOneWidget);
    expect(find.text('¥0.00 / ¥1000.00'), findsOneWidget);
    expect(find.text('¥0.00 / ¥500.00'), findsOneWidget);
  });

  testWidgets('new budget button opens edit sheet', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.byTooltip('新建预算'));
    await tester.tap(find.byTooltip('新建预算'));
    await tester.pumpAndSettle();

    expect(find.text('新建预算'), findsWidgets);
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('tapping a budget card opens edit sheet', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await BudgetRepository(db, bookId: testBookId)
        .createBudget(categoryId: null, period: '2026-08-01', amountMinor: 100000);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('总预算'));
    await tester.tap(find.text('总预算'));
    await tester.pumpAndSettle();

    expect(find.text('编辑预算'), findsOneWidget);
    expect(find.text('删除预算'), findsOneWidget);
  });
}
