import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/repositories/reports_repository.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/calendar/calendar_page.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';

import '../helpers/fixtures.dart';
import 'categories_page_test.dart' show testSeed;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
  });

  Widget harness(AppDatabase db, {String role = 'owner'}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        currentRoleProvider.overrideWith((ref) => role),
        categorySeedProvider.overrideWith((ref) async => testSeed),
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

  /// 点击日历上「今天」所在的日格
  Future<void> tapTodayCell(WidgetTester tester) async {
    final day = DateTime.now().day;
    await tester.tap(todayCellText(day));
    await tester.pumpAndSettle();
  }

  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $finder');
  }

  testWidgets('calendar renders in Chinese with a prominent today cell', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('周一'));

    // 星期表头为中文
    expect(find.text('周一'), findsOneWidget);
    expect(find.text('周日'), findsOneWidget);
    // 月份标题为中文格式（如 2026年8月）
    expect(find.textContaining('年'), findsWidgets);
    expect(find.textContaining('月'), findsWidgets);

    // 今天：固定直径圆形高亮内为加粗白字（比普通日期更醒目）
    final day = DateTime.now().day;
    final todayText = tester.widget<Text>(todayCellText(day));
    expect(todayText.style?.fontWeight, FontWeight.bold);
    // W3 迁移后今日日期走 TextTheme（bodyMedium）加粗白字，不再裸字号；
    // 具体字号随主题字阶，此处不锁死具体值
    expect(todayText.style?.color, Colors.white);
  });

  testWidgets('adjacent-month days render dimmed numbers instead of blank cells',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('周一'));

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

  testWidgets('tapping a date opens quick entry prefilled with that day', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('周一'));
    await tapTodayCell(tester);

    expect(find.text('记一笔'), findsOneWidget);
    final now = DateTime.now();
    final expected = '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('viewer tapping a date does not open quick entry', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db, role: 'viewer'));
    await pumpUntil(tester, find.text('周一'));
    await tapTodayCell(tester);

    expect(find.text('记一笔'), findsNothing);
  });

  testWidgets('long pressing a date shows the day detail sheet', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('周一'));

    final day = DateTime.now().day;
    await tester.longPress(todayCellText(day));
    await tester.pumpAndSettle();

    expect(find.textContaining('净额'), findsOneWidget);
  });
}
