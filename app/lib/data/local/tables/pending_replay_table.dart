import 'package:drift/drift.dart';

/// FK 未就绪暂存的重放队列（审查 F-6）：transaction 的 account/category
/// 依赖 op 晚到时，create 暂存于此；依赖实体合并落库后触发重放，
/// 成功即删，避免"跳过即永久丢失"。op 以 wire 格式（JSON 字符串）存储。
class PendingReplay extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get entityId => text().named('entity_id')();
  TextColumn get op => text()();
  TextColumn get payload => text()();
  TextColumn get bookId => text().named('book_id')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  List<Set<Column>> get uniqueKeys => [
        {bookId, entityId},
      ];
}
