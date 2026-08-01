import 'package:drift/drift.dart';

import '../local/database.dart';
import '../local/tables/sync_ops_table.dart';
import 'op_logger.dart';

/// 预算仓库（Spec §3.4 / BK-P0-004）：写路径统一经 OpLogger 入队
class BudgetRepository {
  BudgetRepository(this.db, {OpLogger? opLogger}) : opLogger = opLogger ?? OpLogger(db);

  final AppDatabase db;
  final OpLogger opLogger;

  static const _alertPrefix = 'budget_alert_';

  Future<int> createBudget({
    required int? categoryId,
    required String period,
    required int amountMinor,
    int threshold = 80,
  }) async {
    return db.transaction(() async {
      final remoteId = opLogger.newUuid();
      final id = await db.into(db.budgets).insert(BudgetsCompanion.insert(
            remoteId: Value(remoteId),
            categoryId: Value(categoryId),
            period: period,
            amountMinor: amountMinor,
            threshold: Value(threshold),
          ));
      await opLogger.enqueue(
        entity: 'budget',
        entityId: id,
        remoteId: remoteId,
        op: SyncOpCode.c,
        payload: {
          'id': id,
          'category_id': categoryId == null ? null : await _remoteIdOf(categoryId),
          'period': period,
          'amount_minor': amountMinor,
          'threshold': threshold,
        },
      );
      return id;
    });
  }

  Future<void> updateBudget(
    int id, {
    int? amountMinor,
    int? threshold,
    String? period,
  }) async {
    await db.transaction(() async {
      await (db.update(db.budgets)..where((t) => t.id.equals(id))).write(
        BudgetsCompanion(
          amountMinor: amountMinor != null ? Value(amountMinor) : const Value.absent(),
          threshold: threshold != null ? Value(threshold) : const Value.absent(),
          period: period != null ? Value(period) : const Value.absent(),
        ),
      );
      await _enqueueSnapshot(id, SyncOpCode.u);
    });
  }

  Future<void> deleteBudget(int id) async {
    await db.transaction(() async {
      final budget = await (db.select(db.budgets)..where((t) => t.id.equals(id))).getSingle();
      await (db.delete(db.budgets)..where((t) => t.id.equals(id))).go();
      await opLogger.enqueue(
        entity: 'budget',
        entityId: id,
        remoteId: budget.remoteId!,
        op: SyncOpCode.d,
      );
    });
  }

  Future<String?> _remoteIdOf(int categoryId) async {
    final row = await (db.select(db.categories)..where((t) => t.id.equals(categoryId))).getSingle();
    return row.remoteId;
  }

  Future<void> _enqueueSnapshot(int id, SyncOpCode op) async {
    final budget = await (db.select(db.budgets)..where((t) => t.id.equals(id))).getSingle();
    await opLogger.enqueue(
      entity: 'budget',
      entityId: id,
      remoteId: budget.remoteId!,
      op: op,
      payload: {
        'id': id,
        'category_id': budget.categoryId == null ? null : await _remoteIdOf(budget.categoryId!),
        'period': budget.period,
        'amount_minor': budget.amountMinor,
        'threshold': budget.threshold,
      },
    );
  }

  Future<List<Budget>> listBudgets() {
    final q = db.select(db.budgets)..orderBy([(t) => OrderingTerm.asc(t.id)]);
    return q.get();
  }

  /// 周期内支出（SQL 聚合）：窗口 [start, end)，含子分类、不含已删除、不含收入
  Future<int> spentForPeriod({
    required int? categoryId,
    required DateTime start,
    required DateTime end,
  }) async {
    final query = db.customSelect(
      'SELECT COALESCE(SUM(-amount_minor), 0) AS spent '
      'FROM transactions '
      'WHERE type = ? AND deleted_at IS NULL '
      'AND occurred_at >= ? AND occurred_at < ? '
      '${categoryId != null ? 'AND category_id = ?' : ''}',
      variables: [
        Variable.withString('expense'),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
        if (categoryId != null) Variable.withInt(categoryId),
      ],
    );
    final row = await query.getSingle();
    return row.read<int>('spent');
  }

  /// 阈值提醒「恰好一次」：以 (budget_id, period, level) 去重（Spec §3.4）
  Future<bool> shouldNotify(int budgetId, {required String period, required String level}) async {
    final key = '$_alertPrefix${budgetId}_${period}_$level';
    final rows = await (db.select(db.appMeta)..where((t) => t.key.equals(key))).get();
    return rows.isEmpty;
  }

  Future<void> markAlertNotified(int budgetId, {required String period, required String level}) async {
    final key = '$_alertPrefix${budgetId}_${period}_$level';
    await db.into(db.appMeta)
        .insert(AppMetaCompanion.insert(key: key, value: 'true'));
  }
}
