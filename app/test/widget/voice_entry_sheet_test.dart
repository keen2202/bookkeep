import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/account_repository.dart';
import 'package:bookkeep_app/features/auto_capture/voice_entry_sheet.dart';

import '../helpers/sqlite.dart';

void main() {
  ensureSqliteLoaded();

  group('VoiceRuleEngine 规则抽取', () {
    const engine = VoiceRuleEngine();

    test('支出文本：金额/方向/分类/时间（昨天）', () {
      final c = engine.extract('昨天午餐 打车花了25元');
      expect(c, isNotNull);
      expect(c!.amountMinor, -2500);
      expect(c.type, TransactionType.expense);
      expect(c.categoryName, '交通');
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(c.occurredAt.year, yesterday.year);
      expect(c.occurredAt.month, yesterday.month);
      expect(c.occurredAt.day, yesterday.day);
      expect(c.source, 'voice');
      expect(c.raw, '昨天午餐 打车花了25元');
    });

    test('收入文本抽取正数金额', () {
      final c = engine.extract('今天收到工资 5000元');
      expect(c, isNotNull);
      expect(c!.amountMinor, 500000);
      expect(c.type, TransactionType.income);
      expect(c.occurredAt.day, DateTime.now().day);
    });

    test('无金额或方向不明返回 null', () {
      expect(engine.extract('随便写的备注'), isNull);
      expect(engine.extract('100 元'), isNull);
    });
  });

  Widget harness(AppDatabase db) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: VoiceEntrySheet()),
    );
  }

  testWidgets('渲染语音记账页 UI', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await tester.pumpAndSettle();

    expect(find.text('语音记账'), findsOneWidget);
    expect(find.text('语音转文字结果 / 手动输入'), findsOneWidget);
    expect(find.text('语音识别'), findsOneWidget);
    expect(find.text('提取并确认'), findsOneWidget);
  });

  testWidgets('DisabledVoiceRecognizer 点击语音识别提示未开启', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('语音识别'));
    await tester.pumpAndSettle();

    expect(find.text('语音识别未开启（默认关闭）；请先输入文本'), findsOneWidget);
  });

  testWidgets('输入文本提取成功跳转确认页', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AccountRepository(db).createAccount(name: '钱包', type: AccountType.cash);

    await tester.pumpWidget(harness(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '昨天午餐 打车花了25元');
    await tester.tap(find.text('提取并确认'));
    await tester.pumpAndSettle();

    expect(find.text('确认入账（1 笔）'), findsOneWidget);
    expect(find.textContaining('分类：交通'), findsOneWidget);
    expect(find.textContaining('-¥25.00'), findsOneWidget);
  });

  testWidgets('无法识别金额与方向时提示', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '这是一段无法识别的文字');
    await tester.tap(find.text('提取并确认'));
    await tester.pumpAndSettle();

    expect(find.text('无法从文本中识别金额与收支方向'), findsOneWidget);
  });
}
