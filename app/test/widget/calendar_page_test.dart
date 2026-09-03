import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/categories_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/reports_repository.dart';
import 'package:bookkeep_app/features/auth_lock/lock_controller.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/calendar/calendar_page.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';

import '../helpers/fixtures.dart';
import 'categories_page_test.dart' show testSeed;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
  });

  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  Widget harness(AppDatabase db, {String role = 'owner', bool masked = false}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        currentRoleProvider.overrideWith((ref) => role),
        categorySeedProvider.overrideWith((ref) async => testSeed),
        if (masked) amountMaskProvider.overrideWith((ref) => true),
      ],
      child: const MaterialApp(
        locale: Locale('zh', 'CN'),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: CalendarPage()),
      ),
    );
  }

  AppDatabase memoryDb() {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  Future<int> seedAccount(AppDatabase db) =>
      db.into(db.accounts).insert(AccountsCompanion.insert(
            bookId: testBookId,
            accountType: AccountType.cash,
            name: '钱包',
            currency: 'CNY',
            createdAt: DateTime.utc(2026, 8, 1),
          ));

  /// 两级测试分类（返回子类 id）：验证明细行的「父类 / 子类」路径渲染
  Future<int> seedTwoLevelCategory(AppDatabase db) async {
    final parentId = await db.into(db.categories).insert(CategoriesCompanion.insert(
          bookId: testBookId,
          name: '测试父类',
          icon: 'restaurant',
          color: 0xFFFF7043,
          kind: CategoryKind.expense,
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
    return db.into(db.categories).insert(CategoriesCompanion.insert(
          bookId: testBookId,
          parentId: Value(parentId),
          name: '测试子类',
          icon: 'free_breakfast',
          color: 0xFFFF7043,
          kind: CategoryKind.expense,
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
  }

  Future<void> seedTxn(
    AppDatabase db, {
    required int accountId,
    required DateTime at,
    required int amountMinor,
    int? categoryId,
    TransactionType type = TransactionType.expense,
  }) =>
      db.into(db.transactions).insert(TransactionsCompanion.insert(
            bookId: testBookId,
            accountId: accountId,
            categoryId: Value(categoryId),
            type: type,
            amountMinor: amountMinor,
            currency: 'CNY',
            occurredAt: at,
            updatedAt: DateTime.now(),
          ));

  /// 月历 + 明细面板纵向空间敏感：统一按手机竖屏视口验证（Spec §2.2）
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// 轮询 pump 直到条件满足（真实 I/O 与假时钟下 pumpAndSettle 会与
  /// 面板加载态的 CircularProgressIndicator 竞态而超时）
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $finder');
  }

  /// 轮询 pump 直到元素消失（面板收起 / AnimatedSwitcher 旧内容退场）
  Future<void> pumpUntilGone(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isEmpty) return;
    }
    fail('Timed out waiting for $finder to disappear');
  }

  /// 挂载日历页并等待月面渲染完成
  Future<void> mountCalendar(
    WidgetTester tester,
    AppDatabase db, {
    String role = 'owner',
    bool masked = false,
  }) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(harness(db, role: role, masked: masked));
    await pumpUntil(tester, find.text('周一'));
  }

  /// 今日日号的唯一 Finder：仅「今天」以加粗白字渲染。
  /// （修复空白日期后，相邻月份的淡色日号可能与本月同号重复，
  ///  不能再按纯文本查找点击）
  Finder todayCellText(int day) => find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data == '$day' &&
            w.style?.fontWeight == FontWeight.bold &&
            w.style?.color == Colors.white,
      );

  /// 月历内指定日号：限定在 TableCalendar 子树内，避开年份按钮与金额文本。
  /// 相邻月淡色格只可能是上月末（≥23）或下月初（≤6），故 15/16 号唯一。
  Finder dayCellText(int day) => find.descendant(
        of: find.byType(TableCalendar<DailyTotal>),
        matching: find.text('$day'),
      );

  /// 与「今天」不同、且必定落在本月内的对照日
  int otherDay() => DateTime.now().day == 15 ? 16 : 15;

  Future<void> tapToday(WidgetTester tester) async {
    await tester.tap(todayCellText(DateTime.now().day));
    await tester.pump();
  }

  Future<void> tapDay(WidgetTester tester, int day) async {
    await tester.tap(dayCellText(day));
    await tester.pump();
  }

  /// 面板展开动画（GlassMotion.state 200ms）收尾，供几何断言使用
  Future<void> settlePanel(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 300));

  String dayHeader(DateTime day) =>
      '${day.month}月${day.day}日 ${weekdays[day.weekday - 1]}';

  testWidgets('calendar renders in Chinese with a prominent today cell', (tester) async {
    await mountCalendar(tester, memoryDb());

    // 星期表头为中文
    expect(find.text('周一'), findsOneWidget);
    expect(find.text('周日'), findsOneWidget);
    // 月份标题为中文格式（如 2026年8月）
    expect(find.textContaining('年'), findsWidgets);
    expect(find.textContaining('月'), findsWidgets);

    // 今天：固定直径圆形高亮内为加粗白字（比普通日期更醒目）
    final todayText = tester.widget<Text>(todayCellText(DateTime.now().day));
    expect(todayText.style?.fontWeight, FontWeight.bold);
    // W3 迁移后今日日期走 TextTheme（bodyMedium）加粗白字，不再裸字号；
    // 具体字号随主题字阶，此处不锁死具体值
    expect(todayText.style?.color, Colors.white);
  });

  testWidgets('adjacent-month days render dimmed numbers instead of blank cells',
      (tester) async {
    await mountCalendar(tester, memoryDb());

    // 空白日期修复：月面首尾的相邻月份日期仍显示日号（淡色），
    // 不再整格留白。按真实月历推算存在相邻日号的月份里，
    // 同一日号会出现两次（本月 + 相邻月）；旧实现相邻格为空白，
    // 日号只出现一次。
    final now = DateTime.now();
    final firstWeekday = DateTime(now.year, now.month, 1).weekday % 7; // 周日=0
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final outsideCount =
        firstWeekday + (7 - (firstWeekday + daysInMonth) % 7) % 7;
    if (outsideCount == 0) return; // 该月恰好铺满整周、无相邻格（理论少见）

    final counts = <String, int>{};
    tester
        .widgetList<Text>(find.descendant(
          of: find.byType(TableCalendar<DailyTotal>),
          matching: find.byWidgetPredicate(
            (w) => w is Text && (w.data ?? w.textSpan?.toPlainText()) != null,
          ),
        ))
        .forEach((t) {
      final s = t.data ?? t.textSpan?.toPlainText() ?? '';
      if (RegExp(r'^\d+$').hasMatch(s)) {
        counts[s] = (counts[s] ?? 0) + 1;
      }
    });
    expect(
      counts.values.any((c) => c >= 2),
      isTrue,
      reason: '存在 $outsideCount 个相邻月日格，应渲染淡色日号而非留白',
    );
  });

  // ── BK-DOC-28 需求1：移除日历页现金流趋势图 ──

  testWidgets('cashflow trend chart is removed and the panel starts collapsed',
      (tester) async {
    await mountCalendar(tester, memoryDb());

    // AC1-1 / AC1-3：30 天现金流折线图整体下线，槽位由明细面板接管
    expect(find.textContaining('现金流'), findsNothing);
    expect(find.byType(LineChart), findsNothing);
    // AC2-1：进入日历默认选中今天、面板收起（不占视觉焦点）
    expect(find.text('净额'), findsNothing);
    expect(find.text('当日无记账记录'), findsNothing);
  });

  // ── BK-DOC-28 需求2：点日改为日历下方滑动展开明细面板 ──

  testWidgets('tapping today expands the inline day detail panel', (tester) async {
    final db = memoryDb();
    final accountId = await seedAccount(db);
    final childCategoryId = await seedTwoLevelCategory(db);
    final now = DateTime.now();
    await seedTxn(
      db,
      accountId: accountId,
      categoryId: childCategoryId,
      at: DateTime(now.year, now.month, now.day, 8, 30),
      amountMinor: -2550,
    );
    await seedTxn(
      db,
      accountId: accountId,
      at: DateTime(now.year, now.month, now.day, 12, 5),
      amountMinor: 5000,
      type: TransactionType.income,
    );

    await mountCalendar(tester, db);
    await tapToday(tester);
    await pumpUntil(tester, find.text('净额'));
    await settlePanel(tester);

    // AC2-3：面板头「M月D日 周X」+ 净额 +「（N 笔）」
    final today = DateTime(now.year, now.month, now.day);
    expect(find.text(dayHeader(today)), findsOneWidget);
    expect(find.text('净额'), findsOneWidget);
    expect(find.text('¥24.50'), findsOneWidget);
    expect(find.text('（2 笔）'), findsOneWidget);
    // AC2-3：明细行显示「父类 / 子类」路径与收支语义金额
    expect(find.text('测试父类 / 测试子类'), findsOneWidget);
    expect(find.text('-¥25.50'), findsOneWidget);
    expect(find.text('+¥50.00'), findsOneWidget);
    // AC2-1：面板在月历下方原地展开，不再是模态底部弹窗
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester.getTopLeft(find.text('净额')).dy,
      greaterThan(tester.getBottomLeft(find.byType(TableCalendar<DailyTotal>)).dy),
    );
  });

  testWidgets('re-tapping the same day collapses the panel', (tester) async {
    await mountCalendar(tester, memoryDb());

    await tapToday(tester);
    await pumpUntil(tester, find.text('净额'));

    // AC2-1：同一日再次点击收起
    await tapToday(tester);
    await pumpUntilGone(tester, find.text('净额'));
    expect(find.text('当日无记账记录'), findsNothing);

    // 再点重新展开（toggle 语义可反复）
    await tapToday(tester);
    await pumpUntil(tester, find.text('净额'));
    expect(find.text('当日无记账记录'), findsOneWidget);
  });

  testWidgets('selecting another day keeps the panel open and switches content',
      (tester) async {
    final db = memoryDb();
    final accountId = await seedAccount(db);
    final now = DateTime.now();
    final other = otherDay();
    await seedTxn(
      db,
      accountId: accountId,
      at: DateTime(now.year, now.month, now.day, 9),
      amountMinor: -2550,
    );
    await seedTxn(
      db,
      accountId: accountId,
      at: DateTime(now.year, now.month, other, 9),
      amountMinor: -1000,
    );
    await seedTxn(
      db,
      accountId: accountId,
      at: DateTime(now.year, now.month, other, 18),
      amountMinor: -2000,
    );

    await mountCalendar(tester, db);
    await tapToday(tester);
    await pumpUntil(tester, find.text('（1 笔）'));

    // AC2-2：展开态下改选他日不收起，面板内容平滑切换为新日期
    await tapDay(tester, other);
    await pumpUntil(tester, find.text('（2 笔）'));
    await pumpUntilGone(tester, find.text('（1 笔）'));

    final otherDate = DateTime(now.year, now.month, other);
    expect(find.text('净额'), findsOneWidget);
    expect(find.text(dayHeader(otherDate)), findsOneWidget);
    expect(find.text(dayHeader(DateTime(now.year, now.month, now.day))), findsNothing);
    expect(find.text('-¥30.00'), findsOneWidget);
  });

  testWidgets('empty day keeps the panel open with a no-record placeholder',
      (tester) async {
    await mountCalendar(tester, memoryDb());

    await tapDay(tester, otherDay());
    await pumpUntil(tester, find.text('当日无记账记录'));

    // AC2-4：无记账记录时面板仍展开，显示空态文案（净额/笔数由面板头承载）
    expect(find.text('净额'), findsOneWidget);
    expect(find.text('¥0.00'), findsOneWidget);
    expect(find.text('（0 笔）'), findsOneWidget);
  });

  testWidgets('masked state replaces panel amounts with the mask', (tester) async {
    final db = memoryDb();
    final accountId = await seedAccount(db);
    final now = DateTime.now();
    await seedTxn(
      db,
      accountId: accountId,
      at: DateTime(now.year, now.month, now.day, 9),
      amountMinor: -2550,
    );

    await mountCalendar(tester, db, masked: true);
    await tapToday(tester);
    await pumpUntil(tester, find.text('净额'));
    await settlePanel(tester);

    // AC2-3：脱敏态下面板内全部金额走统一掩码
    expect(find.text('-¥25.50'), findsNothing);
    expect(find.text('¥***'), findsWidgets);
  });

  testWidgets('viewer tapping a date can still view the day detail (read-only)',
      (tester) async {
    final db = memoryDb();
    final accountId = await seedAccount(db);
    final childCategoryId = await seedTwoLevelCategory(db);
    final now = DateTime.now();
    await seedTxn(
      db,
      accountId: accountId,
      categoryId: childCategoryId,
      at: DateTime(now.year, now.month, now.day, 9),
      amountMinor: -2550,
    );

    await mountCalendar(tester, db, role: 'viewer');
    await tapToday(tester);
    await pumpUntil(tester, find.text('净额'));
    await settlePanel(tester);

    // AC2-5：只读角色可查看明细（纯展示列表，无写入口）；
    // 金额需限定在明细面板内——当日仅一笔时月历日格净额同为「-¥25.50」
    expect(find.text('测试父类 / 测试子类'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byWidgetPredicate((w) => w.key is ValueKey<String>),
        matching: find.text('-¥25.50'),
      ),
      findsWidgets,
    );
    expect(find.text('-¥25.50'), findsWidgets);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('long pressing a day expands the panel with the same semantics',
      (tester) async {
    await mountCalendar(tester, memoryDb());

    await tester.longPress(todayCellText(DateTime.now().day));
    await pumpUntil(tester, find.text('净额'));

    // AC2-1：长按与单击同语义（更新选中 + 展开面板）
    expect(find.text(dayHeader(DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ))), findsOneWidget);
    expect(find.text('当日无记账记录'), findsOneWidget);
  });
}
