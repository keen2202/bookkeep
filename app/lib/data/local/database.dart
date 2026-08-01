import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/constants.dart';
import 'tables/account_snapshots_table.dart';
import 'tables/accounts_table.dart';
import 'tables/app_meta_table.dart';
import 'tables/budgets_table.dart';
import 'tables/categories_table.dart';
import 'tables/sync_ops_table.dart';
import 'tables/transactions_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  AppMeta,
  Accounts,
  AccountSnapshots,
  Categories,
  Transactions,
  Budgets,
  SyncOps,
])
class AppDatabase extends _$AppDatabase {
  /// 打开未加密数据库（单元测试 / Linux 桌面）。
  AppDatabase(super.e);

  /// 打开 SQLCipher 加密库：设备端由 sqlcipher_flutter_libs 提供实现，
  /// PRAGMA key 在打开后立即执行（Spec §1.3 / BK-P0-006）。
  factory AppDatabase.openEncrypted(String path, String key) {
    return AppDatabase(NativeDatabase(File(path), setup: (db) {
      db.execute("PRAGMA key = '$key'");
    }));
  }

  static const _uuid = Uuid();

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createIndex(idxTransactionsOccurredAt);
          }
          if (from < 3) {
            // v3：实体表与 sync_ops 增加 remote_id（uuid v4，跨设备身份）；
            // 既有行回填 uuid 以保持可同步（BK-T-007 评审 B1/H3 修复）
            await m.addColumn(accounts, accounts.remoteId);
            await m.addColumn(categories, categories.remoteId);
            await m.addColumn(transactions, transactions.remoteId);
            await m.addColumn(budgets, budgets.remoteId);
            await m.addColumn(syncOps, syncOps.remoteId);
            await _backfillRemoteIds();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _backfillRemoteIds() async {
    // 既有行回填 uuid 保持可同步；sync_ops 旧行无远端身份，引擎跳过（remote_id 为 null）
    for (final row in await (select(accounts)..where((t) => t.remoteId.isNull())).get()) {
      await (update(accounts)..where((t) => t.id.equals(row.id)))
          .write(AccountsCompanion(remoteId: Value(_uuid.v4())));
    }
    for (final row in await (select(categories)..where((t) => t.remoteId.isNull())).get()) {
      await (update(categories)..where((t) => t.id.equals(row.id)))
          .write(CategoriesCompanion(remoteId: Value(_uuid.v4())));
    }
    for (final row in await (select(transactions)..where((t) => t.remoteId.isNull())).get()) {
      await (update(transactions)..where((t) => t.id.equals(row.id)))
          .write(TransactionsCompanion(remoteId: Value(_uuid.v4())));
    }
    for (final row in await (select(budgets)..where((t) => t.remoteId.isNull())).get()) {
      await (update(budgets)..where((t) => t.id.equals(row.id)))
          .write(BudgetsCompanion(remoteId: Value(_uuid.v4())));
    }
  }

  Future<Account> getAccount(int id) async {
    final row = await (select(accounts)..where((t) => t.id.equals(id))).getSingle();
    return row;
  }
}
