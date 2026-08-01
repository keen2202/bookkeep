import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/repositories/account_repository.dart';
import 'package:bookkeep_app/features/accounts/accounts_page.dart';

import '../helpers/sqlite.dart';

void main() {
  ensureSqliteLoaded();

  Widget harness(AppDatabase db) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: AccountsPage()),
    );
  }

  testWidgets('empty state prompts to create an account', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await tester.pumpAndSettle();

    expect(find.text('还没有账户，点击右下角 + 新建'), findsOneWidget);
  });

  testWidgets('creating an account via the sheet shows it with balance and net worth',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '账户名称'), '工资卡');
    await tester.enterText(find.widgetWithText(TextFormField, '初始余额（元）'), '1000.50');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('工资卡'), findsOneWidget);
    expect(find.text('¥1000.50'), findsWidgets);
    expect(find.text('¥1000.50'), findsNWidgets(2)); // 净资产 + 账户余额
  });

  testWidgets('archiving an account removes it from the list', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = AccountRepository(db);
    await repo.createAccount(name: '钱包', type: AccountType.cash, initialBalance: 500);

    await tester.pumpWidget(harness(db));
    await tester.pumpAndSettle();
    expect(find.text('钱包'), findsOneWidget);

    await tester.longPress(find.text('钱包'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('归档'));
    await tester.pumpAndSettle();

    expect(find.text('钱包'), findsNothing);
  });
}
