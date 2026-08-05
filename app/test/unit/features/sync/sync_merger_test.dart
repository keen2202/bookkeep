import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/domain/models/remote_op.dart';
import 'package:bookkeep_app/features/sync/sync_merger.dart';

const client = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

// 远端实体身份（uuid 字符串，与实体表 remote_id 列一致）
var _seq = 0;
String nextId() => '99999999-9999-4999-8999-${(_seq++).toString().padLeft(12, '0')}';

void main() {
  late AppDatabase db;
  late SyncMerger merger;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    merger = SyncMerger(db);
  });

  tearDown(() async {
    await db.close();
  });

  RemoteOp op(
    String entity,
    String entityId,
    String op, {
    Map<String, dynamic>? payload,
    int lamport = 1,
  }) {
    return RemoteOp(
      entity: entity,
      entityId: entityId,
      op: op,
      lamport: lamport,
      clientId: client,
      payload: payload,
    );
  }

  test('merges a transaction create and is idempotent on replay', () async {
    final remoteTxId = nextId();
    final remoteAccountId = nextId();
    final created = await merger.merge([
      op('account', remoteAccountId, 'c', payload: {
        'type': 'cash',
        'name': '钱包',
        'currency': 'CNY',
        'initial_balance': 0,
        'archived': false,
      }),
      op('transaction', remoteTxId, 'c', payload: {
        'account_id': remoteAccountId,
        'category_id': null,
        'type': 'expense',
        'amount_minor': -1250,
        'currency': 'CNY',
        'occurred_at': '2026-08-01T12:00:00.000Z',
        'note': null,
        'auto_generated': false,
      }),
    ]);

    expect(created, 2);
    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.single.amountMinor, -1250);
    expect(txs.single.note, isNull);

    // 幂等重放：不再产生重复行
    final replay = await merger.merge([
      op('account', remoteAccountId, 'c', payload: {
        'type': 'cash',
        'name': '钱包',
        'currency': 'CNY',
        'initial_balance': 0,
        'archived': false,
      }),
      op('transaction', remoteTxId, 'c', payload: {
        'account_id': remoteAccountId,
        'category_id': null,
        'type': 'expense',
        'amount_minor': -1250,
        'currency': 'CNY',
        'occurred_at': '2026-08-01T12:00:00.000Z',
        'note': null,
        'auto_generated': false,
      }),
    ]);
    expect(replay, 0);
    expect(await db.select(db.transactions).get(), hasLength(1));
  });

  test('applies an update op to a previously created entity', () async {
    final remoteTxId = nextId();
    final remoteAccountId = nextId();
    await merger.merge([
      op('account', remoteAccountId, 'c', payload: {'type': 'cash', 'name': '钱包', 'currency': 'CNY', 'initial_balance': 0, 'archived': false}),
      op('transaction', remoteTxId, 'c', payload: {'account_id': remoteAccountId, 'category_id': null, 'type': 'expense', 'amount_minor': -100, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': null, 'auto_generated': false}),
    ]);

    await merger.merge([
      op('transaction', remoteTxId, 'u', lamport: 2, payload: {'account_id': remoteAccountId, 'category_id': null, 'type': 'expense', 'amount_minor': -250, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': '晚餐', 'auto_generated': false}),
    ]);

    final tx = await db.select(db.transactions).getSingle();
    expect(tx.amountMinor, -250);
    expect(tx.note, '晚餐');
  });

  test('delete op soft-deletes the local row (delete priority over later update)', () async {
    final remoteTxId = nextId();
    final remoteAccountId = nextId();
    await merger.merge([
      op('account', remoteAccountId, 'c', payload: {'type': 'cash', 'name': '钱包', 'currency': 'CNY', 'initial_balance': 0, 'archived': false}),
      op('transaction', remoteTxId, 'c', payload: {'account_id': remoteAccountId, 'category_id': null, 'type': 'expense', 'amount_minor': -100, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': null, 'auto_generated': false}),
    ]);

    // 同一实体：update（lamport 更高）与 delete（lamport 更低）并存 → 删除优先
    await merger.merge([
      op('transaction', remoteTxId, 'u', lamport: 9, payload: {'account_id': remoteAccountId, 'category_id': null, 'type': 'expense', 'amount_minor': -999, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': 'x', 'auto_generated': false}),
      op('transaction', remoteTxId, 'd', lamport: 2),
    ]);

    final tx = await db.select(db.transactions).getSingle();
    expect(tx.deletedAt, isNotNull);
  });

  test('ignores ops for unmapped entities and unresolvable FKs', () async {
    final applied = await merger.merge([
      op('transaction', nextId(), 'c', payload: {'account_id': nextId(), 'category_id': null, 'type': 'expense', 'amount_minor': -100, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': null, 'auto_generated': false}),
      op('transaction', nextId(), 'd'),
      op('gadget', nextId(), 'c', payload: {}),
    ]);

    expect(applied, 0);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  test('merges account update (archive) and category with parent resolution', () async {
    final parentId = nextId();
    final childId = nextId();
    final accountId = nextId();
    await merger.merge([
      op('category', parentId, 'c', payload: {'parent_id': null, 'name': '餐饮', 'icon': 'restaurant', 'color': 0xFF111111, 'kind': 'expense', 'is_system': true, 'sort_order': 0}),
      op('category', childId, 'c', payload: {'parent_id': parentId, 'name': '早餐', 'icon': 'bakery', 'color': 0xFF222222, 'kind': 'expense', 'is_system': true, 'sort_order': 1}),
      op('account', accountId, 'c', payload: {'type': 'savings', 'name': '储蓄卡', 'currency': 'CNY', 'initial_balance': 5000, 'archived': false}),
    ]);

    final cats = await db.select(db.categories).get();
    expect(cats, hasLength(2));
    expect(cats[1].parentId, cats[0].id);

    await merger.merge([op('account', accountId, 'u', lamport: 2, payload: {'type': 'savings', 'name': '储蓄卡', 'currency': 'CNY', 'initial_balance': 5000, 'archived': true})]);
    final account = await db.select(db.accounts).getSingle();
    expect(account.archived, isTrue);

    // 删除分类 → 软删除
    await merger.merge([op('category', childId, 'd', lamport: 3)]);
    final child = await (db.select(db.categories)..where((t) => t.id.equals(cats[1].id))).getSingle();
    expect(child.deletedAt, isNotNull);
  });

  test('merges budget create/update/delete', () async {
    final budgetId = nextId();
    await merger.merge([
      op('budget', budgetId, 'c', payload: {'category_id': null, 'period': '2026-08-01', 'amount_minor': 300000, 'threshold': 80}),
    ]);
    final budget = await db.select(db.budgets).getSingle();
    expect(budget.amountMinor, 300000);

    await merger.merge([
      op('budget', budgetId, 'u', lamport: 2, payload: {'category_id': null, 'period': '2026-08-01', 'amount_minor': 500000, 'threshold': 90}),
    ]);
    final updated = await db.select(db.budgets).getSingle();
    expect(updated.amountMinor, 500000);
    expect(updated.threshold, 90);

    await merger.merge([op('budget', budgetId, 'd', lamport: 3)]);
    expect(await db.select(db.budgets).get(), isEmpty);
  });

  test('create ops are applied before updates across entities', () async {
    final remoteTxId = nextId();
    final remoteAccountId = nextId();
    // update 在 create 之前到达（乱序）→ 仍应先建 account 与 transaction
    await merger.merge([
      op('transaction', remoteTxId, 'u', lamport: 2, payload: {'account_id': remoteAccountId, 'category_id': null, 'type': 'expense', 'amount_minor': -500, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': '补', 'auto_generated': false}),
      op('account', remoteAccountId, 'c', payload: {'type': 'cash', 'name': '钱包', 'currency': 'CNY', 'initial_balance': 0, 'archived': false}),
      op('transaction', remoteTxId, 'c', lamport: 1, payload: {'account_id': remoteAccountId, 'category_id': null, 'type': 'expense', 'amount_minor': -100, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': null, 'auto_generated': false}),
    ]);

    final tx = await db.select(db.transactions).getSingle();
    expect(tx.amountMinor, -500);
  });

  test('malformed payloads are skipped without breaking the batch (H1)', () async {
    final remoteAccountId = nextId();
    final goodTxId = nextId();
    final badTxId = nextId();
    final applied = await merger.merge([
      op('account', remoteAccountId, 'c', payload: {'type': 'cash', 'name': '钱包', 'currency': 'CNY', 'initial_balance': 0, 'archived': false}),
      // 畸形：amount_minor 为字符串、occurred_at 非日期
      op('transaction', badTxId, 'c', payload: {'account_id': remoteAccountId, 'type': 'expense', 'amount_minor': 'not-a-number', 'occurred_at': 12345}),
      op('transaction', goodTxId, 'c', payload: {'account_id': remoteAccountId, 'category_id': null, 'type': 'expense', 'amount_minor': -100, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': null, 'auto_generated': false}),
    ]);

    expect(applied, 2); // account + 正常 tx；畸形 tx 被跳过
    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.single.amountMinor, -100);

    // 畸形 update 同样不中断
    final after = await merger.merge([
      op('transaction', goodTxId, 'u', lamport: 2, payload: {'amount_minor': 'bad', 'note': 42}),
    ]);
    expect(after, 1); // 字段全部非法 → 无字段生效，但 op 被消费
    final tx = await db.select(db.transactions).getSingle();
    expect(tx.amountMinor, -100);
  });
}
