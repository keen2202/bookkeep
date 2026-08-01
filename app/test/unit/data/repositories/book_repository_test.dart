import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:bookkeep_app/core/constants/constants.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/account_repository.dart';
import 'package:bookkeep_app/data/repositories/book_repository.dart';
import 'package:bookkeep_app/data/repositories/op_logger.dart';
import 'package:bookkeep_app/data/repositories/transaction_repository.dart';

import '../../../helpers/sqlite.dart';

const bookA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const bookB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

void main() {
  ensureSqliteLoaded();
  late AppDatabase db;
  late BookRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = BookRepository(db);
  });

  tearDown(() => db.close());

  group('BookRepository（Spec §4.1 / BK-T-010）', () {
    test('新库自动种子默认账本，currentBook 可用', () async {
      final id = await repo.currentBookId();
      expect(id, isNot(kDefaultBookId));
      final book = await repo.currentBook();
      expect(book, isNotNull);
      expect(book!.name, '默认账本');
    });

    test('创建/列表/切换账本', () async {
      await repo.createLocalBook(id: bookA, name: '生活账本', type: 'life');
      await repo.createLocalBook(id: bookB, name: '生意账本', type: 'business');
      final books = await repo.listBooks();
      expect(books.map((b) => b.id), containsAll([bookA, bookB]));

      await repo.switchBook(bookB);
      expect(await repo.currentBookId(), bookB);
      expect((await repo.currentBook())!.name, '生意账本');
    });

    test('账本间数据完全隔离（账户/流水/op 队列）', () async {
      await repo.createLocalBook(id: bookA, name: 'A');
      await repo.createLocalBook(id: bookB, name: 'B');

      final repoA = AccountRepository(db, bookId: bookA);
      await repoA.createAccount(name: 'A钱包', type: AccountType.cash);
      final repoB = AccountRepository(db, bookId: bookB);
      await repoB.createAccount(name: 'B钱包', type: AccountType.cash);

      // 列表隔离
      final accountsA = await repoA.listAccounts();
      final accountsB = await repoB.listAccounts();
      expect(accountsA.single.name, 'A钱包');
      expect(accountsB.single.name, 'B钱包');

      // op 队列按账本分区
      final opsA = await OpLogger(db).pendingOps(bookId: bookA);
      final opsB = await OpLogger(db).pendingOps(bookId: bookB);
      expect(opsA, hasLength(1));
      expect(opsB, hasLength(1));
      expect(opsA.single.bookId, bookA);
      expect(opsB.single.bookId, bookB);
    });

    test('流水归属当前账本，跨账本不可见', () async {
      await repo.createLocalBook(id: bookA, name: 'A');
      await repo.createLocalBook(id: bookB, name: 'B');
      final txRepoA = TransactionRepository(db, bookId: bookA);
      final accountId = await AccountRepository(db, bookId: bookA)
          .createAccount(name: '钱包', type: AccountType.cash);
      await txRepoA.createTransaction(
        accountId: accountId,
        type: TransactionType.expense,
        amountMinor: -100,
        occurredAt: DateTime.utc(2026, 8, 1),
      );

      final txsA = await txRepoA.listTransactions();
      final txsB = await TransactionRepository(db, bookId: bookB).listTransactions();
      expect(txsA, hasLength(1));
      expect(txsB, isEmpty);
    });
  });

  group('v4 迁移（老数据归默认账本）', () {
    const v3Ddl = '''
CREATE TABLE accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id TEXT,
  account_type TEXT NOT NULL,
  name TEXT NOT NULL,
  currency TEXT NOT NULL,
  initial_balance INTEGER NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id TEXT,
  parent_id INTEGER,
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
  remote_id TEXT,
  account_id INTEGER NOT NULL,
  category_id INTEGER,
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
  remote_id TEXT,
  category_id INTEGER,
  period TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  threshold INTEGER NOT NULL DEFAULT 80
);
CREATE TABLE sync_ops (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remote_id TEXT,
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

    test('v3 数据库升级到 v4：books 表创建、既有数据归默认账本、当前账本生效', () async {
      final dir = Directory.systemTemp.createTempSync('bk_mig_v4');
      final dbPath = '${dir.path}/test.db';
      addTearDown(() => dir.deleteSync(recursive: true));

      const legacyBookId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
      final raw = sqlite.sqlite3.open(dbPath);
      raw.execute(v3Ddl);
      raw.execute('PRAGMA user_version = 3');
      raw.execute(
          "INSERT INTO app_meta (key, value) VALUES ('sync_book_id', '$legacyBookId')");
      raw.execute(
          "INSERT INTO accounts (account_type, name, currency, initial_balance, archived, created_at) "
          "VALUES ('cash', '旧账户', 'CNY', 500, 0, 1754064000)");
      raw.execute(
          "INSERT INTO sync_ops (entity, entity_id, op, payload, lamport, client_id, pushed, created_at) "
          "VALUES ('account', 1, 'c', '{}', 1, 'legacy', 0, 1754064000)");
      raw.dispose();

      final migrated = AppDatabase(NativeDatabase(File(dbPath)));
      expect(migrated.schemaVersion, 6);

      // 老数据归默认账本（保留 legacy sync_book_id 作为默认账本 id）
      final account = await migrated.select(migrated.accounts).getSingle();
      expect(account.bookId, legacyBookId);
      final op = await migrated.select(migrated.syncOps).getSingle();
      expect(op.bookId, legacyBookId);
      expect(await migrated.currentBookId(), legacyBookId);

      // books 表有默认账本行
      final book = await (migrated.select(migrated.books)).getSingle();
      expect(book.id, legacyBookId);
      await migrated.close();
    });

    test('v4 后旧账本数据经仓库可见（默认账本 = legacy id）', () async {
      final dir = Directory.systemTemp.createTempSync('bk_mig_v4b');
      final dbPath = '${dir.path}/test.db';
      addTearDown(() => dir.deleteSync(recursive: true));

      const legacyBookId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
      final raw = sqlite.sqlite3.open(dbPath);
      raw.execute(v3Ddl);
      raw.execute('PRAGMA user_version = 3');
      raw.execute("INSERT INTO app_meta (key, value) VALUES ('sync_book_id', '$legacyBookId')");
      raw.execute(
          "INSERT INTO accounts (account_type, name, currency, initial_balance, archived, created_at) "
          "VALUES ('cash', '旧账户', 'CNY', 500, 0, 1754064000)");
      raw.dispose();

      final migrated = AppDatabase(NativeDatabase(File(dbPath)));
      final bookRepo = BookRepository(migrated);
      // 显式传入 legacy 默认账本 → 老数据可见
      final repo = AccountRepository(migrated, bookId: legacyBookId);
      final accounts = await repo.listAccounts();
      expect(accounts.single.name, '旧账户');
      expect(await bookRepo.currentBookId(), legacyBookId);
      await migrated.close();
    });
  });
}
