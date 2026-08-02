import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:bookkeep_app/core/constants/constants.dart';
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

// v3 schema = v1 + remote_id 列（v2→v3 迁移产物）+ 索引
const v3ColumnDdl = '''
ALTER TABLE accounts ADD COLUMN remote_id TEXT;
ALTER TABLE categories ADD COLUMN remote_id TEXT;
ALTER TABLE transactions ADD COLUMN remote_id TEXT;
ALTER TABLE budgets ADD COLUMN remote_id TEXT;
ALTER TABLE sync_ops ADD COLUMN remote_id TEXT;
CREATE INDEX idx_transactions_occurred_at ON transactions(occurred_at);
''';

// v4 schema 新增：books 表 + 业务表 book_id（默认 kDefaultBookId，v3→v4 迁移产物）
const v4ColumnDdl = '''
CREATE TABLE books (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'default',
  created_at INTEGER NOT NULL
);
ALTER TABLE accounts ADD COLUMN book_id TEXT NOT NULL DEFAULT '$kDefaultBookId';
ALTER TABLE categories ADD COLUMN book_id TEXT NOT NULL DEFAULT '$kDefaultBookId';
ALTER TABLE transactions ADD COLUMN book_id TEXT NOT NULL DEFAULT '$kDefaultBookId';
ALTER TABLE budgets ADD COLUMN book_id TEXT NOT NULL DEFAULT '$kDefaultBookId';
ALTER TABLE sync_ops ADD COLUMN book_id TEXT NOT NULL DEFAULT '$kDefaultBookId';
''';

