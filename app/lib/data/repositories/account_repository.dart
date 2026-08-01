import 'package:drift/drift.dart';

import '../../core/errors/repository_exceptions.dart';
import '../local/database.dart';
import '../local/tables/accounts_table.dart';
import '../local/tables/sync_ops_table.dart';
import '../local/tables/transactions_table.dart';
import 'op_logger.dart';

/// 账户仓库（Spec §3.2 / BK-P0-002）：写路径统一经 OpLogger 入队
class AccountRepository {
  AccountRepository(this.db, {OpLogger? opLogger}) : opLogger = opLogger ?? OpLogger(db);

  final AppDatabase db;
  final OpLogger opLogger;

  Future<int> createAccount({
    required String name,
    required AccountType type,
    String currency = 'CNY',
    int initialBalance = 0,
  }) async {
    return db.transaction(() async {
      final now = DateTime.now().toUtc();
      final remoteId = opLogger.newUuid();
      final id = await db.into(db.accounts).insert(AccountsCompanion.insert(
            remoteId: Value(remoteId),
            accountType: type,
            name: name,
            currency: currency,
            initialBalance: Value(initialBalance),
            createdAt: now,
          ));
      await opLogger.enqueue(
        entity: 'account',
        entityId: id,
        remoteId: remoteId,
        op: SyncOpCode.c,
        payload: {
          'id': id,
          'type': type.name,
          'name': name,
          'currency': currency,
          'initial_balance': initialBalance,
          'archived': false,
          'created_at': now.toIso8601String(),
        },
      );
      return id;
    });
  }

  Future<Account> getAccount(int id) async {
    return (db.select(db.accounts)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<List<Account>> listAccounts({bool includeArchived = false}) {
    final q = db.select(db.accounts)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (!includeArchived) {
      q.where((t) => t.archived.equals(false));
    }
    return q.get();
  }

  Future<void> updateAccount(
    int id, {
    String? name,
    AccountType? type,
    String? currency,
    int? initialBalance,
  }) async {
    await db.transaction(() async {
      await (db.update(db.accounts)..where((t) => t.id.equals(id))).write(
        AccountsCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          accountType: type != null ? Value(type) : const Value.absent(),
          currency: currency != null ? Value(currency) : const Value.absent(),
          initialBalance:
              initialBalance != null ? Value(initialBalance) : const Value.absent(),
        ),
      );
      await _enqueueSnapshot(id, SyncOpCode.u);
    });
  }

  Future<void> archiveAccount(int id) async {
    await db.transaction(() async {
      await (db.update(db.accounts)..where((t) => t.id.equals(id)))
          .write(const AccountsCompanion(archived: Value(true)));
      await _enqueueSnapshot(id, SyncOpCode.u);
    });
  }

  /// 删除 = 软删除（归档）。仍有关联流水时拒绝（Spec §3.2）。
  Future<void> deleteAccount(int id) async {
    final hasTx = await (db.select(db.transactions)
          ..where((t) => t.accountId.equals(id) & t.deletedAt.isNull()))
        .get()
        .then((rows) => rows.isNotEmpty);
    if (hasTx) {
      throw AccountInUseException();
    }
    await archiveAccount(id);
  }

  /// 转账 = 同一事务两条流水 + transfer_id 关联（Spec §3.2 / BK-P0-002）
  Future<int> createTransfer({
    required int fromAccountId,
    required int toAccountId,
    required int amountMinor,
    required DateTime occurredAt,
  }) async {
    return db.transaction(() async {
      final now = DateTime.now().toUtc();
      final fromRemoteId = opLogger.newUuid();
      final pairedRemoteId = opLogger.newUuid();
      final fromId = await db.into(db.transactions).insert(TransactionsCompanion.insert(
            remoteId: Value(fromRemoteId),
            accountId: fromAccountId,
            type: TransactionType.transfer,
            amountMinor: -amountMinor,
            currency: 'CNY',
            occurredAt: occurredAt,
            updatedAt: now,
          ));
      final pairedId = await db.into(db.transactions).insert(TransactionsCompanion.insert(
            remoteId: Value(pairedRemoteId),
            accountId: toAccountId,
            type: TransactionType.transfer,
            amountMinor: amountMinor,
            currency: 'CNY',
            occurredAt: occurredAt,
            transferId: Value(fromId),
            updatedAt: now,
          ));
      // 双向关联：首条流水也回写 transfer_id，保证配对对称
      await (db.update(db.transactions)..where((t) => t.id.equals(fromId)))
          .write(TransactionsCompanion(transferId: Value(fromId)));

      final fromAccountRef = await _remoteIdOf(fromAccountId);
      final toAccountRef = await _remoteIdOf(toAccountId);
      await opLogger.enqueue(
        entity: 'transaction',
        entityId: fromId,
        remoteId: fromRemoteId,
        op: SyncOpCode.c,
        payload: {
          'id': fromId,
          'account_id': fromAccountRef,
          'transfer_id': fromRemoteId,
          'type': 'transfer',
          'amount_minor': -amountMinor,
          'currency': 'CNY',
          'occurred_at': occurredAt.toUtc().toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
      );
      await opLogger.enqueue(
        entity: 'transaction',
        entityId: pairedId,
        remoteId: pairedRemoteId,
        op: SyncOpCode.c,
        payload: {
          'id': pairedId,
          'account_id': toAccountRef,
          'transfer_id': fromRemoteId,
          'type': 'transfer',
          'amount_minor': amountMinor,
          'currency': 'CNY',
          'occurred_at': occurredAt.toUtc().toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
      );
      return fromId;
    });
  }

  Future<String?> _remoteIdOf(int accountId) async {
    final row = await (db.select(db.accounts)..where((t) => t.id.equals(accountId))).getSingle();
    return row.remoteId;
  }

  Future<void> _enqueueSnapshot(int id, SyncOpCode op) async {
    final account = await getAccount(id);
    await opLogger.enqueue(
      entity: 'account',
      entityId: id,
      remoteId: account.remoteId!,
      op: op,
      payload: {
        'id': id,
        'type': account.accountType.name,
        'name': account.name,
        'currency': account.currency,
        'initial_balance': account.initialBalance,
        'archived': account.archived,
        'created_at': account.createdAt.toUtc().toIso8601String(),
      },
    );
  }

  /// 按日刷新账户快照缓存（余额 = initial + Σ流水，SQL 聚合）
  Future<void> refreshSnapshots(DateTime date) async {
    final endOfDay = DateTime.utc(date.year, date.month, date.day, 23, 59, 59);
    final totals = await db.customSelect(
      'SELECT account_id, SUM(amount_minor) AS total '
      'FROM transactions WHERE deleted_at IS NULL AND occurred_at <= ? '
      'GROUP BY account_id',
      variables: [Variable.withDateTime(endOfDay)],
    ).get();

    final day = _dayKey(date);
    await db.transaction(() async {
      for (final row in totals) {
        final accountId = row.read<int>('account_id');
        final account = await getAccount(accountId);
        final balance = account.initialBalance + row.read<int>('total');
        await db.into(db.accountSnapshots).insert(
              AccountSnapshotsCompanion.insert(
                accountId: accountId,
                date: day,
                balanceMinor: balance,
              ),
              onConflict: DoUpdate(
                (existing) => AccountSnapshotsCompanion(balanceMinor: Value(balance)),
                target: [db.accountSnapshots.accountId, db.accountSnapshots.date],
              ),
            );
      }
    });
  }

  String _dayKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }
}
