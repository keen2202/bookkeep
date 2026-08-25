import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/app.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/sync_ops_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/budget_repository.dart';
import 'package:bookkeep_app/data/repositories/category_repository.dart';
import 'package:bookkeep_app/data/repositories/lock_repository.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';

import '../helpers/fixtures.dart';
import 'categories_page_test.dart' show testSeed;

/// 黄金路径 e2e（Spec §5.2 集成测试的设备端前置；本地以 widget 级全链路验证）：
/// 记账 → 预算 → 报表 → 同步（op 入队）→ 隐私锁
void main() {
  Widget harness(AppDatabase db) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        categorySeedProvider.overrideWith((ref) async => testSeed),
      ],
      child: const BookkeepApp(),
    );
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.text(key));
    await tester.pump(const Duration(milliseconds: 30));
  }

  /// 经数字键盘输入 6 位 PIN 并等待 PBKDF2 校验/落库完成
  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tapKey(tester, d);
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $finder');
  }

  testWidgets('记账→预算→报表→同步→锁', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // 准备：seed 分类 + 账户 + 总预算 100 元
    final categoryRepo = CategoryRepository(db, bookId: testBookId);
    await categoryRepo.installSeeds(testSeed);
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final now = DateTime.now();
    await BudgetRepository(db, bookId: testBookId).createBudget(
      categoryId: null,
      period: now.toString().substring(0, 10),
      amountMinor: 10000,
    );
    expect(await db.select(db.syncOps).get(), hasLength(1)); // 预算创建入 op 队列

    await tester.pumpWidget(harness(db));
    await tester.pump(const Duration(milliseconds: 600));

    // ── ① 记账：FAB → 快速记账 25.5 元 ──
    await tester.tap(find.byTooltip('记一笔'));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.byType(DropdownButtonFormField<int>));
    for (final key in ['2', '5', '.', '5']) {
      await tapKey(tester, key);
    }
    // 账户自动回填（无需手动选择）
    await pumpUntilFound(tester, find.text('钱包（现金）'));
    // 分类：点字段弹出两级选择器 → 点 chip 即选中并关闭弹层
    await pumpUntilFound(tester, find.text('选择分类'));
    await tester.ensureVisible(find.text('选择分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择分类'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('早餐'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('已保存'), findsOneWidget);

    // ── ② 数据落库 + 同步 op 入队（乐观写，Spec §3.1）──
    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.single.amountMinor, -2550);
    expect(txs.single.type, TransactionType.expense);
    final ops = await db.select(db.syncOps).get();
    expect(ops, hasLength(2));
    expect(ops.last.entity, 'transaction');
    expect(ops.last.op, SyncOpCode.c);
    expect(ops.last.lamport, greaterThan(0));

    // ── ③ 账单页（默认主页）：当天支出合计 + 分类行；记账页预算卡联动 ──
    // （W3 迁移后'支出 '标签与金额拆分为独立 Text）
    expect(find.text('支出 '), findsOneWidget);
    expect(find.text('¥25.50'), findsOneWidget);
    expect(find.text('餐饮 / 早餐'), findsOneWidget);
    await tester.tap(find.byTooltip('记一笔'));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('本月预算'));
    expect(find.text('已花 ¥25.50 / 总额 ¥100.00'), findsOneWidget);
    expect(find.text('剩余 ¥74.50'), findsOneWidget);
    // 中文 locale 下 BackButton tooltip 为「返回」，pageBack 找不到，直接按类型找
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // ── ④ 报表页：三图渲染（当月区间）──
    await tester.tap(find.text('报表'));
    await tester.pumpAndSettle();
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    await tester.scrollUntilVisible(find.text('收支趋势'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('收支趋势'), findsOneWidget);

    // ── ⑤ 设置 → 开启隐私锁 → 立即锁定 → 锁屏覆盖 → PIN 解锁 ──
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    // 设置弹层可滚动（新增汇率管理入口后隐私锁可能在视口外）
    await tester.scrollUntilVisible(find.text('隐私锁'), 100,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('隐私锁'));
    await tester.pumpAndSettle();

    // 设置 PIN：两段式输入
    expect(find.text('设置 6 位数字 PIN'), findsOneWidget);
    await enterPin(tester, '123456');
    expect(find.text('再次输入确认'), findsOneWidget);
    await enterPin(tester, '123456');

    // 开启成功：显示管理项（设置弹层可滚动，先滚动到可见再点击）
    expect(find.text('立即锁定'), findsOneWidget);
    expect(find.text('修改 PIN'), findsOneWidget);

    // 立即锁定 → LockGate 覆盖整个 App
    await tester.ensureVisible(find.text('立即锁定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('立即锁定'));
    await tester.pumpAndSettle();
    expect(find.text('bookkeep 已锁定'), findsOneWidget);
    expect(find.byType(PieChart), findsNothing);

    // PIN 解锁 → 回到应用
    await enterPin(tester, '123456');
    expect(find.text('bookkeep 已锁定'), findsNothing);
    expect(find.text('报表'), findsWidgets);

    // 杀进程重进仍锁：冷启动初始状态为锁定（数据持久化在库中）
    final restarted = LockRepository(db).initialState();
    expect((await restarted).configured, isTrue);
  });
}