// v5 schema 新增：周期规则 + 分期计划表（v4→v5 迁移产物）
const v5TableDdl = '''
CREATE TABLE recurring_rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id TEXT NOT NULL DEFAULT '$kDefaultBookId',
  frequency TEXT NOT NULL,
  interval INTEGER NOT NULL DEFAULT 1,
  anchor_type TEXT NOT NULL,
  anchor_day INTEGER NOT NULL DEFAULT 1,
  time_of_day INTEGER NOT NULL DEFAULT 540,
  amount_minor INTEGER NOT NULL,
  account_id INTEGER NOT NULL,
  category_id INTEGER,
  next_due INTEGER NOT NULL,
  start_date INTEGER NOT NULL,
  end_date INTEGER,
  updated_at INTEGER NOT NULL
);
CREATE TABLE installment_plans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id TEXT NOT NULL DEFAULT '$kDefaultBookId',
  name TEXT NOT NULL,
  total_minor INTEGER NOT NULL,
  periods INTEGER NOT NULL,
  start_date INTEGER NOT NULL,
  linked_account_id INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE TABLE installment_schedules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plan_id INTEGER NOT NULL,
  due_date INTEGER NOT NULL,
  amount_minor INTEGER NOT NULL,
  UNIQUE(plan_id, due_date)
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

  test('v3 database migrates to v6 backfilling book_id and creating the default book',
      () async {
    // 模拟真实 v3 库（v1 + remote_id 列 + 索引），带既有 sync_book_id
    final raw = sqlite.sqlite3.open(dbPath);
    raw.execute(v1Ddl);
    raw.execute(v3ColumnDdl);
    raw.execute('PRAGMA user_version = 3');
    raw.execute(
        "INSERT INTO accounts (account_type, name, currency, initial_balance, archived, created_at) "
        "VALUES ('cash', '旧账户', 'CNY', 500, 0, 1754064000)");
    raw.execute(
        "INSERT INTO transactions (account_id, category_id, type, amount_minor, currency, occurred_at, updated_at) "
        "VALUES (1, NULL, 'expense', -100, 'CNY', 1754064000, 1754064000)");
    raw.execute("INSERT INTO app_meta (key, value) VALUES ('sync_book_id', 'legacy-book-id')");
    raw.dispose();

    final db = AppDatabase(NativeDatabase(File(dbPath)));
    expect(db.schemaVersion, 6);

    // book_id 回填到既有 sync_book_id（同步域连续），而非 kDefaultBookId
    final account = await db.select(db.accounts).getSingle();
    expect(account.bookId, 'legacy-book-id');
    final tx = await db.select(db.transactions).getSingle();
    expect(tx.bookId, 'legacy-book-id');
    // 默认账本行与 current_book 元数据
    final book = await db.select(db.books).getSingle();
    expect(book.id, 'legacy-book-id');
    expect(book.name, '默认账本');
    expect(await db.currentBookId(), 'legacy-book-id');
    // 数据保留
    expect(account.name, '旧账户');
    expect(tx.amountMinor, -100);
    // v5/v6 表已建
    final tables = await db
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name IN "
            "('recurring_rules','installment_plans','installment_schedules','currencies')")
        .get();
    expect(tables, hasLength(4));
    await db.close();
  });

  test('v4 database migrates to v6 creating recurring and currency tables', () async {
    // 模拟真实 v4 库（v3 + books + book_id 列），无 sync_book_id 元数据
    final raw = sqlite.sqlite3.open(dbPath);
    raw.execute(v1Ddl);
    raw.execute(v3ColumnDdl);
    raw.execute(v4ColumnDdl);
    raw.execute('PRAGMA user_version = 4');
    raw.execute(
        "INSERT INTO accounts (account_type, name, currency, initial_balance, archived, created_at) "
        "VALUES ('cash', '旧账户', 'CNY', 500, 0, 1754064000)");
    // 真实 v4 库在 v3→v4 迁移时已插入默认账本行
    raw.execute(
        "INSERT INTO books (id, name, type, created_at) "
        "VALUES ('$kDefaultBookId', '默认账本', 'default', 1754064000)");
    raw.dispose();

    final db = AppDatabase(NativeDatabase(File(dbPath)));
    expect(db.schemaVersion, 6);

    // 无 sync_book_id → 默认账本 = kDefaultBookId，book_id 保持列默认值
    final account = await db.select(db.accounts).getSingle();
    expect(account.bookId, kDefaultBookId);
    final book = await db.select(db.books).getSingle();
    expect(book.id, kDefaultBookId);
    expect(account.name, '旧账户');
    // v5/v6 表已建
    final tables = await db
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name IN "
            "('recurring_rules','installment_plans','installment_schedules','currencies')")
        .get();
    expect(tables, hasLength(4));
    await db.close();
  });

  test('v5 database migrates to v6 preserving recurring rules', () async {
    // 模拟真实 v5 库（v4 + 周期/分期表），带既有周期规则
    final raw = sqlite.sqlite3.open(dbPath);
    raw.execute(v1Ddl);
    raw.execute(v3ColumnDdl);
    raw.execute(v4ColumnDdl);
    raw.execute(v5TableDdl);
    raw.execute('PRAGMA user_version = 5');
    raw.execute(
        "INSERT INTO accounts (account_type, name, currency, initial_balance, archived, created_at) "
        "VALUES ('cash', '旧账户', 'CNY', 500, 0, 1754064000)");
    raw.execute(
        "INSERT INTO recurring_rules (frequency, anchor_type, amount_minor, account_id, "
        "next_due, start_date, updated_at) "
        "VALUES ('month', 'start', 1000, 1, 1754064000, 1754064000, 1754064000)");
    raw.dispose();

    final db = AppDatabase(NativeDatabase(File(dbPath)));
    expect(db.schemaVersion, 6);

    // 既有数据保留（账户 + 周期规则）
    final account = await db.select(db.accounts).getSingle();
    expect(account.name, '旧账户');
    final rules = await db.select(db.recurringRules).get();
    expect(rules, hasLength(1));
    expect(rules.single.frequency, 'month');
    expect(rules.single.amountMinor, 1000);
    // v6 币种表已建
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table' AND name = 'currencies'")
        .get();
    expect(tables, hasLength(1));
    await db.close();
  });
}
