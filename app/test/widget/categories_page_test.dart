import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/app.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/categories_table.dart';
import 'package:bookkeep_app/data/repositories/category_repository.dart';
import 'package:bookkeep_app/domain/models/category_seed.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';

import '../helpers/fixtures.dart';

/// 测试用 seed：两级分类样例（生产 seed 的真实性由 category_repository_test 覆盖）
const testSeed = CategorySeed(
  version: 1,
  parents: [
    CategorySeedNode(
      name: '餐饮',
      icon: 'restaurant',
      color: 0xFFFF7043,
      kind: CategoryKind.expense,
      children: [
        CategorySeedNode(name: '早餐', icon: 'free_breakfast', color: 0xFFFF7043, kind: CategoryKind.expense),
        CategorySeedNode(name: '晚餐', icon: 'dinner_dining', color: 0xFFFF7043, kind: CategoryKind.expense),
      ],
    ),
    CategorySeedNode(
      name: '交通',
      icon: 'directions_bus',
      color: 0xFF1E88E5,
      kind: CategoryKind.expense,
      children: [
        CategorySeedNode(name: '打车', icon: 'local_taxi', color: 0xFF1E88E5, kind: CategoryKind.expense),
      ],
    ),
    CategorySeedNode(
      name: '工资',
      icon: 'payments',
      color: 0xFF42A5F5,
      kind: CategoryKind.income,
      children: [
        CategorySeedNode(name: '基本工资', icon: 'payments', color: 0xFF42A5F5, kind: CategoryKind.income),
      ],
    ),
  ],
);

/// 轮询 pump 直到条件满足（避免真实 I/O 与假时钟的 pumpAndSettle 竞态）
Future<void> pumpUntil(WidgetTester tester, Finder finder, {int maxTries = 100}) async {
  for (var i = 0; i < maxTries; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

/// 轮询 pump 直到元素消失（弹窗关闭/加载完成）
Future<void> pumpUntilGone(WidgetTester tester, Finder finder, {int maxTries = 100}) async {
  for (var i = 0; i < maxTries; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Timed out waiting for $finder to disappear');
}

void main() {
  Widget harness(AppDatabase db) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        categorySeedProvider.overrideWith((ref) async => testSeed),
      ],
      child: const MaterialApp(home: Scaffold(body: CategoriesPage())),
    );
  }

  // 审查 U-1：新建分类动作已上移到主 shell AppBar
  Widget shellHarness(AppDatabase db) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        categorySeedProvider.overrideWith((ref) async => testSeed),
      ],
      child: const BookkeepApp(),
    );
  }

  testWidgets('seed categories install and render parent groups', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('餐饮'));

    expect(find.text('交通'), findsOneWidget);
    expect(find.text('早餐'), findsOneWidget);
    expect(find.text('工资'), findsOneWidget);
    expect(find.text('基本工资'), findsOneWidget);
  });

  testWidgets('creating a custom category appends it to the list', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(shellHarness(db));
    await pumpUntil(tester, find.text('餐饮'));

    await tester.tap(find.byTooltip('新建分类'));
    await pumpUntil(tester, find.widgetWithText(TextFormField, '分类名称'));
    await tester.pump(const Duration(milliseconds: 400)); // 弹窗入场动画完成
    await tester.enterText(find.widgetWithText(TextFormField, '分类名称'), '旅行');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await pumpUntilGone(tester, find.text('保存')); // 弹窗完全关闭
    await pumpUntil(tester, find.byType(ListView)); // 数据视图已刷新

    await tester.scrollUntilVisible(find.text('旅行'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('旅行'), findsOneWidget);
  });

  testWidgets('deleting a custom category removes it from the list', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = CategoryRepository(db, bookId: testBookId);
    await repo.createCategory(
      name: '临时',
      icon: 'tag',
      color: 0xFF000000,
      kind: CategoryKind.expense,
    );

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('临时'));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.descendant(
      of: find.widgetWithText(ListTile, '临时'),
      matching: find.byIcon(Icons.more_vert),
    ));
    await pumpUntil(tester, find.text('删除'));
    await tester.pump(const Duration(milliseconds: 400)); // 弹窗入场动画完成
    await tester.tap(find.text('删除'));
    await pumpUntilGone(tester, find.text('删除')); // 弹窗关闭
    await pumpUntilGone(tester, find.text('临时')); // 列表刷新完成
    expect(find.text('临时'), findsNothing);
  });

  testWidgets('collapsing a parent header hides its children', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('餐饮'));
    await tester.pump(const Duration(milliseconds: 200));

    // 默认全部展开：子分类可见
    expect(find.text('早餐'), findsOneWidget);

    // 点击父分类标题折叠 → 子分类隐藏
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    expect(find.text('早餐'), findsNothing);

    // 再次点击展开 → 子分类恢复
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    expect(find.text('早餐'), findsOneWidget);
  });
}
