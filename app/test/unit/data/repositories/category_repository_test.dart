import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/core/errors/repository_exceptions.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/categories_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/local/tables/sync_ops_table.dart';
import 'package:bookkeep_app/data/repositories/category_repository.dart';
import 'package:bookkeep_app/domain/models/category_seed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late CategoryRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CategoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('bundled seed parses to 60+ categories with a version', () async {
    final raw = await rootBundle.loadString('assets/seed/categories_seed.json');
    final seed = CategorySeed.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(seed.version, 1);
    expect(seed.totalCount, greaterThanOrEqualTo(60));
    expect(seed.parents.where((c) => c.kind == CategoryKind.expense), isNotEmpty);
    expect(seed.parents.where((c) => c.kind == CategoryKind.income), isNotEmpty);
  });

  test('installing the seed creates system categories and records the version', () async {
    final raw = await rootBundle.loadString('assets/seed/categories_seed.json');
    final seed = CategorySeed.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    final inserted = await repo.installSeeds(seed);

    expect(inserted, seed.totalCount);
    expect(await repo.currentSeedVersion(), seed.version);
    final all = await repo.listCategories(includeDeleted: true);
    expect(all, hasLength(seed.totalCount));
    expect(all.where((c) => c.isSystem), hasLength(seed.totalCount));
  });

  test('installing the seed twice is idempotent', () async {
    final raw = await rootBundle.loadString('assets/seed/categories_seed.json');
    final seed = CategorySeed.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    await repo.installSeeds(seed);
    final inserted = await repo.installSeeds(seed);

    expect(inserted, 0);
    expect(await repo.listCategories(includeDeleted: true), hasLength(seed.totalCount));
  });

  test('creates a custom category and updates it', () async {
    final id = await repo.createCategory(
      name: '旅行',
      icon: 'hiking',
      color: 0xFF00FF00,
      kind: CategoryKind.expense,
    );
    await repo.updateCategory(id, name: '旅行度假', color: 0xFF0000FF, sortOrder: 9);

    final category = await repo.getCategory(id);
    expect(category.name, '旅行度假');
    expect(category.color, 0xFF0000FF);
    expect(category.sortOrder, 9);
    expect(category.isSystem, isFalse);
  });

  test('refuses to delete a category referenced by transactions', () async {
    final id = await repo.createCategory(
      name: '被引用',
      icon: 'tag',
      color: 0xFF000000,
      kind: CategoryKind.expense,
    );
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          accountType: AccountType.cash,
          name: 'A',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: accountId,
          categoryId: Value(id),
          type: TransactionType.expense,
          amountMinor: -100,
          currency: 'CNY',
          occurredAt: DateTime.utc(2026, 8, 1),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));

    expect(() => repo.deleteCategory(id), throwsA(isA<CategoryInUseException>()));
  });

  test('soft-deletes a category: hidden from lists but still resolvable', () async {
    final id = await repo.createCategory(
      name: '临时分类',
      icon: 'tag',
      color: 0xFF000000,
      kind: CategoryKind.expense,
    );

    await repo.deleteCategory(id);

    expect(await repo.listCategories(includeDeleted: false), isEmpty);
    final deleted = await repo.getCategory(id);
    expect(deleted.deletedAt, isNotNull);
    expect(await repo.listCategories(includeDeleted: true), hasLength(1));
  });

  test('installing the seed does not enqueue sync ops (seed 由各设备本地安装)', () async {
    final raw = await rootBundle.loadString('assets/seed/categories_seed.json');
    final seed = CategorySeed.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await repo.installSeeds(seed);

    expect(await db.select(db.syncOps).get(), isEmpty);
  });

  test('custom category create/update/delete enqueue ops', () async {
    final id = await repo.createCategory(name: '宠物', icon: 'pets', color: 0xFF333333, kind: CategoryKind.expense);
    await repo.updateCategory(id, name: '宠物用品');
    await repo.deleteCategory(id);

    final ops = await db.select(db.syncOps).get();
    expect(ops.map((o) => o.op).toList(), [SyncOpCode.c, SyncOpCode.u, SyncOpCode.d]);
    expect(ops.first.entityId, id);

    final createPayload = jsonDecode(ops[0].payload) as Map<String, dynamic>;
    expect(createPayload['name'], '宠物');
    expect(createPayload['is_system'], false);
    final updatePayload = jsonDecode(ops[1].payload) as Map<String, dynamic>;
    expect(updatePayload['name'], '宠物用品');
  });
}
