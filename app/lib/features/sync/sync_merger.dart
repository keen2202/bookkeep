import 'package:drift/drift.dart';

import '../../core/constants/constants.dart';
import '../../data/local/database.dart';
import '../../data/local/tables/accounts_table.dart';
import '../../data/local/tables/categories_table.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../domain/models/remote_op.dart';
import '../../domain/services/lww_resolver.dart';

/// 把远端 op 批次合并到本地库（BK-T-007）：
/// 按实体分组 → LWW/删除优先解析 → create 先物化（FK 映射就绪）再处理 u/d。
/// 实体身份 = 各表 remote_id 列（uuid v4）；幂等：create 已存在即跳过；
/// u/d 未找到目标时：update 按完整快照 upsert 物化（LWW 折叠场景），delete 跳过。
/// 畸形 payload 单 op 跳过，不中断整批合并（评审 H1）。
/// 合并结果归属 sync 引擎的账本（Spec §4.1 / BK-T-010）。
class SyncMerger {
  SyncMerger(this.db, {LwwResolver? resolver, this.bookId = kDefaultBookId})
      : _resolver = resolver ?? const LwwResolver();

  final AppDatabase db;
  final LwwResolver _resolver;
  final String bookId;

  static const _entities = {'account', 'category', 'transaction', 'budget'};

  Future<int> merge(List<RemoteOp> ops) async {
    if (ops.isEmpty) return 0;

    final groups = <String, List<RemoteOp>>{};
    for (final op in ops) {
      if (!_entities.contains(op.entity)) continue;
      groups.putIfAbsent('${op.entity}:${op.entityId}', () => []).add(op);
    }

    final resolved = <ResolvedOp>[];
    for (final group in groups.values) {
      final r = _resolver.resolve(group);
      if (r != null) resolved.add(r);
    }
    // create 先物化（保证 FK 引用映射就绪），其余保持原序
    final creates = resolved.where((r) => r.op == 'c').toList();
    final others = resolved.where((r) => r.op != 'c').toList();

    var applied = 0;
    await db.transaction(() async {
      for (final r in [...creates, ...others]) {
        try {
          if (await _apply(r)) applied++;
        } catch (_) {
          // 单 op 失败（畸形 payload）不中断整批合并
        }
      }
    });
    return applied;
  }

  Future<bool> _apply(ResolvedOp r) async {
    switch (r.op) {
      case 'c':
        return _applyCreate(r.entity, r.entityId, r.payload);
      case 'u':
        return _applyUpdate(r.entity, r.entityId, r.payload);
      case 'd':
        return _applyDelete(r.entity, r.entityId);
    }
    return false;
  }

  Future<bool> _applyCreate(String entity, String remoteId, Map<String, dynamic>? payload) async {
    if (payload == null) return false;
    if (await _localIdByRemoteId(entity, remoteId) != null) return false; // 幂等

    final localId = switch (entity) {
      'account' => await _createAccount(remoteId, payload),
      'category' => await _createCategory(remoteId, payload),
      'transaction' => await _createTransaction(remoteId, payload),
      'budget' => await _createBudget(remoteId, payload),
      _ => null,
    };
    return localId != null;
  }

  Future<bool> _applyUpdate(String entity, String remoteId, Map<String, dynamic>? payload) async {
    final localId = await _localIdByRemoteId(entity, remoteId);
    // LWW 可能把 create 折叠进 update：未找到时按完整快照 upsert 物化
    if (localId == null) return _applyCreate(entity, remoteId, payload);
    if (payload == null) return false;
    return switch (entity) {
      'account' => _updateAccount(localId, payload),
      'category' => _updateCategory(localId, payload),
      'transaction' => _updateTransaction(localId, payload),
      'budget' => _updateBudget(localId, payload),
      _ => Future.value(false),
    };
  }

