import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/category_repository.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';
import 'package:bookkeep_app/features/quick_entry/quick_entry_sheet.dart';

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
      child: const MaterialApp(home: QuickEntrySheet()),
    );
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $finder');
  }

  testWidgets('golden path: type amount, pick account and category, save', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = CategoryRepository(db);
    await repo.installSeeds(testSeed);
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final lunch = await repo.listCategories();
    final lunchId = lunch.firstWhere((c) => c.name == '早餐').id;

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('早餐'));

    // 输入 25.5
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('.'));
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump();

    expect(find.text('-¥25.50'), findsOneWidget);

    // 选择账户（默认空 → 需选择）
    await tester.tap(find.text('账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('钱包（现金）').last);
    await tester.pumpAndSettle();

    // 选择分类
    await tester.tap(find.text('早餐'));
    await tester.pump();

    // 保存
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 400));

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.single.amountMinor, -2550);
    expect(txs.single.categoryId, lunchId);
    expect(txs.single.type, TransactionType.expense);
  });

  testWidgets('invalid amount shows an error and does not save', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = CategoryRepository(db);
    await repo.installSeeds(testSeed);
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('早餐'));
    await tester.tap(find.text('账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('钱包（现金）').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('早餐'));
    await tester.pump();

    // 金额为空直接保存 → 无效
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('金额无效，请重新输入'), findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);
  });
}
