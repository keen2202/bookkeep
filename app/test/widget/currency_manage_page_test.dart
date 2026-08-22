import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/repositories/currency_repository.dart';
import 'package:bookkeep_app/features/currency/currency_manage_page.dart';
import 'package:bookkeep_app/shared/widgets/app_button.dart';


/// 汇率管理页（审查 F-8 后回归）：
/// - 副标题插值修复（此前渲染 "1 Currency(...).code = x CNY" 错误文本）
/// - 未设置汇率显式标注 1:1 回退口径
/// - 手动改汇率后列表即时刷新
void main() {
  Widget harness(AppDatabase db) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CurrencyManagePage()),
      );

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    int maxTries = 100,
  }) async {
    for (var i = 0; i < maxTries; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $finder');
  }

  /// 币种列表按代码排序共 150+ 行（ListView 惰性构建），
  /// USD 等靠后币种须滚动进视口后才会被构建
  Future<void> scrollToText(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 80; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 50));
    }
    fail('scrollToText timed out for $finder');
  }

  testWidgets('renders rate subtitle with currency code (no raw object text)',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await CurrencyRepository(db).installSeeds();

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('人民币（CNY）'));

    // 主币种行
    expect(find.text('主币种 · 1 CNY = 1.0'), findsOneWidget);
    expect(find.textContaining('Currency('), findsNothing);
    // 未设置汇率的币种显式标注回退口径
    expect(find.textContaining('未设置汇率'), findsWidgets);
  });

  testWidgets('editing a manual rate refreshes the list', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = CurrencyRepository(db);
    await repo.installSeeds();
    await repo.setManualRate('USD', 7.25);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('人民币（CNY）'));
    await scrollToText(tester, find.text('1 USD = 7.2500 CNY'));

    // 打开修改弹窗，改为 7.5
    await tester.tap(find.widgetWithText(TextButton, '修改').first);
    await pumpUntil(tester, find.text('美元（USD）汇率'));
    await tester.pump(const Duration(milliseconds: 400)); // 弹窗入场动画
    final field = find.byType(TextField);
    await tester.enterText(field, '7.5');
    await tester.tap(find.widgetWithText(AppButton, '保存'));
    await pumpUntilGone2(tester, find.text('美元（USD）汇率'));

    // 列表立即反映新汇率（此前需重启应用才生效）
    await scrollToText(tester, find.text('1 USD = 7.5000 CNY'));
    expect(find.text('1 USD = 7.5000 CNY'), findsOneWidget);
  });

  testWidgets('rejects invalid rate input with inline error', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await CurrencyRepository(db).installSeeds();
    await CurrencyRepository(db).setManualRate('USD', 7.25);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('人民币（CNY）'));
    await scrollToText(tester, find.text('1 USD = 7.2500 CNY'));

    await tester.tap(find.widgetWithText(TextButton, '修改').first);
    await pumpUntil(tester, find.text('美元（USD）汇率'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.widgetWithText(AppButton, '保存'));

    // 弹窗不关闭且出现错误提示
    await pumpUntil(tester, find.text('请输入大于 0 的数值'));
    expect(find.text('美元（USD）汇率'), findsOneWidget);
  });
}

Future<void> pumpUntilGone2(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Timed out waiting for $finder to disappear');
}
