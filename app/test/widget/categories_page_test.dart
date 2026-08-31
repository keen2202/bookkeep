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
import 'package:bookkeep_app/shared/widgets/app_button.dart';

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
    // 默认主页为账单，切换到分类 tab
    await tester.tap(find.text('分类').last);
    await tester.pump(const Duration(milliseconds: 300));
    await pumpUntil(tester, find.text('餐饮'));

    await tester.tap(find.byTooltip('新建分类'));
    await pumpUntil(tester, find.widgetWithText(TextFormField, '分类名称'));
    await tester.pump(const Duration(milliseconds: 400)); // 弹窗入场动画完成
    await tester.enterText(find.widgetWithText(TextFormField, '分类名称'), '旅行');
    // 输入框聚焦状态会影响弹层内后续点击命中，先取消焦点再操作
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    // 弹层内含图标库较高：保存按钮先滚入可视区再点击
    await tester.ensureVisible(find.widgetWithText(AppButton, '保存'));
    await tester.pump();
    await tester.tap(find.widgetWithText(AppButton, '保存'));
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
    await tester.tap(find.text('删除')); // 操作弹层关闭，确认弹窗弹出（其内亦有「删除」）
    await pumpUntil(tester, find.text('删除分类'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('删除').last); // 确认删除
    await pumpUntilGone(tester, find.text('删除分类')); // 确认弹窗关闭
    await pumpUntilGone(tester, find.text('临时')); // 列表刷新完成
    expect(find.text('临时'), findsNothing);
  });

  testWidgets('system categories expose edit and delete actions', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('早餐'));
    await tester.pump(const Duration(milliseconds: 200));

    // 编辑入口对系统分类可用（此前 isSystem 完全屏蔽增删改）
    await tester.tap(find.descendant(
      of: find.widgetWithText(ListTile, '早餐'),
      matching: find.byIcon(Icons.more_vert),
    ));
    await pumpUntil(tester, find.text('编辑'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('编辑'));
    await pumpUntil(tester, find.widgetWithText(TextFormField, '分类名称'));
    await tester.pumpAndSettle(); // 编辑弹层入场动画完成（否则保存按钮尚在屏外）
    await tester.enterText(find.widgetWithText(TextFormField, '分类名称'), '早点铺');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(AppButton, '保存'));
    await tester.pump();
    await tester.tap(find.widgetWithText(AppButton, '保存'));
    await pumpUntilGone(tester, find.widgetWithText(TextFormField, '分类名称'));

    expect(find.text('早点铺'), findsOneWidget);
    expect(find.text('早餐'), findsNothing);
  });

  testWidgets('deleting a parent with children is blocked with a hint', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('餐饮'));
    await tester.pump(const Duration(milliseconds: 200));

    // 「餐饮」含子分类（早餐/晚餐）→ 删除应被拒绝并提示
    await tester.tap(find.descendant(
      of: find.widgetWithText(ListTile, '餐饮'),
      matching: find.byIcon(Icons.more_vert),
    ));
    await pumpUntil(tester, find.text('删除'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('删除')); // 操作弹层关闭，确认弹窗弹出
    await pumpUntil(tester, find.text('删除分类'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('删除').last); // 确认删除 → 仓库拒绝并提示
    await pumpUntilGone(tester, find.text('删除分类'));
    await pumpUntil(tester, find.textContaining('包含子分类'));
    // 分类仍在列表中
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('早餐'), findsOneWidget);
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

  // ── BK-DOC-26 需求7：层级选择 + 自定义图标 ──

  testWidgets('creating a second-level category: pick level and parent', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(shellHarness(db));
    await tester.tap(find.text('分类').last);
    await tester.pump(const Duration(milliseconds: 300));
    await pumpUntil(tester, find.text('餐饮'));

    await tester.tap(find.byTooltip('新建分类'));
    await pumpUntil(tester, find.widgetWithText(TextFormField, '分类名称'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.widgetWithText(TextFormField, '分类名称'), '商务打车');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    // 选择二级层级 → 出现「归属一级分类」下拉
    await tester.ensureVisible(find.text('二级分类'));
    await tester.pump();
    await tester.tap(find.text('二级分类'));
    await tester.pump();

    await tester.ensureVisible(find.text('归属一级分类'));
    await tester.pump();
    await tester.tap(find.text('归属一级分类'));
    await tester.pumpAndSettle();
    // 支出型父级候选含「交通」；菜单项覆盖列表同名组头，取最后一个
    await tester.tap(find.text('交通').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(AppButton, '保存'));
    await tester.pump();
    await tester.tap(find.widgetWithText(AppButton, '保存'));
    await pumpUntilGone(tester, find.text('保存'));
    await pumpUntil(tester, find.byType(ListView));

    await tester.scrollUntilVisible(find.text('商务打车'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('商务打车'), findsOneWidget);

    // 落库校验：归属父级（交通），为二级分类
    final repo = CategoryRepository(db, bookId: testBookId);
    final all = await repo.listCategories();
    final created = all.firstWhere((c) => c.name == '商务打车');
    final parent = all.firstWhere((c) => c.id == created.parentId);
    expect(created.parentId, isNotNull);
    expect(parent.name, '交通');
  });

  testWidgets('creating a category with a custom icon', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(shellHarness(db));
    await tester.tap(find.text('分类').last);
    await tester.pump(const Duration(milliseconds: 300));
    await pumpUntil(tester, find.text('餐饮'));

    await tester.tap(find.byTooltip('新建分类'));
    await pumpUntil(tester, find.widgetWithText(TextFormField, '分类名称'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.widgetWithText(TextFormField, '分类名称'), '电影之夜');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    // 图标库选择 movie（背景列表无同名图标，命中唯一）
    await tester.ensureVisible(find.byIcon(Icons.movie));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.movie).first);
    await tester.pump();

    await tester.ensureVisible(find.widgetWithText(AppButton, '保存'));
    await tester.pump();
    await tester.tap(find.widgetWithText(AppButton, '保存'));
    await pumpUntilGone(tester, find.text('保存'));
    await pumpUntil(tester, find.byType(ListView));

    await tester.scrollUntilVisible(find.text('电影之夜'), 300,
        scrollable: find.byType(Scrollable).first);
    // 列表行渲染所选图标
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, '电影之夜'),
        matching: find.byIcon(Icons.movie),
      ),
      findsOneWidget,
    );
  });
}
