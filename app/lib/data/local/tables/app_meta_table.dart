import 'package:drift/drift.dart';

/// key/value 元数据（seed version、schema 信息等）
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// app_meta 键约定（同步/账本/设置共用，BK-T-007 / BK-T-010）
abstract final class AppMetaKeys {
  static const syncBookId = 'sync_book_id';
  static const clientId = 'client_id';
  static const maxRemoteLamport = 'sync_max_remote_lamport';
  static const currentBook = 'current_book_id';
  static String lastSyncedSeq(String bookId) => 'sync_last_seq_$bookId';
}
