import 'package:drift/drift.dart';

import '../../core/constants/constants.dart';
import '../../core/errors/repository_exceptions.dart';
import '../../domain/models/category_seed.dart';
import '../local/database.dart';
import '../local/tables/categories_table.dart';
import '../local/tables/sync_ops_table.dart';
import 'op_logger.dart';

/// 分类仓库（Spec §3.3 / BK-P0-003）。
/// 系统 seed 分类由各设备本地按版本安装（不产生同步 op）；
/// 自定义分类的增删改经 OpLogger 入队；查询/写入按账本过滤（Spec §4.1 / BK-T-010）。
class CategoryRepository {
  CategoryRepository(this.db, {OpLogger? opLogger, this.bookId})
      : opLogger = opLogger ?? OpLogger(db);

  final AppDatabase db;
  final OpLogger opLogger;
  final String? bookId;

  /// 种子版本按账本隔离的 meta 键（参照 sync_last_seq_$bookId 先例）；
  /// 旧版本（v0.2.0 及更早）写入的是全局键 [legacySeedMetaKey]。
  static String _seedKey(String bookId) => 'seed_version_$bookId';

  /// 旧版本的全局种子版本键，仅用于存量数据迁移回退
  static const legacySeedMetaKey = 'seed_version';

  Future<String> _bookId() async => bookId ?? kDefaultBookId;

  /// 安装系统分类 seed（幂等：app_meta 记录各账本版本，仅当版本更新时插入）。
  /// seed 分类归属当前账本（各账本独立分类体系）。
  Future<int> installSeeds(CategorySeed seed) async {
    final currentBookId = await _bookId();
    var current = await currentSeedVersion();

    // 存量迁移回退：旧版本种子版本是全局键。若当前账本已有系统分类行且全局版本
    // 达标，视为已安装，并把版本固化到 per-book 键（此后判定不再依赖全局键）。
    if (current == 0) {
      final global = await _metaInt(legacySeedMetaKey);
      if (global >= seed.version && await _hasSystemCategories(currentBookId)) {
        current = global;
        await db.into(db.appMeta).insert(
              AppMetaCompanion.insert(key: _seedKey(currentBookId), value: '$global'),
              onConflict: DoUpdate((_) => AppMetaCompanion(value: Value('$global'))),
            );
      }
    }
    if (current >= seed.version) return 0;

    final now = DateTime.now().toUtc();
    var inserted = 0;
    await db.transaction(() async {
      for (final parent in seed.parents) {
        final parentId = await _insertNode(parent, null, now, currentBookId);
        inserted++;
        for (final child in parent.children) {
          await _insertNode(child, parentId, now, currentBookId);
          inserted++;
        }
      }
      await db.into(db.appMeta).insert(
            AppMetaCompanion.insert(key: _seedKey(currentBookId), value: '${seed.version}'),
            onConflict: DoUpdate((_) => AppMetaCompanion(value: Value('${seed.version}'))),
          );
    });
    return inserted;
  }

  Future<int> _insertNode(CategorySeedNode node, int? parentId, DateTime now, String bookId) {
    return db.into(db.categories).insert(CategoriesCompanion.insert(
          bookId: Value(bookId),
          remoteId: Value(opLogger.newUuid()),
          parentId: Value(parentId),
          name: node.name,
          icon: node.icon,
          color: node.color,
          kind: node.kind,
          isSystem: const Value(true),
          sortOrder: const Value(0),
          updatedAt: now,
        ));
  }

  Future<int> currentSeedVersion() async {
    return _metaInt(_seedKey(await _bookId()));
  }

