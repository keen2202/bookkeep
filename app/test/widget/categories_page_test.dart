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
  /// 仅含支出分类的 seed：用于验证「收入」tab 的空态（AC5-4）
  const expenseOnlySeed = CategorySeed(
    version: 1,
    parents: [
      CategorySeedNode(
        name: '餐饮',
        icon: 'restaurant',
        color: 0xFFFF7043,
        kind: CategoryKind.expense,
      ),
    ],
  );

  Widget harness(AppDatabase db, {CategorySeed seed = testSeed}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        categorySeedProvider.overrideWith((ref) async => seed),
      ],
      child: const MaterialApp(home: Scaffold(body: CategoriesPage())),
    );
  }

  // 审查 U-1：新建分类动作已上移到宿主页 AppBar
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

  /// BK-DOC-28 需求6：分类入口自底部 Tab 下沉至设置弹层 → 独立分类管理页
  Future<void> openCategoryManagement(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('分类管理'), 120,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('分类管理'));
    // 路由入场动画完成：设置弹层之上再 push 独立页，过渡约 600ms。
    // 须分帧推进假时钟——单次长 pump 只渲染一帧，过渡不推进，
    // 未结束即点 AppBar 动作会因页面仍在滑动而命中视口外坐标
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('seed categories install and render expense groups collapsed',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('餐饮'));

    // 需求5 AC5-1：默认「支出」tab → 收入型分类（工资/基本工资）不在列表
    expect(find.text('交通'), findsOneWidget);
    expect(find.text('工资'), findsNothing);
    // 需求4 AC4-1：进入即全折叠 → 二级分类不可见
    expect(find.text('早餐'), findsNothing);
    expect(find.text('基本工资'), findsNothing);
  });

  testWidgets('creating a custom category appends it to the list', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(shellHarness(db));
    // 需求6：分类入口下沉设置弹层 → 独立分类管理页
    await openCategoryManagement(tester);
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
    // 新建的一级支出分类落在默认「支出」tab；组头不受折叠态影响，直接可见
    expect(find.text('旅行'), findsOneWidget);
    // 需求4 AC4-2：无子级的组头不渲染折叠箭头
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, '旅行'),
        matching: find.byIcon(Icons.expand_more),
      ),
      findsNothing,
    );
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
    await pumpUntil(tester, find.text('餐饮'));
    // 需求4：默认全折叠 → 先展开「餐饮」组头才能操作其二级分类
    await tester.tap(find.text('餐饮'));
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
    // Spec §2.4 边界：数据刷新不重置展开态 → 改名后的二级分类仍在展开的组内
    await pumpUntil(tester, find.text('早点铺'));

    expect(find.text('早点铺'), findsOneWidget);
    expect(find.text('早餐'), findsNothing);
  });

  testWidgets('deleting a parent with children is blocked with a hint', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('餐饮'));
    // 需求4：默认全折叠 → 先展开，末尾才能断言子分类未被删掉
    await tester.tap(find.text('餐饮'));
    await pumpUntil(tester, find.text('早餐'));
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
    // 分类仍在列表中（删除被拒 → 未触发刷新，展开态与子分类均保持）
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('早餐'), findsOneWidget);
  });

  testWidgets('默认全折叠：点组头展开二级分类，再点收起', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('餐饮'));
    await tester.pump(const Duration(milliseconds: 200));

    // AC4-1：进入即全折叠 → 二级分类不可见；收起态箭头指向「可展开」
    expect(find.text('早餐'), findsNothing);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, '餐饮'),
        matching: find.byIcon(Icons.expand_more),
      ),
      findsOneWidget,
    );

    // AC4-2：点击组头展开 → 子分类可见，箭头翻转为「可收起」
    // （「交通」同样有子级但保持收起，故 expand_less 全局唯一）
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    expect(find.text('早餐'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);

    // 再次点击收起 → 子分类隐藏
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    expect(find.text('早餐'), findsNothing);
    expect(find.byIcon(Icons.expand_less), findsNothing);
  });

  // ── BK-DOC-28 需求5：分类页顶部支出/收入两栏 tab ──

  testWidgets('切换收支 tab 过滤列表并重置为全折叠', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db));
    await pumpUntil(tester, find.text('餐饮'));

    // AC5-1：顶部两栏 tab，选中态沿用需求7（无 ✔、颜色突显）
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);

    // 支出 tab：展开「餐饮」看到二级分类
    await tester.tap(find.text('餐饮'));
    await pumpUntil(tester, find.text('早餐'));

    // AC5-2：切到「收入」→ 仅收入型分类，且列表回到全折叠
    await tester.tap(find.text('收入'));
    await tester.pump();
    expect(find.text('工资'), findsOneWidget);
    expect(find.text('餐饮'), findsNothing);
    expect(find.text('基本工资'), findsNothing);

    // AC4-3：切回「支出」→ 展开态已随 tab 切换清空，仍为全折叠
    await tester.tap(find.text('支出'));
    await tester.pump();
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('工资'), findsNothing);
    expect(find.text('早餐'), findsNothing);
  });

  testWidgets('空收入类型显示空态提示', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(harness(db, seed: expenseOnlySeed));
    await pumpUntil(tester, find.text('餐饮'));

    // AC5-4：该账本无收入分类 → 收入 tab 走空态引导而非空白列表
    await tester.tap(find.text('收入'));
    await pumpUntil(tester, find.text('暂无收入分类，点击右上角新建'));
    expect(find.text('暂无收入分类，点击右上角新建'), findsOneWidget);
  });

  testWidgets('从收入 tab 新建分类默认预填收入类型', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(shellHarness(db));
    await openCategoryManagement(tester);
    await pumpUntil(tester, find.text('餐饮'));

    await tester.tap(find.text('收入'));
    await tester.pump();
    await tester.tap(find.byTooltip('新建分类'));
    await pumpUntil(tester, find.widgetWithText(TextFormField, '分类名称'));
    await tester.pump(const Duration(milliseconds: 400)); // 弹窗入场动画完成

    // AC5-3：弹层类型分段控件预选「收入」——页面 tab 同为
    // SegmentedButton<CategoryKind>，故限定在 BottomSheet 内取
    expect(
      tester
          .widget<SegmentedButton<CategoryKind>>(find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(SegmentedButton<CategoryKind>),
          ))
          .selected,
      {CategoryKind.income},
    );

    await tester.enterText(find.widgetWithText(TextFormField, '分类名称'), '奖金');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(AppButton, '保存'));
    await tester.pump();
    await tester.tap(find.widgetWithText(AppButton, '保存'));
    await pumpUntilGone(tester, find.text('保存'));
    // 预填生效 → 新分类落在当前（收入）tab，支出分类不在列表
    await pumpUntil(tester, find.text('奖金'));
    expect(find.text('奖金'), findsOneWidget);
    expect(find.text('工资'), findsOneWidget);
    expect(find.text('餐饮'), findsNothing);
  });

  testWidgets('退出分类页再进入恢复默认支出 tab 与全折叠', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(shellHarness(db));
    await openCategoryManagement(tester);
    await pumpUntil(tester, find.text('餐饮'));

    // 制造非默认状态：展开「餐饮」+ 切到「收入」tab
    await tester.tap(find.text('餐饮'));
    await pumpUntil(tester, find.text('早餐'));
    await tester.tap(find.text('收入'));
    await tester.pump();
    expect(find.text('工资'), findsOneWidget);

    // 返回主 shell（GlassScaffold 对可返回路由自动提供返回键）；
    // 中文 locale 下 BackButton tooltip 为「返回」，pageBack 找不到，
    // 直接按类型找（同 golden_path_test 既有约定）
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // 返回后落回仍开着的设置弹层（分类页自弹层之上 push，未消费弹层，
    // 与周期记账/备份入口行为一致），重进直接点「分类管理」
    await tester.tap(find.text('分类管理'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // AC4-3：重进 → 默认「支出」tab 且全折叠（tab 状态 autoDispose，不持久化）
    await pumpUntil(tester, find.text('餐饮'));
    expect(find.text('工资'), findsNothing);
    expect(find.text('早餐'), findsNothing);
  });

  // ── BK-DOC-26 需求7：层级选择 + 自定义图标 ──

  testWidgets('creating a second-level category: pick level and parent', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(shellHarness(db));
    await openCategoryManagement(tester);
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

    // 需求4：默认全折叠 → 展开「交通」组头才能看到新建的二级分类
    await tester.tap(find.text('交通'));
    await pumpUntil(tester, find.text('商务打车'));
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
    await openCategoryManagement(tester);
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
