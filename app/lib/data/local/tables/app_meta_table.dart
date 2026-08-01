import 'package:drift/drift.dart';

/// key/value 元数据（seed version、schema 信息等）
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
