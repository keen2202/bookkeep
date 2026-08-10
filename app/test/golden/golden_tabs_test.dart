import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/category_repository.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';
import 'package:bookkeep_app/features/recurring/recurring_page.dart';
import 'package:bookkeep_app/features/reports/reports_page.dart';
import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';

import '../helpers/fixtures.dart' show testBookId;
import '../widget/categories_page_test.dart' show testSeed;

/// Golden 扩展（设计文档 §6.1 交付：8 套主题 × 五个主 Tab 观感）：
/// 分类/周期记账/报表 三个 Tab 补齐（账单主页见 golden_ui_test.dart；
/// 日历 Tab 含"今日"高亮、随日期漂移，不适合 Golden，走人工走查）。
/// 容差 0.5%，比较器与 golden_ui_test.dart 相同。
void main() {
  setUpAll(() {
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.parse('test/golden/golden_tabs_test.dart'),
      precisionTolerance: 0.005,
    );
  });

  Future<AppDatabase> seedDb() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catRepo = CategoryRepository(db, bookId: testBookId);
    await catRepo.installSeeds(testSeed);
    final cats = await catRepo.listCategories();
    final breakfastId = cats.firstWhere((c) => c.name == '早餐').id;
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: accountId,
          categoryId: Value(breakfastId),
          type: TransactionType.expense,
          amountMinor: -2550,
          currency: 'CNY',
          occurredAt: DateTime(2026, 8, 10, 8, 30),
          updatedAt: DateTime.utc(2026, 8, 10),
        ));
    return db;
  }

  Future<Widget> harness(AppDatabase db, Widget page) async {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentBookIdProvider.overrideWith((ref) => testBookId),
        categorySeedProvider.overrideWith((ref) async => testSeed),
      ],
      child: Scaffold(body: page),
    );
  }

  Future<void> pumpGolden(
    WidgetTester tester,
    AppThemePreset preset,
    Widget home,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(preset),
      home: home,
    ));
    // 报表图表动画/异步数据加载完成后稳定渲染
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  Future<void> expectGolden(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  for (final preset in kThemePresetsV2) {
    group('${preset.id} ${preset.name} Tab 观感', () {
      testWidgets('分类页', (tester) async {
        final db = await seedDb();
        await pumpGolden(tester, preset,
            await harness(db, const CategoriesPage()));
        await expectGolden(tester, '${preset.id}_categories');
      });

      testWidgets('周期记账页', (tester) async {
        final db = await seedDb();
        await pumpGolden(tester, preset,
            await harness(db, const RecurringPage()));
        await expectGolden(tester, '${preset.id}_recurring');
      });

      testWidgets('报表页', (tester) async {
        final db = await seedDb();
        await pumpGolden(tester, preset,
            await harness(db, const ReportsPage()));
        await expectGolden(tester, '${preset.id}_reports');
      });
    });
  }
}

/// 0.5% 容差 golden 比较器（与 golden_ui_test.dart 同实现）
class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  })  : assert(
          0 <= precisionTolerance && precisionTolerance <= 1,
          'precisionTolerance must be between 0 and 1',
        ),
        _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (!passed) {
      throw TestFailure(
        'Golden 差异 ${(result.diffPercent * 100).toStringAsFixed(2)}% '
        '> ${(_precisionTolerance * 100).toStringAsFixed(1)}%（$golden）',
      );
    }
    result.dispose();
    return true;
  }
}
