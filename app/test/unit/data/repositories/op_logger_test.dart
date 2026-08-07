import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/sync_ops_table.dart';
import 'package:bookkeep_app/data/repositories/op_logger.dart';

import '../../../helpers/fixtures.dart';

const remoteA = '11111111-1111-4111-8111-111111111111';
const remoteB = '22222222-2222-4222-8222-222222222222';

void main() {
  late AppDatabase db;
  late OpLogger logger;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    logger = OpLogger(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('enqueue writes ops with strictly increasing lamport and a persisted uuid client_id', () async {
    await logger.enqueue(entity: 'transaction', entityId: 1, remoteId: remoteA, op: SyncOpCode.c, bookId: testBookId, payload: {'a': 1});
    await logger.enqueue(entity: 'transaction', entityId: 2, remoteId: remoteB, op: SyncOpCode.c, bookId: testBookId, payload: {'a': 2});

    final ops = await db.select(db.syncOps).get();
    expect(ops, hasLength(2));
    expect(ops[0].lamport, lessThan(ops[1].lamport));

    final clientId = ops[0].clientId;
    expect(ops[1].clientId, clientId);
    // OpenAPI client_id format: uuid
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(clientId), isTrue);

    // 同一实例再次入队仍用同一 client_id
    await logger.enqueue(entity: 'budget', entityId: 5, remoteId: remoteA, op: SyncOpCode.c, bookId: testBookId);
    final again = await db.select(db.syncOps).get();
    expect(again.last.clientId, clientId);
  });

  test('enqueue stores the remote id and payload snapshot', () async {
    await logger.enqueue(entity: 'transaction', entityId: 7, remoteId: remoteA, op: SyncOpCode.d, bookId: testBookId);
    await logger.enqueue(entity: 'transaction', entityId: 8, remoteId: remoteB, op: SyncOpCode.c, bookId: testBookId, payload: {'amount_minor': -100});

    final ops = await db.select(db.syncOps).get();
    expect(ops[0].remoteId, remoteA);
    expect(ops[1].remoteId, remoteB);
    expect(jsonDecode(ops[0].payload), isNull);
    expect(jsonDecode(ops[1].payload), {'amount_minor': -100});
  });

  test('pendingOps returns only unpushed ops ordered by id and respects the limit', () async {
    for (var i = 1; i <= 5; i++) {
      await logger.enqueue(entity: 'transaction', entityId: i, remoteId: remoteA, op: SyncOpCode.c, bookId: testBookId);
    }
    final all = await db.select(db.syncOps).get();
    await logger.markPushed([all[0].id, all[1].id]);

    final pending = await logger.pendingOps();
    expect(pending.map((o) => o.entityId), [3, 4, 5]);

    final limited = await logger.pendingOps(limit: 2);
    expect(limited.map((o) => o.entityId), [3, 4]);
  });

  test('markPushed flips the pushed flag only for the given ids', () async {
    await logger.enqueue(entity: 'transaction', entityId: 1, remoteId: remoteA, op: SyncOpCode.c, bookId: testBookId);
    await logger.enqueue(entity: 'transaction', entityId: 2, remoteId: remoteB, op: SyncOpCode.c, bookId: testBookId);
    final ops = await db.select(db.syncOps).get();

    await logger.markPushed([ops[0].id]);

    final after = await db.select(db.syncOps).get();
    expect(after[0].pushed, isTrue);
    expect(after[1].pushed, isFalse);
  });

  test('lastSyncedSeq persists across OpLogger instances', () async {
    expect(await logger.lastSyncedSeq(bookId: testBookId), 0);
    await logger.setLastSyncedSeq(42, bookId: testBookId);

    final logger2 = OpLogger(db);
    expect(await logger2.lastSyncedSeq(bookId: testBookId), 42);
  });

  test('ensureBookId creates and persists a uuid book id', () async {
    final id = await logger.ensureBookId();
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(id), isTrue);

    final id2 = await OpLogger(db).ensureBookId();
    expect(id2, id);
  });

  test('newUuid returns fresh uuid values', () async {
    final a = logger.newUuid();
    final b = logger.newUuid();
    expect(a, isNot(b));
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(a), isTrue);
  });

  test('nextLamport rises above the recorded remote lamport after a merge', () async {
    await logger.enqueue(entity: 'transaction', entityId: 1, remoteId: remoteA, op: SyncOpCode.c, bookId: testBookId);
    expect(await logger.nextLamport(), 2);

    // 合并了远端 lamport=100 的 op 后，本地新 op 必须 > 100（因果序）
    await logger.recordRemoteLamports([100]);

    await logger.enqueue(entity: 'transaction', entityId: 2, remoteId: remoteB, op: SyncOpCode.c, bookId: testBookId);
    final ops = await db.select(db.syncOps).get();
    expect(ops.last.lamport, 101);
  });

  test('onChange fires when an op is enqueued', () async {
    final events = <void>[];
    final sub = logger.onChange.listen(events.add);
    await logger.enqueue(entity: 'transaction', entityId: 1, remoteId: remoteA, op: SyncOpCode.c, bookId: testBookId);
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
    await sub.cancel();
  });
}
