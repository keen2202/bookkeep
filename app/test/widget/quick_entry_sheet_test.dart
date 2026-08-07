import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/category_repository.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';
import 'package:bookkeep_app/features/quick_entry/quick_entry_sheet.dart';

import '../helpers/fixtures.dart';
import 'categories_page_test.dart' show testSeed;

void main() {
  Widget harness(AppDatabase db) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
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

  /// 弹层内点「早餐」chip：选中即关闭弹层并回填（无确定按钮）
  Future<void> pickBreakfast(WidgetTester tester) async {
    await pumpUntilFound(tester, find.text('选择分类'));
    await tester.tap(find.text('选择分类'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(FilterChip, '早餐'),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 手动重新选择账户（覆盖自动回填）
  Future<void> pickAccount(WidgetTester tester) async {
    await pumpUntilFound(tester, find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.text('账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('钱包（现金）').last);
    await tester.pumpAndSettle();
  }

  Future<void> seedDb(AppDatabase db) async {
    final repo = CategoryRepository(db, bookId: testBookId);
    await repo.installSeeds(testSeed);
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
  }

  testWidgets('golden path: type amount, pick account and category, save', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedDb(db);
    final lunch = await CategoryRepository(db, bookId: testBookId).listCategories();
    final lunchId = lunch.firstWhere((c) => c.name == '早餐').id;

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.byType(DropdownButtonFormField<int>));

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

    // 账户自动回填（无需手动选择）
    await pumpUntilFound(tester, find.text('钱包（现金）'));
    expect(find.text('钱包（现金）'), findsOneWidget);

    // 选择分类：点字段弹出两层选择器 → 点 chip 即选中并关闭弹层
    await pickBreakfast(tester);
    expect(find.text('餐饮 / 早餐'), findsOneWidget);

    // 保存（键盘确定）
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
    await seedDb(db);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.byType(DropdownButtonFormField<int>));
    await pickAccount(tester);
    await pickBreakfast(tester);

    // 金额为空直接保存 → 无效
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('金额无效，请重新输入'), findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  testWidgets('category picker collapses and expands parent categories', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedDb(db);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.byType(DropdownButtonFormField<int>));

    // 打开分类选择器（默认全部展开）
    await pumpUntilFound(tester, find.text('选择分类'));
    await tester.tap(find.text('选择分类'));
    await tester.pumpAndSettle();
    Finder breakfastChip() => find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(FilterChip, '早餐'),
        );
    expect(breakfastChip(), findsOneWidget);

    // 点击父分类标题折叠 → 子分类 chip 隐藏
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(breakfastChip(), findsNothing);

    // 再次点击展开 → 子分类 chip 恢复
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(breakfastChip(), findsOneWidget);
  });
}
