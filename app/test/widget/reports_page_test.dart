import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
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
import 'package:bookkeep_app/features/categories/categories_page.dart'
    show categorySeedProvider;
import 'package:bookkeep_app/features/reports/reports_page.dart';

import '../helpers/fixtures.dart';
import 'categories_page_test.dart' show testSeed;

void main() {
  Widget harness(AppDatabase db) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
      ],
      // 与真实 App 一致：ReportsPage 置于 Scaffold 内（GlassPanel/AppSheet 需 Material 祖先）
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

  Future<void> pumpUntilGone(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isEmpty) return;
    }
    fail('Timed out waiting for $finder to disappear');
  }

  /// 最小账本数据：一笔当年支出（分类占比 / 周期对比均有非空桶）
  Future<void> seedOneExpense(AppDatabase db, DateTime at) async {
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: accountId,
          type: TransactionType.expense,
          amountMinor: -3000,
          currency: 'CNY',
          occurredAt: at,
          updatedAt: DateTime.now(),
        ));
  }

  /// 挂载图表视图并等待取数完成：loading 态的不确定 CircularProgressIndicator
  /// 会持续排帧，pumpAndSettle 的收敛时机取决于取数何时落地，故显式等待更稳
  Future<void> mountCharts(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('分类占比'));
    await pumpUntilGone(tester, find.byType(CircularProgressIndicator));
  }

  /// 关闭滚轮弹层（取消 / 确定通用）并等待新窗口的图表重新取数完成
  Future<void> dismissSheet(WidgetTester tester) async {
    await tester.pump();
    await pumpUntilGone(tester, find.text('选择统计期'));
    await pumpUntilGone(tester, find.byType(CircularProgressIndicator));
  }

  /// 手机竖屏视口（与 calendar_page_test 同口径）：年粒度下报表有三个区块，
  /// 默认 800×600 会把「收支趋势」推到 ListView 构建窗口边缘，断言不稳定
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// 报表图表区的 ListView（独立挂载 ReportsPage，页内仅此一个滚动区）
  Finder reportsScrollable() => find.byType(Scrollable).last;

  testWidgets('renders pie and period-comparison bar charts with seeded data',
      (tester) async {
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
    // 年粒度下「周期对比」为柱状，「收支趋势」（需求9）为折线；默认视口里第三
    // 区块是否进入 ListView 构建窗口不确定，12 桶/折线断言交给手机竖屏专项用例
    expect(find.byType(BarChart), findsWidgets);

    // BK-DOC-28 需求7（AC7-1）：「图表 / 日历」分段控件选中段不渲染 ✔
    expect(find.byType(SegmentedButton<ReportsView>), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);

    // BK-DOC-28 需求3：默认统计期 = 今年（年粒度），chip 与「分类占比」副标题同源
    expect(find.text('${now.year}年'), findsNWidgets(2));
    expect(find.text('最近5年'), findsOneWidget);
  });

  testWidgets('empty state shows no-data placeholders', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntilFound(tester, find.text('暂无数据'));

    expect(find.text('暂无数据'), findsWidgets);
  });

  // ── BK-DOC-28 需求3：时间筛选 = 年/月/日三列滚轮弹层（取代区间 SegmentedButton
  //    与自定义范围选择器；Spec §3 冲突 C4）──

  testWidgets('time chip opens the wheel sheet and cancel discards the draft',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    await seedOneExpense(db, DateTime(now.year, now.month, 1));

    await mountCharts(tester, db);
    // AC3-1：默认统计期 = 今年（chip 与「分类占比」副标题同源，故为 2 处）
    expect(find.text('${now.year}年'), findsNWidgets(2));
    expect(find.text('最近5年'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.schedule_outlined));
    await tester.pumpAndSettle();
    expect(find.text('选择统计期'), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsNWidgets(3));
    // AC3-2：月/日列首项均为「全部」（月为「全部」时日列禁用）
    expect(find.text('全部'), findsNWidgets(2));

    // AC3-5：滚动月列后点「取消」→ 草稿随弹层丢弃，统计期不变
    await tester.drag(find.byType(CupertinoPicker).at(1), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await dismissSheet(tester);
    expect(find.text('选择统计期'), findsNothing);
    expect(find.text('${now.year}年'), findsNWidgets(2));
    expect(find.text('最近5年'), findsOneWidget);
  });

  testWidgets('confirming the wheel narrows granularity: year → month → day',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    await seedOneExpense(db, DateTime(now.year, 2, 3, 9));

    await mountCharts(tester, db);

    // 年 → 月：选 2 月后窗口收敛为单月，周期对比口径变「最近5个月」（AC3-3）
    await tester.tap(find.byIcon(Icons.schedule_outlined));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CupertinoPicker).at(1), const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await dismissSheet(tester);
    expect(find.text('${now.year}年2月'), findsNWidgets(2));
    expect(find.text('最近5个月'), findsOneWidget);
    // AC9-1：月粒度不渲染「收支趋势」区块
    expect(find.text('收支趋势'), findsNothing);
    expect(find.byType(BarChart), findsOneWidget);

    // 月 → 日：日列解禁后选 3 日，口径变「最近7天」（AC3-2 / AC3-3）
    await tester.tap(find.byIcon(Icons.schedule_outlined));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CupertinoPicker).at(2), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await dismissSheet(tester);
    expect(find.text('${now.year}年2月3日'), findsNWidgets(2));
    expect(find.text('最近7天'), findsOneWidget);
    // AC9-1：日粒度同样不渲染「收支趋势」区块
    expect(find.text('收支趋势'), findsNothing);
    expect(find.byType(BarChart), findsOneWidget);
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

    await mountCharts(tester, db);

    // 年粒度为默认统计期：周期对比锚定今年，轴标签覆盖最近 5 年（含 lastYear）
    await pumpUntilFound(tester, find.text('${now.year}'));

    expect(find.text('${now.year}'), findsOneWidget);
    expect(find.text('$lastYear'), findsOneWidget);
  });

  // ── BK-DOC-28 需求9：年维度新增「收支趋势」区块 ──

  testWidgets('yearly trend section renders at year granularity and follows the selected year',
      (tester) async {
    usePhoneViewport(tester);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    await seedOneExpense(db, DateTime(now.year, 3, 5, 10));

    await mountCharts(tester, db);

    // AC9-1：年粒度出现第三个区块（位于 ListView 下方，滚到可见再断言）
    await tester.scrollUntilVisible(find.text('收支趋势'), 120,
        scrollable: reportsScrollable());
    expect(find.text('收支趋势'), findsOneWidget);
    expect(find.text('${now.year}年 · 按月汇总'), findsOneWidget);
    // AC9-2：「周期对比」为柱状，「收支趋势」为折线图
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);

    // AC9-4：滚轮换年后区块随之更新（副标题带新年份）
    await tester.tap(find.byIcon(Icons.schedule_outlined));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CupertinoPicker).at(0), const Offset(0, -40));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await dismissSheet(tester);
    final nextYear = now.year + 1;
    expect(find.text('$nextYear年'), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text('$nextYear年 · 按月汇总'), 120,
        scrollable: reportsScrollable());
    expect(find.text('$nextYear年 · 按月汇总'), findsOneWidget);
  });

  // ── BK-DOC-26 需求6：日历并入报表；BK-DOC-28 需求2：点日内联展开明细面板 ──

  testWidgets('calendar view: toggle shows month grid, tapping a day expands detail',
      (tester) async {
    await initializeDateFormatting('zh_CN');
    // 日历/图表按手机竖屏尺寸验证，避免默认 800×600 下日历纵向空间不足
    usePhoneViewport(tester);
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

    // TableCalendar zh_CN 头部需要本地化代理（与 calendar_page_test 同）；
    // 明细面板解析分类名走 categoriesViewModelProvider，覆盖 seed 免真实资产 I/O
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        categorySeedProvider.overrideWith((ref) async => testSeed),
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
    // 需求7（AC7-1）：切到「日历」后选中段仍不带 ✔（选中态仅由颜色承载）
    expect(find.byIcon(Icons.check), findsNothing);

    // 点击「今天」日格（唯一加粗白字日号）→ 当天明细在日历下方内联展开
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
    // BK-DOC-28 需求2：明细为页内面板而非模态弹层，无需关闭即可继续操作
    expect(find.byType(BottomSheet), findsNothing);

    // 切回图表视图正常
    await tester.tap(find.text('图表'));
    await pumpUntilFound(tester, find.text('分类占比'));
    expect(find.text('分类占比'), findsOneWidget);
  });
}
