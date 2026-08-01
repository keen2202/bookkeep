import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';

import '../../helpers/sqlite.dart';

// v1 DDL mirrored from the v1 schema, used to simulate an existing install
// before the v1 -> v2 example migration runs. Column storage follows drift's
// default mappings (text -> TEXT, int -> INTEGER, dateTime -> INTEGER unix, bool -> INTEGER).
const v1Ddl = '''
CREATE TABLE accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_type TEXT NOT NULL,
  name TEXT NOT NULL,
  currency TEXT NOT NULL,
  initial_balance INTEGER NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  parent_id INTEGER REFERENCES categories(id),
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  color INTEGER NOT NULL,
  kind TEXT NOT NULL,
  is_system INTEGER NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  deleted_at INTEGER,
  updated_at INTEGER NOT NULL
);
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL REFERENCES accounts(id),
  category_id INTEGER REFERENCES categories(id),
  type TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL,
  rate_snapshot INTEGER NOT NULL DEFAULT 1000000,
  note TEXT,
  occurred_at INTEGER NOT NULL,
  transfer_id INTEGER,
  auto_generated INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);
CREATE TABLE budgets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER REFERENCES categories(id),
  period TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  threshold INTEGER NOT NULL DEFAULT 80
);
CREATE TABLE sync_ops (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity TEXT NOT NULL,
  entity_id INTEGER NOT NULL,
  op TEXT NOT NULL,
  payload TEXT NOT NULL,
  lamport INTEGER NOT NULL,
  client_id TEXT NOT NULL,
  pushed INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
CREATE TABLE account_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL,
  date TEXT NOT NULL,
  balance_minor INTEGER NOT NULL,
  UNIQUE(account_id, date)
);
CREATE TABLE app_meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
''';

void main() {
  ensureSqliteLoaded();
  late Directory tmp;
  late String dbPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bk_migrations');
    dbPath = '${tmp.path}/test.db';
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  test('fresh open creates all v1 tables and supports insert/read roundtrip', () async {
    final db = AppDatabase(NativeDatabase(File(dbPath)));

    final accountId = await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          initialBalance: const Value(1000),
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final account = await db.getAccount(accountId);

    expect(account.name, '钱包');
    expect(account.initialBalance, 1000);
    await db.close();
  });

  test('v1 database migrates to v2 preserving existing rows and creating the index',
      () async {
    // Seed a v1 database the way a previous app version would have left it.
    final raw = sqlite.sqlite3.open(dbPath);
    raw.execute(v1Ddl);
    raw.execute('PRAGMA user_version = 1');
    raw.execute(
        "INSERT INTO accounts (account_type, name, currency, initial_balance, archived, created_at) "
        "VALUES ('cash', '旧账户', 'CNY', 500, 0, 1754064000)");
    raw.dispose();

    final db = AppDatabase(NativeDatabase(File(dbPath)));

    final accounts = await db.select(db.accounts).get();
    expect(accounts, hasLength(1));
    expect(accounts.single.name, '旧账户');
    expect(accounts.single.initialBalance, 500);

    final indexList = await db.customSelect('PRAGMA index_list(transactions)').get();
    expect(indexList.map((r) => r.data['name']), contains('idx_transactions_occurred_at'));

    await db.close();
  });

  test('reopening the migrated database reports the latest schema version', () async {
    final db1 = AppDatabase(NativeDatabase(File(dbPath)));
    await db1.close();

    final db2 = AppDatabase(NativeDatabase(File(dbPath)));
    expect(db2.schemaVersion, 6);
    await db2.close();
  });

  test('v2 database migrates to v3 adding remote_id columns and backfilling rows', () async {
    final raw = sqlite.sqlite3.open(dbPath);
    raw.execute(v1Ddl);
    raw.execute('PRAGMA user_version = 2');
    raw.execute(
        "INSERT INTO accounts (account_type, name, currency, initial_balance, archived, created_at) "
        "VALUES ('cash', '旧账户', 'CNY', 500, 0, 1754064000)");
    raw.execute(
        "INSERT INTO transactions (account_id, category_id, type, amount_minor, currency, occurred_at, updated_at) "
        "VALUES (1, NULL, 'expense', -100, 'CNY', 1754064000, 1754064000)");
    raw.execute(
        "INSERT INTO sync_ops (entity, entity_id, op, payload, lamport, client_id, pushed, created_at) "
        "VALUES ('transaction', 1, 'c', '{}', 1, 'legacy-client', 0, 1754064000)");
    raw.dispose();

    final db = AppDatabase(NativeDatabase(File(dbPath)));

    // 既有行回填 uuid 远端身份
    final account = await db.select(db.accounts).getSingle();
    expect(account.remoteId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    final tx = await db.select(db.transactions).getSingle();
    expect(tx.remoteId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    // sync_ops 旧行无法回填（remote_id 为 null，引擎跳过）
    final legacyOp = await db.select(db.syncOps).getSingle();
    expect(legacyOp.remoteId, isNull);

    // 数据保留
    expect(account.name, '旧账户');
    expect(tx.amountMinor, -100);
    await db.close();
  });
}
