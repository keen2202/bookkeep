import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/constants.dart';
import 'tables/account_snapshots_table.dart';
import 'tables/accounts_table.dart';
import 'tables/app_meta_table.dart';
import 'tables/books_table.dart';
import 'tables/budgets_table.dart';
import 'tables/categories_table.dart';
import 'tables/currencies_table.dart';
import 'tables/pending_replay_table.dart';
import 'tables/recurring_tables.dart';
import 'tables/sync_ops_table.dart';
import 'tables/transactions_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  AppMeta,
  Books,
  Currencies,
  Accounts,
  AccountSnapshots,
  Categories,
  Transactions,
  Budgets,
  SyncOps,
  RecurringRules,
  InstallmentPlans,
  InstallmentSchedules,
  PendingReplay,
])
class AppDatabase extends _$AppDatabase {
  /// 打开未加密数据库（单元测试 / Linux 桌面）。
  AppDatabase(super.e);

  static const _uuid = Uuid();
  static const _defaultBookName = '默认账本';

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // 新安装：默认账本 = 随机 uuid（与同步域一致；固定 id 会造成跨用户
          // 服务端账本串扰），books 行 + current_book_id + sync_book_id 三者一致
          final defaultId = _uuid.v4();
          await into(books).insert(
            BooksCompanion.insert(
              id: defaultId,
              name: _defaultBookName,
              type: const Value('default'),
              createdAt: DateTime.now().toUtc(),
            ),
          );
          await _setMeta(AppMetaKeys.currentBook, defaultId);
          await _setMeta(AppMetaKeys.syncBookId, defaultId);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createIndex(idxTransactionsOccurredAt);
          }
          if (from < 3) {
            // v3：实体表与 sync_ops 增加 remote_id（uuid v4，跨设备身份）
            await m.addColumn(accounts, accounts.remoteId);
            await m.addColumn(categories, categories.remoteId);
            await m.addColumn(transactions, transactions.remoteId);
            await m.addColumn(budgets, budgets.remoteId);
            await m.addColumn(syncOps, syncOps.remoteId);
          }
          if (from < 4) {
            // v4：books 表 + 业务表 book_id（Spec §4.1 / BK-T-010）。
            // 默认账本 = 既有 sync_book_id（保持同步域连续），老数据全部归默认账本。
            // 先加列再回填：生成的 select 映射器需要全部列存在。
            await m.createTable(books);
            final legacy = await _meta(AppMetaKeys.syncBookId);
            final defaultId = legacy ?? kDefaultBookId;
            if (legacy == null) {
              await _setMeta(AppMetaKeys.syncBookId, defaultId);
            }
            await into(books).insert(
              BooksCompanion.insert(
                id: defaultId,
                name: _defaultBookName,
                type: const Value('default'),
                createdAt: DateTime.now().toUtc(),
              ),
              onConflict: DoNothing(),
            );
            await m.addColumn(accounts, accounts.bookId);
            await m.addColumn(categories, categories.bookId);
            await m.addColumn(transactions, transactions.bookId);
            await m.addColumn(budgets, budgets.bookId);
            await m.addColumn(syncOps, syncOps.bookId);
            // 既有行回填默认账本（列默认值 kDefaultBookId → 更新为真实默认账本 id）
            await customStatement(
              "UPDATE accounts SET book_id = '$defaultId' WHERE book_id = '$kDefaultBookId'",
            );
            await customStatement(
              "UPDATE categories SET book_id = '$defaultId' WHERE book_id = '$kDefaultBookId'",
            );
            await customStatement(
              "UPDATE transactions SET book_id = '$defaultId' WHERE book_id = '$kDefaultBookId'",
            );
            await customStatement(
              "UPDATE budgets SET book_id = '$defaultId' WHERE book_id = '$kDefaultBookId'",
            );
            await customStatement(
              "UPDATE sync_ops SET book_id = '$defaultId' WHERE book_id = '$kDefaultBookId'",
            );
            await _setMeta(AppMetaKeys.currentBook, defaultId);
          }
          if (from < 5) {
            // v5：周期规则 + 分期计划表（Spec §4.4 / BK-T-013）
            await m.createTable(recurringRules);
            await m.createTable(installmentPlans);
            await m.createTable(installmentSchedules);
          }
          if (from < 6) {
            // v6：币种表（Spec §4.5 / BK-T-014）；seed 由 CurrencyRepository 安装
            await m.createTable(currencies);
          }
          if (from < 7) {
            // v7：FK 未就绪 op 重放队列（审查 F-6 / BK-R-009）
            await m.createTable(pendingReplay);
            // v7：周期规则收支类型（审查 F-7 / BK-R-014）。
            // 表定义已含 type 列：从 v1~v4 升级时 v5 步骤按新定义建表，此处须先探测避免重复添加
            final ruleCols =
                await customSelect("PRAGMA table_info('recurring_rules')").get();
            final hasType = ruleCols.any((c) => c.read<String>('name') == 'type');
            if (!hasType) {
              await m.addColumn(recurringRules, recurringRules.type);
            }
          }
          // v3 回填放最后：需全部列（含 v4 book_id）已存在（迁移链 v1/v2 → v4）
          if (from < 3) {
            await _backfillRemoteIds();
          }
        },
        beforeOpen: (details) async {
          // FK 约束（REFERENCES）由 drift 2.34.5 codegen 生成，仅对新建库生效（既有 v6 库无 REFERENCES 不约束）；删除父行在有子行时会被 RESTRICT 拒绝
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<String?> _meta(String key) async {
    final rows = await (select(appMeta)..where((t) => t.key.equals(key))).get();
    return rows.isEmpty ? null : rows.single.value;
  }

  Future<void> _setMeta(String key, String value) async {
    await into(appMeta).insert(
      AppMetaCompanion.insert(key: key, value: value),
      onConflict: DoUpdate((_) => AppMetaCompanion(value: Value(value))),
    );
  }

  /// 当前账本 id（app_meta current_book_id；缺失时回退默认分区）
  Future<String> currentBookId() async =>
      await _meta(AppMetaKeys.currentBook) ?? kDefaultBookId;

  Future<void> setCurrentBookId(String bookId) => _setMeta(AppMetaKeys.currentBook, bookId);

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
