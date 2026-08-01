import 'package:drift/drift.dart';

/// 账户类型（01-开发建议 BK-P0-002 枚举化）
enum AccountType { cash, savings, credit, storedValue, eWallet, liability }

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// 跨设备实体身份（uuid v4，同步域 entity_id；本地创建时生成，合并时沿用远端值）
  TextColumn get remoteId => text().named('remote_id').nullable()();
  TextColumn get accountType => textEnum<AccountType>().named('account_type')();
  TextColumn get name => text()();
  TextColumn get currency => text()();
  IntColumn get initialBalance => integer().named('initial_balance').withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
}
