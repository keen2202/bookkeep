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
import 'package:bookkeep_app/features/calendar/calendar_page.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
  });

  Widget harness(AppDatabase db) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        locale: Locale('zh', 'CN'),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: CalendarPage(),
      ),
    );
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

    // 今天：圆形高亮容器内为加粗白字（比普通日期更醒目）
    final day = DateTime.now().day;
    final todayText = tester.widget<Text>(
      find.descendant(
        of: find.byType(TableCalendar<DailyTotal>),
        matching: find.text('$day'),
      ),
    );
    expect(todayText.style?.fontWeight, FontWeight.bold);
    expect(todayText.style?.fontSize, 14);
    expect(todayText.style?.color, Colors.white);
  });
}
