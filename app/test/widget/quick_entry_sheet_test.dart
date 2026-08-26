import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
  Widget harness(AppDatabase db, {DateTime? initialDate}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        categorySeedProvider.overrideWith((ref) async => testSeed),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN')],
        locale: const Locale('zh', 'CN'),
        home: QuickEntrySheet(initialDate: initialDate),
      ),
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
    await tester.ensureVisible(find.text('选择分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择分类'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('早餐'),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 手动重新选择账户（覆盖自动回填）
  Future<void> pickAccount(WidgetTester tester) async {
    await pumpUntilFound(tester, find.byType(DropdownButtonFormField<int>));
    await tester.ensureVisible(find.text('账户'));
    await tester.pumpAndSettle();
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

  testWidgets('快速记账页不再显示右上角退出按钮', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedDb(db);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.byType(DropdownButtonFormField<int>));

    // 需求：取消记账页右上角「退出」按钮，返回走系统返回手势/导航返回键
    expect(find.text('退出'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('新增记账提供备注栏，填写后随保存入库', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedDb(db);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.byType(DropdownButtonFormField<int>));

    // 需求：记账页（新增模式）展示备注栏
    expect(find.text('备注'), findsOneWidget);

    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('8'));
    await tester.pump();
    await pickAccount(tester);
    await pickBreakfast(tester);
    await tester.enterText(find.byType(TextField), '和同事拼单');
    await tester.pump();

    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 400));

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.single.amountMinor, -2800);
    expect(txs.single.note, '和同事拼单');
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
    await tester.ensureVisible(find.text('选择分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择分类'));
    await tester.pumpAndSettle();
    // FGDS：分类 chip 改为自定义玻璃 chip（无 FilterChip），按文本命中
    Finder breakfastChip() => find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('早餐'),
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

  testWidgets('default date field shows today', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedDb(db);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.byType(DropdownButtonFormField<int>));

    final now = DateTime.now();
    final expected = '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('initialDate prefills and saves with full precision', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedDb(db);
    final target = DateTime(2026, 8, 3, 9, 30, 15);

    await tester.pumpWidget(harness(db, initialDate: target));
    await pumpUntilFound(tester, find.byType(DropdownButtonFormField<int>));
    expect(find.text('2026-08-03'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);

    for (final key in ['2', '5', '.', '5']) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
    await pickBreakfast(tester);
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 400));

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.single.occurredAt, target);
  });

  testWidgets('changing date via picker preserves time', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedDb(db);
    final target = DateTime(2026, 8, 3, 9, 30, 15);

    await tester.pumpWidget(harness(db, initialDate: target));
    await pumpUntilFound(tester, find.byType(DropdownButtonFormField<int>));

    await tester.tap(find.text('2026-08-03'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pumpAndSettle();

    expect(find.text('2026-08-15'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);

    for (final key in ['2', '5', '.', '5']) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
    await pickBreakfast(tester);
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 400));

    final txs = await db.select(db.transactions).get();
    expect(txs.single.occurredAt, DateTime(2026, 8, 15, 9, 30, 15));
  });

  testWidgets('changing time via input picker preserves date', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedDb(db);
    final target = DateTime(2026, 8, 3, 9, 30, 15);

    await tester.pumpWidget(harness(db, initialDate: target));
    await pumpUntilFound(tester, find.byType(DropdownButtonFormField<int>));

    await tester.tap(find.text('09:30'));
    await tester.pumpAndSettle();
    // 输入模式时间选择器：时/分两个 TextField（限定对话框范围，
    // 记账页备注栏本身也是一个 TextField）
    final fields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '9');
    await tester.enterText(fields.at(1), '05');
    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pumpAndSettle();

    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('2026-08-03'), findsOneWidget);

    for (final key in ['2', '5', '.', '5']) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
    await pickBreakfast(tester);
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 400));

    final txs = await db.select(db.transactions).get();
    expect(txs.single.occurredAt, DateTime(2026, 8, 3, 9, 5, 15));
  });
}
