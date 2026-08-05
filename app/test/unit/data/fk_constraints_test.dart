import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';

/// 回归测试：drift 2.34.5 codegen 开始为 5 个外键列生成 REFERENCES 约束，
/// 而 AppDatabase.beforeOpen 固定执行 PRAGMA foreign_keys = ON —— 新建库
/// （含本测试的内存库）首次真正强制外键（父行删除被 RESTRICT 拒绝），
/// 升级前的 v6 库无 REFERENCES 不约束。生产删除路径均为软删除（accounts
/// 归档 archived、transactions 置 deleted_at），天然规避 FK 拒绝。
void main() {
  late AppDatabase db;
  late int accountId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          remoteId: const Value('fk-test-account'),
          accountType: AccountType.cash,
          name: 'FK 回归账户',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: accountId,
          type: TransactionType.expense,
          amountMinor: -100,
          currency: 'CNY',
          occurredAt: DateTime.utc(2026, 8, 1, 12),
          updatedAt: DateTime.utc(2026, 8, 1, 12),
        ));
  });

  tearDown(() async {
    await db.close();
  });

  test('硬删除被流水引用的账户被外键 RESTRICT 拒绝', () async {
    // 新建库生成 REFERENCES accounts(id)，foreign_keys=ON → 子行存在时
    // DELETE 抛 SQLITE_CONSTRAINT_FOREIGNKEY（787），与升级前静默放行相反
    await expectLater(
      (db.delete(db.accounts)..where((t) => t.id.equals(accountId))).go(),
      throwsA(isA<sqlite.SqliteException>()),
    );

    // RESTRICT（非 CASCADE）：失败后父行与子行都原样保留
    expect(await db.select(db.accounts).get(), hasLength(1));
    expect(await db.select(db.transactions).get(), hasLength(1));
  });

  test('软删除（归档）账户不受外键约束影响，流水保持原样', () async {
    // 生产软删除 = 置 archived=true（AccountRepository.archiveAccount），
    // 不删行故不触发 FK；与 deleteAccount 的先查流水拒绝设计一致（Spec §3.2）
    await (db.update(db.accounts)..where((t) => t.id.equals(accountId)))
        .write(const AccountsCompanion(archived: Value(true)));

    final account =
        await (db.select(db.accounts)..where((t) => t.id.equals(accountId))).getSingle();
    expect(account.archived, isTrue);

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.single.accountId, accountId);
    expect(txs.single.amountMinor, -100);
    expect(txs.single.deletedAt, isNull);
  });
}
