import 'package:drift/drift.dart';

import '../../../core/constants/constants.dart';

enum SyncOpCode { c, u, d }

/// 同步操作日志（op-log 模型，Spec §1.3 / BK-P0-006）；按账本分区（Spec §4.1）
class SyncOps extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// 账本分区（Spec §4.1 / BK-T-010）
  TextColumn get bookId => text().named('book_id').withDefault(const Constant(kDefaultBookId))();
  TextColumn get entity => text()();
  IntColumn get entityId => integer().named('entity_id')();
  /// 实体跨设备身份（uuid v4），即 OpenAPI entity_id（本地实体 remote_id 列）。
  /// 可空：v3 迁移前遗留的旧 op 无远端身份，引擎跳过。
  TextColumn get remoteId => text().named('remote_id').nullable()();
  TextColumn get op => textEnum<SyncOpCode>()();
  TextColumn get payload => text()();
  IntColumn get lamport => integer()();
  TextColumn get clientId => text().named('client_id')();
  BoolColumn get pushed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
}
