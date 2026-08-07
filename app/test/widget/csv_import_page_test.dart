import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/repositories/account_repository.dart';
import 'package:bookkeep_app/features/auto_capture/csv_import/csv_import_page.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';

import '../helpers/fixtures.dart';

/// 支付宝账单样本：表头 + 2 条有效记录（可附加批内重复行）
String alipayCsv({int duplicateCount = 0}) {
  final rows = <String>[
    '交易时间,交易分类,交易对方,商品说明,收/支,金额,支付方式,交易状态',
    '2026-07-01 10:00:00,餐饮,星巴克,咖啡,支出,25.00,余额宝,交易成功',
    '2026-07-01 11:00:00,餐饮,肯德基,汉堡,支出,40.50,余额宝,交易成功',
  ];
  for (var i = 0; i < duplicateCount; i++) {
    rows.add('2026-07-01 10:00:00,餐饮,星巴克,咖啡,支出,25.00,余额宝,交易成功');
  }
  return rows.join('\n');
}

void main() {
  Widget harness(AppDatabase db) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
      ],
      child: const MaterialApp(home: CsvImportPage()),
    );
  }

  testWidgets('渲染导入页说明文案与输入框', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await tester.pumpAndSettle();

    expect(find.text('CSV 导入'), findsOneWidget);
    expect(find.text('粘贴支付宝/微信账单 CSV（导出账单后复制内容）：'), findsOneWidget);
    expect(find.text('交易时间,交易分类,交易对方,...'), findsOneWidget);
    expect(find.text('解析并去重'), findsOneWidget);
  });

  testWidgets('空输入点击解析无提示不崩溃', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('解析并去重'));
    await tester.pumpAndSettle();

    expect(find.textContaining('共识别'), findsNothing);
    expect(find.textContaining('未识别到有效账单记录'), findsNothing);
    expect(find.textContaining('确认入账'), findsNothing);
  });

  testWidgets('无效 CSV 提示未识别到有效账单记录', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '这不是账单数据');
    await tester.tap(find.text('解析并去重'));
    await tester.pumpAndSettle();

    expect(find.text('未识别到有效账单记录（请确认粘贴的是支付宝/微信账单 CSV）'), findsOneWidget);
  });

  testWidgets('解析有效 CSV 提示识别数量并出现确认按钮', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), alipayCsv());
    await tester.tap(find.text('解析并去重'));
    await tester.pumpAndSettle();

    expect(find.text('共识别 2 条，其中重复 0 条已跳过'), findsOneWidget);
    expect(find.text('确认入账（2 笔）'), findsOneWidget);
  });

  testWidgets('批内重复去重提示跳过的条数', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), alipayCsv(duplicateCount: 1));
    await tester.tap(find.text('解析并去重'));
    await tester.pumpAndSettle();

    expect(find.text('共识别 3 条，其中重复 1 条已跳过'), findsOneWidget);
    expect(find.text('确认入账（2 笔）'), findsOneWidget);
  });

  testWidgets('确认入账跳转确认页', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AccountRepository(db, bookId: testBookId).createAccount(name: '钱包', type: AccountType.cash);

    await tester.pumpWidget(harness(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), alipayCsv());
    await tester.tap(find.text('解析并去重'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认入账（2 笔）'));
    await tester.pumpAndSettle();

    // 确认页标题（AppBar）
    expect(find.text('确认入账（2 笔）'), findsOneWidget);
  });
}
