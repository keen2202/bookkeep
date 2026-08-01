import 'package:drift/drift.dart';

/// 分类收支类型
enum CategoryKind { expense, income }

/// 一二级分类（parent_id 自关联），is_system 标记 seed 分类（Spec §3.3）
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// 跨设备实体身份（uuid v4，同步域 entity_id）
  TextColumn get remoteId => text().named('remote_id').nullable()();
  IntColumn get parentId => integer().named('parent_id').nullable().references(Categories, #id)();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  TextColumn get kind => textEnum<CategoryKind>()();
  BoolColumn get isSystem => boolean().named('is_system').withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().named('sort_order').withDefault(const Constant(0))();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
}
