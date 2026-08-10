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
import 'package:bookkeep_app/features/bills/bills_page.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';
import 'package:bookkeep_app/features/settings/appearance_page.dart';
import 'package:bookkeep_app/shared/theme/app_theme.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/widgets/app_amount_text.dart';
import 'package:bookkeep_app/shared/widgets/app_card.dart';

import '../helpers/fixtures.dart' show testBookId;
import '../widget/categories_page_test.dart' show testSeed;

/// Golden 测试（BK-UI-016）：8 主题 ×（账单主页/账单卡片/外观页）= 24 基线，
/// 容差 0.5%（Spec §9 Golden 层）。
///
/// 基线生成：flutter test --update-goldens test/golden/
/// 说明：flutter_test 默认 Ahem 字体（中文渲染为实心块），CI Linux 与本机
/// 同一 flutter 版本与运行时，渲染确定可跨环境比对（文档 §11 风险缓冲）。
void main() {
  setUpAll(() {
    // 0.5% 容差比较器（Spec §9），SDK 标准模式（goldens.dart 文档示例）
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.parse('test/golden/golden_ui_test.dart'),
      precisionTolerance: 0.005,
    );
  });

  Future<AppDatabase> seedBillsDb() async {
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
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: accountId,
          categoryId: Value(breakfastId),
          type: TransactionType.income,
          amountMinor: 10000,
          currency: 'CNY',
          occurredAt: DateTime(2026, 8, 9, 12, 0),
          updatedAt: DateTime.utc(2026, 8, 9),
        ));
    return db;
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
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> expectGolden(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  for (final preset in kThemePresetsV2) {
    group('${preset.id} ${preset.name}', () {
      testWidgets('账单主页', (tester) async {
        final db = await seedBillsDb();
        await pumpGolden(tester, preset, ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            currentBookIdProvider.overrideWith((ref) => testBookId),
            categorySeedProvider.overrideWith((ref) async => testSeed),
          ],
          child: const Scaffold(body: BillsPage()),
        ));
        await expectGolden(tester, '${preset.id}_bills');
      });

      testWidgets('账单卡片', (tester) async {
        await pumpGolden(tester, preset, Scaffold(
          body: Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 20, color: context.palette.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('餐饮 / 早餐',
                              style: context.text.titleLarge),
                        ),
                        AppAmountText.minor(-2550,
                            signed: false, tone: AppAmountTone.expense),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Row(
                      children: [
                        Icon(Icons.attach_money,
                            size: 20, color: context.palette.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('工资', style: context.text.titleLarge),
                        ),
                        AppAmountText.minor(10000,
                            signed: true, tone: AppAmountTone.income),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
        await expectGolden(tester, '${preset.id}_bill_card');
      });

      testWidgets('外观页', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await pumpGolden(tester, preset, ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            currentBookIdProvider.overrideWith((ref) => testBookId),
            categorySeedProvider.overrideWith((ref) async => testSeed),
          ],
          child: const AppearancePage(),
        ));
        await expectGolden(tester, '${preset.id}_appearance');
      });
    });
  }
}

/// 0.5% 容差 golden 比较器（Spec §9），SDK 官方示例模式
/// （flutter_test/lib/src/goldens.dart:139）。
class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  })  : assert(
          0 <= precisionTolerance && precisionTolerance <= 1,
          'precisionTolerance must be between 0 and 1',
        ),
        _precisionTolerance = precisionTolerance;

  /// 允许的像素差异占比（0=完全相同，1=完全不同的图）
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