  Future<int> _metaInt(String key) async {
    final rows = await (db.select(db.appMeta)..where((t) => t.key.equals(key))).get();
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.single.value) ?? 0;
  }

  /// 账本是否已存在系统分类（软删行也计入：曾安装过即视为已安装）
  Future<bool> _hasSystemCategories(String bookId) async {
    final rows = await (db.select(db.categories)
          ..where((t) => t.bookId.equals(bookId) & t.isSystem.equals(true))
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  Future<List<Category>> listCategories({
    CategoryKind? kind,
    bool includeDeleted = false,
  }) async {
    final currentBookId = await _bookId();
    final q = db.select(db.categories)
      ..where((t) => t.bookId.equals(currentBookId))
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.id),
      ]);
    if (kind != null) q.where((t) => t.kind.equals(kind.name));
    if (!includeDeleted) q.where((t) => t.deletedAt.isNull());
    return q.get();
  }

  Future<Category> getCategory(int id) async {
    return (db.select(db.categories)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<int> createCategory({
    required String name,
    required String icon,
    required int color,
    required CategoryKind kind,
    int? parentId,
  }) async {
    final currentBookId = await _bookId();
    return db.transaction(() async {
      final now = DateTime.now().toUtc();
      final remoteId = opLogger.newUuid();
      final id = await db.into(db.categories).insert(CategoriesCompanion.insert(
            bookId: Value(currentBookId),
            remoteId: Value(remoteId),
            parentId: Value(parentId),
            name: name,
            icon: icon,
            color: color,
            kind: kind,
            isSystem: const Value(false),
            updatedAt: now,
          ));
      await opLogger.enqueue(
        entity: 'category',
        entityId: id,
        remoteId: remoteId,
        op: SyncOpCode.c,
        bookId: currentBookId,
        payload: {
          'id': id,
          'parent_id': parentId == null ? null : await _remoteIdOf(parentId),
          'name': name,
          'icon': icon,
          'color': color,
          'kind': kind.name,
          'is_system': false,
          'sort_order': 0,
          'updated_at': now.toIso8601String(),
        },
      );
      return id;
    });
  }

  Future<void> updateCategory(
    int id, {
    String? name,
    String? icon,
    int? color,
    int? sortOrder,
  }) async {
    await db.transaction(() async {
      await (db.update(db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          icon: icon != null ? Value(icon) : const Value.absent(),
          color: color != null ? Value(color) : const Value.absent(),
          sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await _enqueueSnapshot(id, SyncOpCode.u);
    });
  }

  /// 软删除。仍被流水引用时拒绝（Spec §3.3：删除被引用分类需提示）。
  Future<void> deleteCategory(int id) async {
    final referenced = await (db.select(db.transactions)
          ..where((t) => t.categoryId.equals(id) & t.deletedAt.isNull()))
        .get()
        .then((rows) => rows.isNotEmpty);
    if (referenced) {
      throw CategoryInUseException();
    }
    await db.transaction(() async {
      final category = await getCategory(id);
      await (db.update(db.categories)..where((t) => t.id.equals(id)))
          .write(CategoriesCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
      await opLogger.enqueue(
        entity: 'category',
        entityId: id,
        remoteId: category.remoteId!,
        op: SyncOpCode.d,
        bookId: await _bookId(),
      );
    });
  }

  Future<String?> _remoteIdOf(int categoryId) async {
    final row = await (db.select(db.categories)..where((t) => t.id.equals(categoryId))).getSingle();
    return row.remoteId;
  }

  Future<void> _enqueueSnapshot(int id, SyncOpCode op) async {
    final category = await getCategory(id);
    await opLogger.enqueue(
      entity: 'category',
      entityId: id,
      remoteId: category.remoteId!,
      op: op,
      bookId: await _bookId(),
      payload: {
        'id': id,
        'parent_id': category.parentId == null ? null : await _remoteIdOf(category.parentId!),
        'name': category.name,
        'icon': category.icon,
        'color': category.color,
        'kind': category.kind.name,
        'is_system': category.isSystem,
        'sort_order': category.sortOrder,
        'updated_at': category.updatedAt.toUtc().toIso8601String(),
      },
    );
  }
}
