import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/database.dart';
import '../local/tables/app_meta_table.dart';
import '../local/tables/sync_ops_table.dart';

/// 同步操作日志统一入口（BK-T-007）：全部写路径经此入队。
/// lamport 逻辑时钟单调递增（并纳入合并中观察到的远端最大 lamport，保证因果序）；
/// client_id 为持久化 uuid；payload 为完整实体快照，跨设备引用字段为远端 uuid。
/// sync_ops 按账本分区（Spec §4.1 / BK-T-010），游标按账本独立。
class OpLogger {
  OpLogger(this.db);

  static const clientIdKey = AppMetaKeys.clientId;
  static const lastSyncedSeqKeyPrefix = 'sync_last_seq_';
  static const bookIdKey = AppMetaKeys.syncBookId;
  static const maxRemoteLamportKey = AppMetaKeys.maxRemoteLamport;

  final AppDatabase db;
  static const _uuid = Uuid();
  final _onChange = StreamController<void>.broadcast();
  String? _cachedClientId;

  /// 跨实例共享事件：仓库各自持有 OpLogger 实例（同库），引擎监听此流即可
  /// 在任何写路径入队时被触发（BK-T-007 评审 H4）。
  static final _sharedOnChange = StreamController<void>.broadcast();
  static Stream<void> get sharedOnChange => _sharedOnChange.stream;

  Future<void> enqueue({
    required String entity,
    required int entityId,
    required String remoteId,
    required SyncOpCode op,
    Map<String, dynamic>? payload,
    required String bookId,
  }) async {
    final lamport = await nextLamport();
    final cid = await clientId();
    await db.into(db.syncOps).insert(SyncOpsCompanion.insert(
          bookId: bookId,
          entity: entity,
          entityId: entityId,
          remoteId: Value(remoteId),
          op: op,
          payload: jsonEncode(payload),
          lamport: lamport,
          clientId: cid,
          createdAt: DateTime.now().toUtc(),
        ));
    _onChange.add(null);
    _sharedOnChange.add(null);
  }

  /// 新实体的跨设备身份（uuid v4）
  String newUuid() => _uuid.v4();

  Future<List<SyncOp>> pendingOps({String? bookId, int limit = 500}) {
    final q = db.select(db.syncOps);
    if (bookId != null) {
      q.where((t) => t.pushed.equals(false) & t.bookId.equals(bookId));
    } else {
      q.where((t) => t.pushed.equals(false));
    }
    q.orderBy([(t) => OrderingTerm.asc(t.id)]);
    q.limit(limit);
    return q.get();
  }

  Future<void> markPushed(List<int> ids) async {
    if (ids.isEmpty) return;
    await (db.update(db.syncOps)..where((t) => t.id.isIn(ids)))
        .write(const SyncOpsCompanion(pushed: Value(true)));
  }

  /// 与远端批中实体重叠的本机 op（含已推送）：合并解析时必须与本机 op 一起
  /// 参与 LWW，否则平局（同 lamport）时两端各自解析出不同胜者导致发散。
  Future<List<SyncOp>> ownOpsForRemoteIds(Iterable<String> remoteIds) async {
    final ids = remoteIds.toSet();
    if (ids.isEmpty) return const [];
    return (db.select(db.syncOps)..where((t) => t.remoteId.isIn(ids))).get();
  }

  /// 合并后记录远端最大 lamport：本地新 op 的 lamport 必须大于已观察到的所有远端值，
  /// 否则因果序上的后写会以更小时钟输掉 LWW（BK-T-007 评审 B2）。
  Future<void> recordRemoteLamports(Iterable<int> lamports) async {
    var max = await maxRemoteLamport();
    for (final l in lamports) {
      if (l > max) max = l;
    }
    if (max > 0) {
      await db.into(db.appMeta)
          .insert(
            AppMetaCompanion.insert(key: maxRemoteLamportKey, value: '$max'),
            onConflict: DoUpdate((_) => AppMetaCompanion(value: Value('$max'))),
          );
    }
  }

  Future<int> maxRemoteLamport() async {
    final rows = await (db.select(db.appMeta)..where((t) => t.key.equals(maxRemoteLamportKey))).get();
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.single.value) ?? 0;
  }

  Future<int> nextLamport() async {
    final local = await db
        .customSelect('SELECT COALESCE(MAX(lamport), 0) AS m FROM sync_ops')
        .getSingle();
    final localMax = local.read<int>('m');
    final remoteMax = await maxRemoteLamport();
    return (localMax > remoteMax ? localMax : remoteMax) + 1;
  }

  Future<String> clientId() async {
    if (_cachedClientId != null) return _cachedClientId!;
    final rows = await (db.select(db.appMeta)..where((t) => t.key.equals(clientIdKey))).get();
    if (rows.isNotEmpty) {
      _cachedClientId = rows.single.value;
      return _cachedClientId!;
    }
    final id = _uuid.v4();
    await db.into(db.appMeta)
        .insert(AppMetaCompanion.insert(key: clientIdKey, value: id));
    _cachedClientId = id;
    return id;
  }

  Future<int> lastSyncedSeq({required String bookId}) async {
    final key = '$lastSyncedSeqKeyPrefix$bookId';
    final rows = await (db.select(db.appMeta)..where((t) => t.key.equals(key))).get();
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.single.value) ?? 0;
  }

  Future<void> setLastSyncedSeq(int seq, {required String bookId}) async {
    final key = '$lastSyncedSeqKeyPrefix$bookId';
    await db.into(db.appMeta)
        .insert(
          AppMetaCompanion.insert(key: key, value: '$seq'),
          onConflict: DoUpdate((_) => AppMetaCompanion(value: Value('$seq'))),
        );
  }

  /// 本客户端的账本 id（uuid v4，首次生成后持久化；服务端首推时自动建账，Spec §1.2）
  Future<String> ensureBookId() async {
    final rows = await (db.select(db.appMeta)..where((t) => t.key.equals(bookIdKey))).get();
    if (rows.isNotEmpty) return rows.single.value;
    final id = _uuid.v4();
    await db.into(db.appMeta).insert(AppMetaCompanion.insert(key: bookIdKey, value: id));
    return id;
  }

  Stream<void> get onChange => _onChange.stream;
}
