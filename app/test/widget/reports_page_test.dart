import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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

    // 需求：取消「收支趋势」折线图
    expect(find.text('收支趋势'), findsNothing);
    expect(find.byType(LineChart), findsNothing);

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

  // ── BK-DOC-26 需求6：日历并入报表 ──

  testWidgets('calendar view: toggle shows month grid, tapping a day opens detail',
      (tester) async {
    await initializeDateFormatting('zh_CN');
    // 日历/图表按手机竖屏尺寸验证，避免默认 800×600 下日历纵向空间不足
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final now = DateTime.now();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: accountId,
          type: TransactionType.expense,
          amountMinor: -2550,
          currency: 'CNY',
          occurredAt: DateTime(now.year, now.month, now.day, 8, 30),
          updatedAt: now,
        ));

    // TableCalendar zh_CN 头部需要本地化代理（与 calendar_page_test 同）
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
      ],
      child: const MaterialApp(
        locale: Locale('zh', 'CN'),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: ReportsPage()),
      ),
    ));
    await pumpUntilFound(tester, find.text('分类占比'));

    // 图表 → 日历：月历出现，图表区收起
    await tester.tap(find.text('日历'));
    await pumpUntilFound(tester, find.text('周一'));
    expect(find.text('周一'), findsOneWidget);
    expect(find.text('分类占比'), findsNothing);

    // 点击「今天」日格（唯一加粗白字日号）→ 当天账单明细
    final today = DateTime.now().day;
    final todayCell = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data == '$today' &&
          w.style?.fontWeight == FontWeight.bold &&
          w.style?.color == Colors.white,
    );
    await tester.tap(todayCell);
    await pumpUntilFound(tester, find.textContaining('净额'));
    expect(find.textContaining('净额'), findsOneWidget);

    // 关闭当日明细弹层（modal bottom sheet），否则会遮住报表页按钮
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 切回图表视图正常
    await tester.tap(find.text('图表'));
    await pumpUntilFound(tester, find.text('分类占比'));
    expect(find.text('分类占比'), findsOneWidget);
  });
}
