import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/app.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/categories_table.dart';
import 'package:bookkeep_app/data/repositories/account_repository.dart';
import 'package:bookkeep_app/data/repositories/category_repository.dart';
import 'package:bookkeep_app/features/accounts/accounts_page.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';
import 'package:bookkeep_app/features/books/books_page.dart' show showBookActions;
import 'package:bookkeep_app/features/books/books_providers.dart';

import '../helpers/fixtures.dart';
import 'categories_page_test.dart' show testSeed;

/// 权限矩阵 UI 拦截（Spec §4.1）：viewer 角色隐藏全部写入口。
/// 服务端 403 为权威校验，此处验证客户端侧双重拒绝。
void main() {
  Widget shellHarness(AppDatabase db, {String role = 'owner'}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        currentRoleProvider.overrideWith((ref) => role),
        categorySeedProvider.overrideWith((ref) async => testSeed),
      ],
      child: const BookkeepApp(),
    );
  }

  Widget pageHarness(AppDatabase db, Widget page, {String role = 'owner'}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        currentRoleProvider.overrideWith((ref) => role),
        categorySeedProvider.overrideWith((ref) async => testSeed),
      ],
      child: MaterialApp(home: Scaffold(body: page)),
    );
  }

  Future<void> switchTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('viewer 隐藏主界面「记一笔」FAB', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(shellHarness(db, role: 'viewer'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byTooltip('记一笔'), findsNothing);
  });

  testWidgets('owner 显示主界面「记一笔」FAB', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(shellHarness(db));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byTooltip('记一笔'), findsOneWidget);
  });

  testWidgets('viewer 隐藏账户页「新建账户」FAB 且长按无编辑菜单', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AccountRepository(db, bookId: testBookId).createAccount(name: '钱包', type: AccountType.cash);

    await tester.pumpWidget(pageHarness(db, const AccountsPage(), role: 'viewer'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('新建账户'), findsNothing);

    await tester.longPress(find.text('钱包'));
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsNothing);
    expect(find.text('归档'), findsNothing);
  });

  testWidgets('owner 账户页可新建与编辑', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AccountRepository(db, bookId: testBookId).createAccount(name: '钱包', type: AccountType.cash);

    await tester.pumpWidget(pageHarness(db, const AccountsPage()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('新建账户'), findsOneWidget);

    await tester.longPress(find.text('钱包'));
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('归档'), findsOneWidget);
  });

  testWidgets('viewer 账单页空态提示（无写入口）', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(shellHarness(db, role: 'viewer'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('暂无账单'), findsOneWidget);
  });

  testWidgets('owner 账单页空态提示', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(shellHarness(db));
    await tester.pump(const Duration(milliseconds: 600));
    // W3 迁移至 AppEmpty：title 与 message 拆分为独立 Text
    expect(find.text('还没有账单'), findsOneWidget);
    expect(find.text('点击右下角 + 记一笔'), findsOneWidget);
  });

  testWidgets('viewer 隐藏周期记账页「新建规则/立即补跑」动作', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(shellHarness(db, role: 'viewer'));
    await switchTab(tester, '周期记账');
    await tester.pumpAndSettle();
    expect(find.byTooltip('新建规则'), findsNothing);
    expect(find.byTooltip('立即补跑'), findsNothing);
  });

  testWidgets('owner 周期记账页可新建规则与补跑', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(shellHarness(db));
    await switchTab(tester, '周期记账');
    await tester.pumpAndSettle();
    expect(find.byTooltip('新建规则'), findsOneWidget);
    expect(find.byTooltip('立即补跑'), findsOneWidget);
  });

  testWidgets('viewer 隐藏分类页新建动作与自定义分类编辑入口', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await CategoryRepository(db, bookId: testBookId).createCategory(
      name: '旅行',
      icon: 'tag',
      color: 0xFF000000,
      kind: CategoryKind.expense,
    );

    await tester.pumpWidget(shellHarness(db, role: 'viewer'));
    await tester.pump(const Duration(milliseconds: 600));
    await switchTab(tester, '分类');
    expect(find.byTooltip('新建分类'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text('旅行'), findsOneWidget);
  });

  testWidgets('viewer 不可见邀请成员入口，成员管理可见', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final harness = ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentRoleProvider.overrideWith((ref) => 'viewer'),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showBookActions(context, bookId: 'b1'),
                child: const Text('actions'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(harness);
    await tester.tap(find.text('actions'));
    await tester.pumpAndSettle();

    expect(find.text('邀请成员'), findsNothing);
    expect(find.text('成员管理'), findsOneWidget);
  });

  testWidgets('owner 可见邀请成员入口', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final harness = ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentRoleProvider.overrideWith((ref) => 'owner'),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showBookActions(context, bookId: 'b1'),
                child: const Text('actions'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(harness);
    await tester.tap(find.text('actions'));
    await tester.pumpAndSettle();

    expect(find.text('邀请成员'), findsOneWidget);
    expect(find.text('成员管理'), findsOneWidget);
  });
}
