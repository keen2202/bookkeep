import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/repositories/account_repository.dart';
import 'package:bookkeep_app/data/repositories/book_repository.dart';
import 'package:bookkeep_app/features/books/books_page.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';

import '../helpers/sqlite.dart';

const bookA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const bookB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

void main() {
  ensureSqliteLoaded();
  late AppDatabase db;
  late BookRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = BookRepository(db);
    await repo.createLocalBook(id: bookA, name: '生活账本', type: 'life');
    await repo.switchBook(bookA);
  });

  tearDown(() => db.close());

  Widget harness() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => bookA),
      ],
      child: const MaterialApp(home: BooksPage()),
    );
  }

  testWidgets('列出账本并标注当前账本', (tester) async {
    await repo.createLocalBook(id: bookB, name: '生意账本', type: 'business');

    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('生活账本'), findsOneWidget);
    expect(find.text('生意账本'), findsOneWidget);
    expect(find.textContaining(' · 当前'), findsOneWidget);
  });

  testWidgets('点击账本切换当前账本', (tester) async {
    await repo.createLocalBook(id: bookB, name: '生意账本', type: 'business');

    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('生意账本'));
    await tester.pumpAndSettle();

    expect(await repo.currentBookId(), bookB);
    expect(find.textContaining('已切换到'), findsOneWidget);
  });

  testWidgets('新建账本出现在列表', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('新建账本'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '账本名称'), '旅行账本');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(find.text('旅行账本'), findsOneWidget);
    expect((await repo.listBooks()).map((b) => b.name), contains('旅行账本'));
  });

  testWidgets('切换账本后账户数据隔离（不同账本不同账户列表）', (tester) async {
    await repo.createLocalBook(id: bookB, name: '生意账本', type: 'business');
    await AccountRepository(db, bookId: bookA)
        .createAccount(name: 'A钱包', type: AccountType.cash);
    await AccountRepository(db, bookId: bookB)
        .createAccount(name: 'B钱包', type: AccountType.cash);

    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 600));

    final accountsA = await AccountRepository(db, bookId: bookA).listAccounts();
    final accountsB = await AccountRepository(db, bookId: bookB).listAccounts();
    expect(accountsA.single.name, 'A钱包');
    expect(accountsB.single.name, 'B钱包');
  });
}
