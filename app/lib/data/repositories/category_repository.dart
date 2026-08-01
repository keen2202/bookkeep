import 'package:drift/drift.dart';

import '../../core/errors/repository_exceptions.dart';
import '../../domain/models/category_seed.dart';
import '../local/database.dart';
import '../local/tables/categories_table.dart';
import '../local/tables/sync_ops_table.dart';
import 'op_logger.dart';

/// 分类仓库（Spec §3.3 / BK-P0-003）。
/// 系统 seed 分类由各设备本地按版本安装（不产生同步 op）；
/// 自定义分类的增删改经 OpLogger 入队。
class CategoryRepository {
  CategoryRepository(this.db, {OpLogger? opLogger}) : opLogger = opLogger ?? OpLogger(db);

  final AppDatabase db;
  final OpLogger opLogger;

  static const seedMetaKey = 'seed_version';

  /// 安装系统分类 seed（幂等：app_meta 记录版本，仅当版本更新时插入）
  Future<int> installSeeds(CategorySeed seed) async {
    final current = await currentSeedVersion();
    if (current >= seed.version) return 0;

    final now = DateTime.now().toUtc();
    var inserted = 0;
    await db.transaction(() async {
      for (final parent in seed.parents) {
        final parentId = await _insertNode(parent, null, now);
        inserted++;
        for (final child in parent.children) {
          await _insertNode(child, parentId, now);
          inserted++;
        }
      }
      await db.into(db.appMeta).insert(
            AppMetaCompanion.insert(key: seedMetaKey, value: '${seed.version}'),
            onConflict: DoUpdate((_) => AppMetaCompanion(value: Value('${seed.version}'))),
          );
    });
    return inserted;
  }

  Future<int> _insertNode(CategorySeedNode node, int? parentId, DateTime now) {
    return db.into(db.categories).insert(CategoriesCompanion.insert(
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
    final rows = await (db.select(db.appMeta)
          ..where((t) => t.key.equals(seedMetaKey)))
        .get();
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.single.value) ?? 0;
  }

  Future<List<Category>> listCategories({
    CategoryKind? kind,
    bool includeDeleted = false,
  }) {
    final q = db.select(db.categories)
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
    return db.transaction(() async {
      final now = DateTime.now().toUtc();
      final remoteId = opLogger.newUuid();
      final id = await db.into(db.categories).insert(CategoriesCompanion.insert(
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
