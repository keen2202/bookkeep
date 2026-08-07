import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/core/constants/constants.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/sync_ops_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/op_logger.dart';
import 'package:bookkeep_app/features/sync/sync_api.dart';
import 'package:bookkeep_app/features/sync/sync_engine.dart';
import 'package:bookkeep_app/features/sync/sync_merger.dart';
import 'package:bookkeep_app/features/sync/sync_state.dart';
import 'package:bookkeep_app/features/sync/token_store.dart';

import '../../../helpers/fake_sync_server.dart';

void main() {
  late AppDatabase db;
  late OpLogger logger;
  late FakeSyncServer server;
  late InMemoryTokenStore tokens;
  late SyncEngine engine;

  const email = 'engine@test.local';
  const password = 'password-123';

  Future<void> setUpEngine({String? bookId}) async {
    db = AppDatabase(NativeDatabase.memory());
    logger = OpLogger(db);
    server = FakeSyncServer();
    tokens = InMemoryTokenStore();
    engine = SyncEngine(
      opLogger: logger,
      api: server,
      tokenStore: tokens,
      merger: SyncMerger(db),
      email: email,
      password: password,
      // 默认测试账本 = kDefaultBookId（与直接插入/入队行一致，BK-T-010）
      bookId: bookId ?? kDefaultBookId,
    );
  }

  tearDown(() async {
    await db.close();
  });

  /// 本机建账户+流水（行含 remote_id，镜像仓库写路径）
  Future<({String accountRemoteId, String txRemoteId})> createLocalAccountAndTx(
      int amountMinor) async {
    final accountRemoteId = logger.newUuid();
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          remoteId: Value(accountRemoteId),
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final txRemoteId = logger.newUuid();
    final txId = await db.into(db.transactions).insert(TransactionsCompanion.insert(
          remoteId: Value(txRemoteId),
          accountId: 1,
          type: TransactionType.expense,
          amountMinor: amountMinor,
          currency: 'CNY',
          occurredAt: DateTime.utc(2026, 8, 1, 12),
          updatedAt: DateTime.utc(2026, 8, 1, 12),
        ));
    await logger.enqueue(
      entity: 'transaction',
      entityId: txId,
      remoteId: txRemoteId,
      op: SyncOpCode.c,
      payload: {
        'account_id': accountRemoteId,
        'category_id': null,
        'type': 'expense',
        'amount_minor': amountMinor,
        'currency': 'CNY',
        'occurred_at': '2026-08-01T12:00:00.000Z',
        'note': null,
        'auto_generated': false,
      },
    );
    return (accountRemoteId: accountRemoteId, txRemoteId: txRemoteId);
  }

  test('first sync registers the account, pushes ops, pulls and merges', () async {
    await setUpEngine();
    await createLocalAccountAndTx(-100);

    await engine.sync();

    expect(engine.phase, SyncPhase.idle);
    expect(await tokens.read(), isNotNull);
    // 推送后队列清空，游标推进
    expect(await logger.pendingOps(), isEmpty);
    expect(await logger.lastSyncedSeq(), server.seq);
  });

  test('start() auto-syncs when any OpLogger instance enqueues (shared stream, H4)', () async {
    await setUpEngine();
    engine.start();
    // 通过仓库的独立 OpLogger 实例写入（模拟真实写路径）
    await createLocalAccountAndTx(-100);
    await Future<void>.delayed(const Duration(milliseconds: 700)); // 防抖 300ms + 同步
    expect(server.seq, greaterThan(0));
    expect(await logger.pendingOps(), isEmpty);
    await engine.dispose();
  });

  test('offline sync fails into error phase and recovers with all 100 ops and no duplicates', () async {
    await setUpEngine();
    for (var i = 0; i < 100; i++) {
      await logger.enqueue(entity: 'transaction', entityId: i, remoteId: logger.newUuid(), op: SyncOpCode.c, bookId: kDefaultBookId, payload: {'amount_minor': -i});
    }
    server.offline = true;

    await engine.sync();
    expect(engine.phase, SyncPhase.error);
    expect(await logger.pendingOps(), hasLength(100)); // 队列保留

    server.offline = false;
    await engine.sync();

    expect(engine.phase, SyncPhase.idle);
    expect(await logger.pendingOps(), isEmpty);
    expect(server.seq, 100); // 服务端恰好 100 条

    // 再次同步不产生重复
    await engine.sync();
    expect(server.seq, 100);
  });

  test('pull merges ops from another client into the local database', () async {
    await setUpEngine();
    await createLocalAccountAndTx(-100);
    await engine.sync();

    // 另一台设备 A 直接向服务端推入一笔（模拟远端写入）
    final bookId = engine.bookId!;
    server.addMember(bookId, 'other@test.local');
    const remoteAccount = '99999999-9999-4999-8999-999999999990';
    const remoteTx = '99999999-9999-4999-8999-999999999991';
    await server.push(bookId, [
      {
        'entity': 'account',
        'entity_id': remoteAccount,
        'op': 'c',
        'payload': {'type': 'cash', 'name': '远端钱包', 'currency': 'CNY', 'initial_balance': 0, 'archived': false},
        'lamport': 1,
        'client_id': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      },
      {
        'entity': 'transaction',
        'entity_id': remoteTx,
        'op': 'c',
        'payload': {'account_id': remoteAccount, 'category_id': null, 'type': 'expense', 'amount_minor': -250, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': null, 'auto_generated': false},
        'lamport': 1,
        'client_id': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      },
    ], accessToken: 'access-other@test.local');

    await engine.sync();

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(2));
    expect(txs.map((t) => t.amountMinor), containsAll([-100, -250]));
    final accounts = await db.select(db.accounts).get();
    expect(accounts.map((a) => a.name), containsAll(['钱包', '远端钱包']));
    expect(await logger.lastSyncedSeq(), server.seq);
  });

  test('remote update of a locally created entity applies in place without duplicates (B1)', () async {
    await setUpEngine();
    final local = await createLocalAccountAndTx(-100);
    await engine.sync();

    // 远端设备改本机自建的流水（改金额+备注）
    final bookId = engine.bookId!;
    server.addMember(bookId, 'other@test.local');
    await server.push(bookId, [
      {
        'entity': 'transaction',
        'entity_id': local.txRemoteId,
        'op': 'u',
        'payload': {'account_id': local.accountRemoteId, 'category_id': null, 'type': 'expense', 'amount_minor': -888, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': '远端改', 'auto_generated': false},
        'lamport': 5,
        'client_id': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      },
    ], accessToken: 'access-other@test.local');

    await engine.sync();

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1)); // 无重复行
    expect(txs.single.amountMinor, -888);
    expect(txs.single.note, '远端改');
  });

  test('remote delete of a locally created entity soft-deletes it (B1)', () async {
    await setUpEngine();
    final local = await createLocalAccountAndTx(-100);
    await engine.sync();

    final bookId = engine.bookId!;
    server.addMember(bookId, 'other@test.local');
    await server.push(bookId, [
      {
        'entity': 'transaction',
        'entity_id': local.txRemoteId,
        'op': 'd',
        'payload': null,
        'lamport': 6,
        'client_id': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      },
    ], accessToken: 'access-other@test.local');

    await engine.sync();

    final tx = await db.select(db.transactions).getSingle();
    expect(tx.deletedAt, isNotNull);
  });

  test('an edit made after seeing the remote state wins by causal lamport (B2)', () async {
    const bookId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
    server = FakeSyncServer();
    server.addMember(bookId, 'a@test.local');
    server.addMember(bookId, 'b@test.local');

    final dbA = AppDatabase(NativeDatabase.memory());
    final loggerA = OpLogger(dbA);
    final engineA = SyncEngine(
      opLogger: loggerA,
      api: server,
      tokenStore: InMemoryTokenStore(),
      email: 'a@test.local',
      password: 'password-123',
      bookId: bookId,
    );
    final dbB = AppDatabase(NativeDatabase.memory());
    final loggerB = OpLogger(dbB);
    final engineB = SyncEngine(
      opLogger: loggerB,
      api: server,
      tokenStore: InMemoryTokenStore(),
      email: 'b@test.local',
      password: 'password-123',
      bookId: bookId,
    );

    // A 建账户 + 流水并同步
    final accountRemote = loggerA.newUuid();
    final txRemote = loggerA.newUuid();
    await dbA.into(dbA.accounts).insert(AccountsCompanion.insert(
          bookId: const Value(bookId),
          remoteId: Value(accountRemote),
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    await dbA.into(dbA.transactions).insert(TransactionsCompanion.insert(
          bookId: const Value(bookId),
          remoteId: Value(txRemote),
          accountId: 1,
          type: TransactionType.expense,
          amountMinor: -100,
          currency: 'CNY',
          occurredAt: DateTime.utc(2026, 8, 1, 12),
          updatedAt: DateTime.utc(2026, 8, 1, 12),
        ));
    await loggerA.enqueue(entity: 'account', entityId: 1, remoteId: accountRemote, op: SyncOpCode.c, bookId: bookId, payload: {'type': 'cash', 'name': '钱包', 'currency': 'CNY', 'initial_balance': 0, 'archived': false});
    await loggerA.enqueue(entity: 'transaction', entityId: 1, remoteId: txRemote, op: SyncOpCode.c, bookId: bookId, payload: {'account_id': accountRemote, 'category_id': null, 'type': 'expense', 'amount_minor': -100, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': null, 'auto_generated': false});
    await engineA.sync();

    // B 同步拿到 A 的数据
    await engineB.sync();
    expect(await dbB.select(dbB.transactions).get(), hasLength(1));

    // A 修改并同步（lamport 3）
    await (dbA.update(dbA.transactions)..where((t) => t.id.equals(1)))
        .write(const TransactionsCompanion(amountMinor: Value(-300), note: Value('A改')));
    await loggerA.enqueue(entity: 'transaction', entityId: 1, remoteId: txRemote, op: SyncOpCode.u, bookId: bookId, payload: {'account_id': accountRemote, 'category_id': null, 'type': 'expense', 'amount_minor': -300, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': 'A改', 'auto_generated': false});
    await engineA.sync();

    // B 已看到 A 的修改（远端 lamport 3）后再改 → lamport 4 > 3，B 必胜
    await engineB.sync();
    final bTx = await dbB.select(dbB.transactions).getSingle();
    expect(bTx.note, 'A改');
    await (dbB.update(dbB.transactions)..where((t) => t.id.equals(bTx.id)))
        .write(const TransactionsCompanion(amountMinor: Value(-500), note: Value('B改')));
    await loggerB.enqueue(entity: 'transaction', entityId: bTx.id, remoteId: txRemote, op: SyncOpCode.u, bookId: bookId, payload: {'account_id': accountRemote, 'category_id': null, 'type': 'expense', 'amount_minor': -500, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': 'B改', 'auto_generated': false});
    await engineB.sync();

    // 双方再同步 → 收敛到 B 的修改
    await engineA.sync();
    await engineB.sync();

    final txA = await dbA.select(dbA.transactions).getSingle();
    final txB = await dbB.select(dbB.transactions).getSingle();
    expect(txA.amountMinor, txB.amountMinor);
    expect(txA.note, txB.note);
    expect(txA.note, 'B改');

    await dbA.close();
    await dbB.close();
  });

  test('concurrent edits converge to the same final state (LWW, either side wins)', () async {
    const bookId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
    server = FakeSyncServer();
    server.addMember(bookId, 'a@test.local');
    server.addMember(bookId, 'b@test.local');

    final dbA = AppDatabase(NativeDatabase.memory());
    final loggerA = OpLogger(dbA);
    final engineA = SyncEngine(
      opLogger: loggerA,
      api: server,
      tokenStore: InMemoryTokenStore(),
      email: 'a@test.local',
      password: 'password-123',
      bookId: bookId,
    );
    final dbB = AppDatabase(NativeDatabase.memory());
    final loggerB = OpLogger(dbB);
    final engineB = SyncEngine(
      opLogger: loggerB,
      api: server,
      tokenStore: InMemoryTokenStore(),
      email: 'b@test.local',
      password: 'password-123',
      bookId: bookId,
    );

    // A 建账户 + 流水并同步；B 拿到数据
    final accountRemote = loggerA.newUuid();
    final txRemote = loggerA.newUuid();
    await dbA.into(dbA.accounts).insert(AccountsCompanion.insert(
          bookId: const Value(bookId),
          remoteId: Value(accountRemote),
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    await dbA.into(dbA.transactions).insert(TransactionsCompanion.insert(
          bookId: const Value(bookId),
          remoteId: Value(txRemote),
          accountId: 1,
          type: TransactionType.expense,
          amountMinor: -100,
          currency: 'CNY',
          occurredAt: DateTime.utc(2026, 8, 1, 12),
          updatedAt: DateTime.utc(2026, 8, 1, 12),
        ));
    await loggerA.enqueue(entity: 'account', entityId: 1, remoteId: accountRemote, op: SyncOpCode.c, bookId: bookId, payload: {'type': 'cash', 'name': '钱包', 'currency': 'CNY', 'initial_balance': 0, 'archived': false});
    await loggerA.enqueue(entity: 'transaction', entityId: 1, remoteId: txRemote, op: SyncOpCode.c, bookId: bookId, payload: {'account_id': accountRemote, 'category_id': null, 'type': 'expense', 'amount_minor': -100, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': null, 'auto_generated': false});
    await engineA.sync();
    await engineB.sync();

    // 双方各自并发修改（均未看到对方的修改）
    await (dbA.update(dbA.transactions)..where((t) => t.id.equals(1)))
        .write(const TransactionsCompanion(amountMinor: Value(-300), note: Value('A改')));
    await loggerA.enqueue(entity: 'transaction', entityId: 1, remoteId: txRemote, op: SyncOpCode.u, bookId: bookId, payload: {'account_id': accountRemote, 'category_id': null, 'type': 'expense', 'amount_minor': -300, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': 'A改', 'auto_generated': false});
    final bTx = await dbB.select(dbB.transactions).getSingle();
    await (dbB.update(dbB.transactions)..where((t) => t.id.equals(bTx.id)))
        .write(const TransactionsCompanion(amountMinor: Value(-500), note: Value('B改')));
    await loggerB.enqueue(entity: 'transaction', entityId: bTx.id, remoteId: txRemote, op: SyncOpCode.u, bookId: bookId, payload: {'account_id': accountRemote, 'category_id': null, 'type': 'expense', 'amount_minor': -500, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'note': 'B改', 'auto_generated': false});

    await engineA.sync();
    await engineB.sync();
    await engineA.sync();
    await engineB.sync();

    final txA = await dbA.select(dbA.transactions).getSingle();
    final txB = await dbB.select(dbB.transactions).getSingle();
    expect(txA.amountMinor, txB.amountMinor);
    expect(txA.note, txB.note);
    expect(txA.note, isIn(['A改', 'B改']));
    expect(await dbA.select(dbA.transactions).get(), hasLength(1));
    expect(await dbB.select(dbB.transactions).get(), hasLength(1));

    await dbA.close();
    await dbB.close();
  });

  test('未登录（无 token 无凭据）sync() 纯本地降级：不触碰服务端（审查 B-1）', () async {
    db = AppDatabase(NativeDatabase.memory());
    logger = OpLogger(db);
    server = FakeSyncServer();
    tokens = InMemoryTokenStore();
    engine = SyncEngine(
      opLogger: logger,
      api: server,
      tokenStore: tokens,
      merger: SyncMerger(db),
      bookId: kDefaultBookId,
    );
    var serverTouched = false;
    final proxied = _TouchCountingServer(server, () => serverTouched = true);
    // 重建 engine 使用计数代理（先保留原 engine 引用以便 dispose）
    final spyEngine = SyncEngine(
      opLogger: logger,
      api: proxied,
      tokenStore: tokens,
      merger: SyncMerger(db),
      bookId: kDefaultBookId,
    );
    await spyEngine.sync();
    expect(spyEngine.phase, SyncPhase.idle);
    expect(serverTouched, isFalse);
    await spyEngine.dispose();
  });

  test('401 触发刷新且单飞：一轮 sync 内 refresh 仅调用一次（审查 B-1）', () async {
    db = AppDatabase(NativeDatabase.memory());
    logger = OpLogger(db);
    final expiring = _ExpiringServer();
    await expiring.register(email, password);
    tokens = InMemoryTokenStore(TokenPair(
      accessToken: 'access-$email',
      refreshToken: 'refresh-$email',
    ));
    final accountRemoteId = logger.newUuid();
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          remoteId: Value(accountRemoteId),
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final txRemoteId = logger.newUuid();
    final txId = await db.into(db.transactions).insert(TransactionsCompanion.insert(
          remoteId: Value(txRemoteId),
          accountId: 1,
          type: TransactionType.expense,
          amountMinor: -100,
          currency: 'CNY',
          occurredAt: DateTime.utc(2026, 8, 1, 12),
          updatedAt: DateTime.utc(2026, 8, 1, 12),
        ));
    await logger.enqueue(
      entity: 'transaction',
      entityId: txId,
      remoteId: txRemoteId,
      op: SyncOpCode.c,
      bookId: kDefaultBookId,
      payload: {'account_id': accountRemoteId, 'category_id': null, 'type': 'expense', 'amount_minor': -100, 'currency': 'CNY', 'occurred_at': '2026-08-01T12:00:00.000Z', 'auto_generated': false},
    );
    engine = SyncEngine(
      opLogger: logger,
      api: expiring,
      tokenStore: tokens,
      merger: SyncMerger(db),
      email: email,
      password: password,
      bookId: kDefaultBookId,
    );
    await engine.sync();
    expect(expiring.refreshCalls, 1);
    expect(engine.phase, SyncPhase.idle);
    expect(await tokens.read(), isNotNull);
  });
}

class _ExpiringServer extends FakeSyncServer {
  int refreshCalls = 0;
  bool expireNextPush = true;

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    refreshCalls++;
    return super.refresh(refreshToken);
  }

  @override
  Future<PushResult> push(String bookId, List<Map<String, dynamic>> ops,
      {required String accessToken}) async {
    if (expireNextPush) {
      expireNextPush = false;
      throw const SyncApiException(401, 'expired');
    }
    return super.push(bookId, ops, accessToken: accessToken);
  }
}

class _TouchCountingServer extends FakeSyncServer {
  _TouchCountingServer(this.inner, this.onTouch);
  final FakeSyncServer inner;
  final void Function() onTouch;

  void _mark() => onTouch();

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    _mark();
    return inner.refresh(refreshToken);
  }

  @override
  Future<PushResult> push(String bookId, List<Map<String, dynamic>> ops,
      {required String accessToken}) async {
    _mark();
    return inner.push(bookId, ops, accessToken: accessToken);
  }

  @override
  Future<PullResult> pull(String bookId, int sinceSeq,
      {required String accessToken, int limit = 500}) async {
    _mark();
    return inner.pull(bookId, sinceSeq, accessToken: accessToken, limit: limit);
  }
}