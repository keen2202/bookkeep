import 'package:drift/drift.dart';

import 'categories_table.dart';

/// 预算：category_id 为 null 表示总预算；period 为周期窗口起始日 'YYYY-MM-DD'（Spec §3.4）
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// 跨设备实体身份（uuid v4，同步域 entity_id）
  TextColumn get remoteId => text().named('remote_id').nullable()();
  IntColumn get categoryId => integer().named('category_id').nullable().references(Categories, #id)();
  TextColumn get period => text()();
  IntColumn get amountMinor => integer().named('amount_minor')();
  IntColumn get threshold => integer().withDefault(const Constant(80))();
}
