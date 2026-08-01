import 'package:drift/drift.dart';

import 'accounts_table.dart';

/// 账户余额日快照缓存（Spec §1.2 / BK-P0-002）
class AccountSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().named('account_id').references(Accounts, #id)();
  TextColumn get date => text()();
  IntColumn get balanceMinor => integer().named('balance_minor')();

  @override
  List<Set<Column>> get uniqueKeys => [
        {accountId, date},
      ];
}
