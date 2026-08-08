import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/core/ledger_version.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/budget_repository.dart';
import 'package:bookkeep_app/data/repositories/category_repository.dart';
import 'package:bookkeep_app/features/books/books_providers.dart';
import 'package:bookkeep_app/features/budgets/budget_providers.dart';
import 'package:bookkeep_app/features/categories/categories_page.dart';

import '../helpers/fixtures.dart';
import 'categories_page_test.dart' show testSeed;

/// 记账页顶部「本月预算」摘要 provider（预算整合进记账页的数据层）
void main() {
  ProviderContainer container(AppDatabase db) {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      currentBookIdProvider.overrideWith((ref) => testBookId),
      categorySeedProvider.overrideWith((ref) async => testSeed),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<BudgetSummary?> summary(ProviderContainer c) =>
      c.read(monthBudgetSummaryProvider.future);

  test('无预算 → null（提示卡）', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await summary(container(db)), isNull);
  });

  test('仅分类预算 → null（卡片只看总预算）', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catRepo = CategoryRepository(db, bookId: testBookId);
    await catRepo.installSeeds(testSeed);
    final cat = (await catRepo.listCategories()).first;
    await BudgetRepository(db, bookId: testBookId)
        .createBudget(categoryId: cat.id, period: '2026-08-01', amountMinor: 10000);

    expect(await summary(container(db)), isNull);
  });

  test('总预算存在 → 返回摘要（含当月支出）', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await BudgetRepository(db, bookId: testBookId)
        .createBudget(categoryId: null, period: '2026-08-01', amountMinor: 100000);
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final now = DateTime.now();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: accountId,
          type: TransactionType.expense,
          amountMinor: -30000,
          currency: 'CNY',
          occurredAt: DateTime(now.year, now.month, 15, 12),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));

    final s = await summary(container(db));

    expect(s, isNotNull);
    expect(s!.budget.amountMinor, 100000);
    expect(s.progress.spentMinor, 30000);
    expect(s.progress.remainingMinor, 70000);
    expect(s.progress.percent, 30);
  });

  test('记账保存 bump 刷新总线后自动重算', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await BudgetRepository(db, bookId: testBookId)
        .createBudget(categoryId: null, period: '2026-08-01', amountMinor: 100000);
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final c = container(db);
    expect((await summary(c))!.progress.spentMinor, 0);

    final now = DateTime.now();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
          accountId: accountId,
          type: TransactionType.expense,
          amountMinor: -2550,
          currency: 'CNY',
          occurredAt: DateTime(now.year, now.month, 15, 12),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
    c.read(ledgerVersionProvider.notifier).state++;

    expect((await summary(c))!.progress.spentMinor, 2550);
  });
}
