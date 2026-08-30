import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
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

import '../../../helpers/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late CategoryRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CategoryRepository(db, bookId: testBookId);
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

  test('seed versions are isolated per book: another book gets its own seeds', () async {
    final raw = await rootBundle.loadString('assets/seed/categories_seed.json');
    final seed = CategorySeed.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final bookA = CategoryRepository(db, bookId: 'book-A');
    final bookB = CategoryRepository(db, bookId: 'book-B');

    expect(await bookA.installSeeds(seed), seed.totalCount);
    // 回归：旧实现用全局 seed_version 守卫，账本 B 永远拿不到种子
    expect(await bookB.installSeeds(seed), seed.totalCount);
    // 各自幂等
    expect(await bookA.installSeeds(seed), 0);
    expect(await bookB.installSeeds(seed), 0);
    expect(await bookA.listCategories(), hasLength(seed.totalCount));
    expect(await bookB.listCategories(), hasLength(seed.totalCount));
  });

  test('legacy global seed_version migrates: book with system rows is treated as installed', () async {
    final raw = await rootBundle.loadString('assets/seed/categories_seed.json');
    final seed = CategorySeed.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    // 模拟 v0.2.0 存量数据：全局键 + 账本 X 已有系统分类行
    await db.into(db.appMeta).insert(AppMetaCompanion.insert(key: 'seed_version', value: '1'));
    final bookX = CategoryRepository(db, bookId: 'book-X');
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          bookId: 'book-X',
          remoteId: const Value('legacy-uuid'),
          name: '旧系统分类',
          icon: 'tag',
          color: 0xFF000000,
          kind: CategoryKind.expense,
          isSystem: const Value(true),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));

    expect(await bookX.installSeeds(seed), 0); // 不重复插入
    expect(await bookX.listCategories(includeDeleted: true), hasLength(1));
    // per-book 版本键已固化（后续判定不再依赖全局键）
    final meta = await (db.select(db.appMeta)
          ..where((t) => t.key.equals('seed_version_book-X')))
        .get();
    expect(meta.single.value, '1');
  });

  test('legacy global seed_version does not block a new book from getting seeds', () async {
    final raw = await rootBundle.loadString('assets/seed/categories_seed.json');
    final seed = CategorySeed.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await db.into(db.appMeta).insert(AppMetaCompanion.insert(key: 'seed_version', value: '1'));
    // 全局键存在但账本 Y 无系统分类行（旧用户切换过账本）→ 应补装
    final bookY = CategoryRepository(db, bookId: 'book-Y');

    expect(await bookY.installSeeds(seed), seed.totalCount);
    expect(await bookY.listCategories(), hasLength(seed.totalCount));
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

  test('creates a second-level category under a parent; icon persists and updates (BK-DOC-26 需求7)',
      () async {
    final parentId = await repo.createCategory(
      name: '娱乐',
      icon: 'movie',
      color: 0xFF7E57C2,
      kind: CategoryKind.expense,
    );
    final childId = await repo.createCategory(
      name: '电影',
      icon: 'movie',
      color: 0xFF7E57C2,
      kind: CategoryKind.expense,
      parentId: parentId,
    );

    final child = await repo.getCategory(childId);
    expect(child.parentId, parentId);
    expect(child.icon, 'movie');

    // 编辑图标（自定义图标在编辑态同样可改）
    await repo.updateCategory(childId, icon: 'sports_esports');
    expect((await repo.getCategory(childId)).icon, 'sports_esports');
    expect((await repo.getCategory(childId)).parentId, parentId);
  });

  test('refuses to delete a category referenced by transactions', () async {
    final id = await repo.createCategory(
      name: '被引用',
      icon: 'tag',
      color: 0xFF000000,
      kind: CategoryKind.expense,
    );
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: testBookId,
          accountType: AccountType.cash,
          name: 'A',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: testBookId,
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

  test('system categories can be renamed and soft-deleted (enqueue u/d ops)', () async {
    final raw = await rootBundle.loadString('assets/seed/categories_seed.json');
    final seed = CategorySeed.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await repo.installSeeds(seed);

    // 取一个叶子级系统分类（无子分类）
    final all = await repo.listCategories();
    final leaf = all.firstWhere((c) => c.isSystem && !all.any((x) => x.parentId == c.id));

    await repo.updateCategory(leaf.id, name: '改名分类', color: 0xFF00FF00);
    await repo.deleteCategory(leaf.id);

    expect(await repo.listCategories(), isNot(contains(predicate<Category>((c) => c.id == leaf.id))));
    final deleted = await repo.getCategory(leaf.id);
    expect(deleted.deletedAt, isNotNull);

    // 系统分类的改名/删除同样入队同步 op（多设备最终一致）
    final ops = await db.select(db.syncOps).get();
    expect(ops.map((o) => o.op).toList(), [SyncOpCode.u, SyncOpCode.d]);
    final updatePayload = jsonDecode(ops[0].payload) as Map<String, dynamic>;
    expect(updatePayload['is_system'], true);
    expect(updatePayload['name'], '改名分类');
  });

  test('refuses to delete a parent that still has active children', () async {
    final raw = await rootBundle.loadString('assets/seed/categories_seed.json');
    final seed = CategorySeed.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await repo.installSeeds(seed);

    final all = await repo.listCategories();
    final parent = all.firstWhere((c) => all.any((x) => x.parentId == c.id));

    // 子分类存在 → 拒绝删除父级（防止父删后子分类失联不可见）
    await expectLater(
      repo.deleteCategory(parent.id),
      throwsA(isA<CategoryHasChildrenException>()),
    );
    expect((await repo.getCategory(parent.id)).deletedAt, isNull);

    // 先逐个删除子分类，随后父级可正常删除
    for (final child in all.where((c) => c.parentId == parent.id).toList()) {
      await repo.deleteCategory(child.id);
    }
    await repo.deleteCategory(parent.id);
    expect((await repo.getCategory(parent.id)).deletedAt, isNotNull);
  });
}

