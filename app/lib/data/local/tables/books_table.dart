import 'package:drift/drift.dart';

/// 账本（Spec §4.1 / BK-P1-001）：本地缓存的账本列表，服务端为成员/权限权威
class Books extends Table {
  /// 与同步域一致的账本 id（uuid v4）
  TextColumn get id => text()();
  TextColumn get name => text()();
  /// 场景模板：default / life / family / travel / business
  TextColumn get type => text().withDefault(const Constant('default'))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}