  Future<bool> _applyDelete(String entity, String remoteId) async {
    final localId = await _localIdByRemoteId(entity, remoteId);
    if (localId == null) return false;
    final now = DateTime.now().toUtc();
    switch (entity) {
      case 'transaction':
        await (db.update(db.transactions)..where((t) => t.id.equals(localId)))
            .write(TransactionsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));
      case 'account':
        await (db.update(db.accounts)..where((t) => t.id.equals(localId)))
            .write(const AccountsCompanion(archived: Value(true)));
      case 'category':
        await (db.update(db.categories)..where((t) => t.id.equals(localId)))
            .write(CategoriesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));
      case 'budget':
        await (db.delete(db.budgets)..where((t) => t.id.equals(localId))).go();
      default:
        return false;
    }
    return true;
  }

  Future<int?> _createAccount(String remoteId, Map<String, dynamic> p) async {
    final type = _enumFromName(p['type'], AccountType.values);
    if (type == null) return null;
    return db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: Value(bookId),
          remoteId: Value(remoteId),
          accountType: type,
          name: _str(p, 'name') ?? '',
          currency: _str(p, 'currency') ?? 'CNY',
          initialBalance: Value(_int(p, 'initial_balance') ?? 0),
          archived: Value(_bool(p, 'archived') ?? false),
          createdAt: _date(p, 'created_at') ?? DateTime.now().toUtc(),
        ));
  }

  Future<int?> _createCategory(String remoteId, Map<String, dynamic> p) async {
    final kind = _enumFromName(p['kind'], CategoryKind.values);
    if (kind == null) return null;
    final parentRef = _str(p, 'parent_id');
    final parentId = parentRef == null ? null : await _localIdByRemoteId('category', parentRef);
    return db.into(db.categories).insert(CategoriesCompanion.insert(
          bookId: Value(bookId),
          remoteId: Value(remoteId),
          parentId: Value(parentId),
          name: _str(p, 'name') ?? '',
          icon: _str(p, 'icon') ?? 'tag',
          color: _int(p, 'color') ?? 0xFF607D8B,
          kind: kind,
          isSystem: Value(_bool(p, 'is_system') ?? false),
          sortOrder: Value(_int(p, 'sort_order') ?? 0),
          updatedAt: _date(p, 'updated_at') ?? DateTime.now().toUtc(),
        ));
  }

  Future<int?> _createTransaction(String remoteId, Map<String, dynamic> p) async {
    final accountRef = _str(p, 'account_id');
    final accountId = accountRef == null ? null : await _localIdByRemoteId('account', accountRef);
    if (accountId == null) return null; // FK 未就绪 → 跳过（依赖先同步）

    final type = _enumFromName(p['type'], TransactionType.values);
    if (type == null) return null;
    final amount = _int(p, 'amount_minor');
    if (amount == null) return null;

    final categoryRef = _str(p, 'category_id');
    final categoryId = categoryRef == null ? null : await _localIdByRemoteId('category', categoryRef);
    final transferRef = _str(p, 'transfer_id');
    final transferId = transferRef == null ? null : await _localIdByRemoteId('transaction', transferRef);

    return db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: Value(bookId),
          remoteId: Value(remoteId),
          accountId: accountId,
          categoryId: Value(categoryId),
          type: type,
          amountMinor: amount,
          currency: _str(p, 'currency') ?? 'CNY',
          note: Value(_str(p, 'note')),
          occurredAt: _date(p, 'occurred_at') ?? DateTime.now().toUtc(),
          transferId: Value(transferId),
          autoGenerated: Value(_bool(p, 'auto_generated') ?? false),
          updatedAt: _date(p, 'updated_at') ?? DateTime.now().toUtc(),
        ));
  }

  Future<int?> _createBudget(String remoteId, Map<String, dynamic> p) async {
    final amount = _int(p, 'amount_minor');
    if (amount == null) return null;
    final categoryRef = _str(p, 'category_id');
    final categoryId = categoryRef == null ? null : await _localIdByRemoteId('category', categoryRef);
    return db.into(db.budgets).insert(BudgetsCompanion.insert(
          bookId: Value(bookId),
          remoteId: Value(remoteId),
          categoryId: Value(categoryId),
          period: _str(p, 'period') ?? '',
          amountMinor: amount,
          threshold: Value(_int(p, 'threshold') ?? 80),
        ));
  }

  Future<bool> _updateAccount(int localId, Map<String, dynamic> p) async {
    final (name, hasName) = _strField(p, 'name');
    final (currency, hasCurrency) = _strField(p, 'currency');
    final (initialBalance, hasInitialBalance) = _intField(p, 'initial_balance');
    final (archived, hasArchived) = _boolField(p, 'archived');
    await (db.update(db.accounts)..where((t) => t.id.equals(localId))).write(AccountsCompanion(
      name: hasName ? Value(name ?? '') : const Value.absent(),
      currency: hasCurrency ? Value(currency ?? 'CNY') : const Value.absent(),
      initialBalance: hasInitialBalance ? Value(initialBalance ?? 0) : const Value.absent(),
      archived: hasArchived ? Value(archived ?? false) : const Value.absent(),
    ));
    return true;
  }

  Future<bool> _updateCategory(int localId, Map<String, dynamic> p) async {
    final (name, hasName) = _strField(p, 'name');
    final (icon, hasIcon) = _strField(p, 'icon');
    final (color, hasColor) = _intField(p, 'color');
    final (sortOrder, hasSortOrder) = _intField(p, 'sort_order');
    await (db.update(db.categories)..where((t) => t.id.equals(localId))).write(CategoriesCompanion(
      name: hasName ? Value(name ?? '') : const Value.absent(),
      icon: hasIcon ? Value(icon ?? '') : const Value.absent(),
      color: hasColor ? Value(color ?? 0) : const Value.absent(),
      sortOrder: hasSortOrder ? Value(sortOrder ?? 0) : const Value.absent(),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
    return true;
  }

  Future<bool> _updateTransaction(int localId, Map<String, dynamic> p) async {
    final accountRef = _str(p, 'account_id');
    final accountId = accountRef == null ? null : await _localIdByRemoteId('account', accountRef);
    if (accountRef != null && accountId == null) return false;

    final categoryRef = _str(p, 'category_id');
    final categoryId = categoryRef == null ? null : await _localIdByRemoteId('category', categoryRef);
    final type = _enumFromName(p['type'], TransactionType.values);

    final (amount, hasAmount) = _intField(p, 'amount_minor');
    final (currency, hasCurrency) = _strField(p, 'currency');
    final (note, hasNote) = _strField(p, 'note');
    final (occurredAt, hasOccurredAt) = _dateField(p, 'occurred_at');
    final (autoGenerated, hasAutoGenerated) = _boolField(p, 'auto_generated');

    await (db.update(db.transactions)..where((t) => t.id.equals(localId))).write(
        TransactionsCompanion(
      accountId: accountId != null ? Value(accountId) : const Value.absent(),
      categoryId: categoryRef != null ? Value(categoryId) : const Value.absent(),
      type: type != null ? Value(type) : const Value.absent(),
      amountMinor: hasAmount ? Value(amount ?? 0) : const Value.absent(),
      currency: hasCurrency ? Value(currency ?? 'CNY') : const Value.absent(),
      note: hasNote ? Value(note) : const Value.absent(),
      occurredAt: hasOccurredAt ? Value(occurredAt ?? DateTime.now().toUtc()) : const Value.absent(),
      autoGenerated: hasAutoGenerated ? Value(autoGenerated ?? false) : const Value.absent(),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
    return true;
  }

  Future<bool> _updateBudget(int localId, Map<String, dynamic> p) async {
    final categoryRef = _str(p, 'category_id');
    final categoryId = categoryRef == null ? null : await _localIdByRemoteId('category', categoryRef);
    final (period, hasPeriod) = _strField(p, 'period');
    final (amount, hasAmount) = _intField(p, 'amount_minor');
    final (threshold, hasThreshold) = _intField(p, 'threshold');
    await (db.update(db.budgets)..where((t) => t.id.equals(localId))).write(BudgetsCompanion(
      categoryId: categoryRef != null ? Value(categoryId) : const Value.absent(),
      period: hasPeriod ? Value(period ?? '') : const Value.absent(),
      amountMinor: hasAmount ? Value(amount ?? 0) : const Value.absent(),
      threshold: hasThreshold ? Value(threshold ?? 80) : const Value.absent(),
    ));
    return true;
  }

  Future<int?> _localIdByRemoteId(String entity, String remoteId) async {
    switch (entity) {
      case 'account':
        final row = await (db.select(db.accounts)
              ..where((t) => t.remoteId.equals(remoteId) & t.bookId.equals(bookId)))
            .getSingleOrNull();
        return row?.id;
      case 'category':
        final row = await (db.select(db.categories)
              ..where((t) => t.remoteId.equals(remoteId) & t.bookId.equals(bookId)))
            .getSingleOrNull();
        return row?.id;
      case 'transaction':
        final row = await (db.select(db.transactions)
              ..where((t) => t.remoteId.equals(remoteId) & t.bookId.equals(bookId)))
            .getSingleOrNull();
        return row?.id;
      case 'budget':
        final row = await (db.select(db.budgets)
              ..where((t) => t.remoteId.equals(remoteId) & t.bookId.equals(bookId)))
            .getSingleOrNull();
        return row?.id;
    }
    return null;
  }

  // —— 类型安全取值（畸形 payload 返回 null，不抛异常，评审 H1）——
  String? _str(Map<String, dynamic> p, String key) {
    final v = p[key];
    return v is String ? v : null;
  }

  int? _int(Map<String, dynamic> p, String key) {
    final v = p[key];
    return v is int ? v : null;
  }

  bool? _bool(Map<String, dynamic> p, String key) {
    final v = p[key];
    return v is bool ? v : null;
  }

  DateTime? _date(Map<String, dynamic> p, String key) {
    final v = p[key];
    if (v is! String) return null;
    return DateTime.tryParse(v);
  }

  // —— 字段存在性语义：缺失 → 不动；显式 null → 置空；非法类型 → 不动（评审 H1）——
  (String?, bool) _strField(Map<String, dynamic> p, String key) {
    if (!p.containsKey(key)) return (null, false);
    final v = p[key];
    if (v is String) return (v, true);
    if (v == null) return (null, true);
    return (null, false);
  }

  (int?, bool) _intField(Map<String, dynamic> p, String key) {
    if (!p.containsKey(key)) return (null, false);
    final v = p[key];
    if (v is int) return (v, true);
    if (v == null) return (null, true);
    return (null, false);
  }

  (bool?, bool) _boolField(Map<String, dynamic> p, String key) {
    if (!p.containsKey(key)) return (null, false);
    final v = p[key];
    if (v is bool) return (v, true);
    if (v == null) return (null, true);
    return (null, false);
  }

  (DateTime?, bool) _dateField(Map<String, dynamic> p, String key) {
    if (!p.containsKey(key)) return (null, false);
    final v = p[key];
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return (parsed, true);
    }
    if (v == null) return (null, true);
    return (null, false);
  }

  T? _enumFromName<T extends Enum>(Object? v, List<T> candidates) {
    if (v is! String) return null;
    for (final e in candidates) {
      if (e.name == v) return e;
    }
    return null;
  }
}
