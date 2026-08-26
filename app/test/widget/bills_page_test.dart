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
import 'package:bookkeep_app/data/repositories/transaction_repository.dart';
import 'package:bookkeep_app/features/auth_lock/lock_controller.dart';
import 'package:bookkeep_app/features/bills/bills_page.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';

import '../helpers/fixtures.dart';
import 'categories_page_test.dart' show testSeed;

/// 账单详情页（默认主页）：按天分组 + 组头收支合计 + 分类行/转账行/脱敏；
/// 点按行打开详情弹层，支持修改（复用极速记账编辑页）与删除
void main() {
  Widget harness(AppDatabase db, {bool masked = false, bool viewer = false}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        categorySeedProvider.overrideWith((ref) async => testSeed),
        if (masked) amountMaskProvider.overrideWith((ref) => true),
        if (viewer) currentRoleProvider.overrideWith((ref) => 'viewer'),
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
    // W3 迁移至 AppEmpty：title 与 message 拆分为独立 Text（Spec §6）
    await pumpUntilFound(tester, find.text('还没有账单'));
    expect(find.text('还没有账单'), findsOneWidget);
    expect(find.text('点击右下角 + 记一笔'), findsOneWidget);
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

    // 组头：当天支出 ¥25.50 · 收入 ¥100.00（转账不计入）；
    // 日汇总行与明细区分：黑色标题样式 + 「支出：/收入：」与标题同字号
    expect(find.text('支出：'), findsOneWidget);
    expect(find.text('¥25.50'), findsOneWidget);
    expect(find.text('收入：'), findsOneWidget);
    expect(find.text('¥100.00'), findsOneWidget);
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

    expect(find.text('支出：'), findsOneWidget);
    expect(find.text('¥***'), findsWidgets);
    expect(find.textContaining('25.50'), findsNothing);
  });

  Future<int> seedExpense(AppDatabase db, ({int accountId, int breakfastId, int lunchId}) ids,
      {int amountMinor = -2550, String? note}) {
    final now = DateTime.now();
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: ids.accountId,
          categoryId: Value(ids.breakfastId),
          type: TransactionType.expense,
          amountMinor: amountMinor,
          currency: 'CNY',
          note: Value(note),
          occurredAt: DateTime(now.year, now.month, now.day, 8, 30),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
  }

  testWidgets('tap bill opens detail sheet and delete removes it after confirm',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ids = await seedDb(db);
    await seedExpense(db, ids);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('餐饮 / 早餐'));

    // 点按账单行 → 详情弹层
    await tester.tap(find.text('餐饮 / 早餐'));
    await pumpUntilFound(tester, find.text('账单详情'));
    expect(find.text('修改'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    // 删除 → 危险确认（小屏下按钮区可滚动，先滚动到可见）
    await tester.ensureVisible(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await pumpUntilFound(tester, find.text('确认删除'));
    await tester.tap(find.text('确认删除'));
    await pumpUntilFound(tester, find.text('已删除'));

    // 软删落库 + 列表经刷新总线回到空态
    final txs = await db.select(db.transactions).get();
    expect(txs.single.deletedAt, isNotNull);
    await pumpUntilFound(tester, find.text('还没有账单'));
  });

  testWidgets('edit bill prefills editor and saves changes', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ids = await seedDb(db);
    await seedExpense(db, ids);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('餐饮 / 早餐'));

    await tester.tap(find.text('餐饮 / 早餐'));
    await pumpUntilFound(tester, find.text('账单详情'));
    await tester.ensureVisible(find.text('修改'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('修改'));
    await pumpUntilFound(tester, find.text('编辑账单'));
    await tester.pumpAndSettle(); // 页面入场动画结束后再点按键盘（下层路由此时已 offstage）

    // 预填：金额大数字 -¥25.50、备注输入字段
    expect(find.text('-¥25.50'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget); // 详情层信息行 + 编辑页输入字段
    expect(find.byType(TextField), findsOneWidget);

    // 收支行不可切转账类型：点「转账」段无响应（enabled=false，不出现双边账户字段）
    await tester.tap(find.text('转账'));
    await tester.pump();
    expect(find.text('转出账户'), findsNothing);
    expect(find.text('转入账户'), findsNothing);

    // 改金额：清空后输入 30；改备注
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
    }
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('0'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '打车后补记');
    await tester.pump();

    await tester.tap(find.text('确定'));
    await pumpUntilFound(tester, find.text('已保存'));

    final txs = await db.select(db.transactions).get();
    expect(txs.single.amountMinor, -3000);
    expect(txs.single.note, '打车后补记');
    expect(txs.single.type, TransactionType.expense);
    // 列表自动刷新为新金额与备注
    await pumpUntilFound(tester, find.text('-¥30.00'));
    await pumpUntilFound(tester, find.textContaining('打车后补记'));
  });

  testWidgets('deleting a transfer from detail sheet removes both paired rows',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ids = await seedDb(db);
    final toAccountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.savings,
          name: '储蓄',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final repo = TransactionRepository(db, bookId: testBookId);
    await repo.createTransfer(
      fromAccountId: ids.accountId,
      toAccountId: toAccountId,
      amountMinor: 3000,
      occurredAt: DateTime.now(),
    );

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('转账'));

    // 转账为双边流水，账单页两行同名；任取一行进入详情
    await tester.tap(find.text('转账').first);
    await pumpUntilFound(tester, find.text('账单详情'));
    // 双边账户行（FutureBuilder 解析配对流水后渲染）
    await pumpUntilFound(tester, find.text('转出账户'));
    await pumpUntilFound(tester, find.text('转入账户'));

    await tester.ensureVisible(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await pumpUntilFound(tester, find.text('确认删除'));
    await tester.tap(find.text('确认删除'));
    await pumpUntilFound(tester, find.text('已删除'));

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(2));
    expect(txs.every((t) => t.deletedAt != null), isTrue);
  });

  testWidgets('viewer role cannot open detail sheet (read-only)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ids = await seedDb(db);
    await seedExpense(db, ids);

    await tester.pumpWidget(harness(db, viewer: true));
    await pumpUntilFound(tester, find.text('餐饮 / 早餐'));

    await tester.tap(find.text('餐饮 / 早餐'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('账单详情'), findsNothing);
    expect(find.text('修改'), findsNothing);
  });
}
