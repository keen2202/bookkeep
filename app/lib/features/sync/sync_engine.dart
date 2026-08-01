import 'dart:async';
import 'dart:convert';

import '../../data/local/database.dart';
import '../../data/repositories/op_logger.dart';
import '../../domain/models/remote_op.dart';
import 'sync_api.dart';
import 'sync_merger.dart';
import 'sync_state.dart';
import 'token_store.dart';

/// 客户端同步引擎（Spec §3.6 / BK-T-007）：
/// 状态机 idle → pushing → pulling → merging → idle；
/// 断网失败进入 error，队列保留，恢复后重试；写路径经 OpLogger 触发自动同步。
class SyncEngine {
  SyncEngine({
    required this.opLogger,
    required SyncApi api,
    required TokenStore tokenStore,
    required SyncMerger merger,
    this.email,
    this.password,
    this.bookId,
  })  : _api = api,
        _tokenStore = tokenStore,
        _merger = merger;

  final OpLogger opLogger;
  final SyncApi _api;
  final TokenStore _tokenStore;
  final SyncMerger _merger;
  final String? email;
  final String? password;
  final String? bookId;

  final SyncPhaseNotifier phaseNotifier = SyncPhaseNotifier();
  SyncPhase get phase => phaseNotifier.value;

  TokenPair? _tokens;
  bool _syncing = false;
  StreamSubscription<void>? _opSub;
  Timer? _debounce;

  /// 监听写路径：任何 OpLogger 实例入队即触发同步（防抖 300ms；
  /// 仓库各自持有实例，故监听跨实例共享流）
  void start() {
    _opSub ??= OpLogger.sharedOnChange.listen((_) => _schedule());
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(sync());
    });
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await _opSub?.cancel();
    _opSub = null;
  }

  /// 完整同步一轮：推送积压 → 拉取 → 合并，直到队列清空且拉取见底。
  Future<void> sync() async {
    if (_syncing) return;
    if (email == null || password == null || bookId == null) return;
    _syncing = true;
    try {
      await _ensureTokens();
      await _runSyncLoop();
      phaseNotifier.value = SyncPhase.idle;
    } on SyncNetworkException {
      // 离线：队列保留，恢复后由下一次触发重试
      phaseNotifier.value = SyncPhase.error;
    } on SyncApiException catch (e) {
      if (e.statusCode == 401) {
        final refreshed = await _refreshTokens();
        if (refreshed) {
          try {
            await _runSyncLoop();
            phaseNotifier.value = SyncPhase.idle;
          } catch (_) {
            phaseNotifier.value = SyncPhase.error;
          }
        } else {
          phaseNotifier.value = SyncPhase.error;
        }
      } else {
        phaseNotifier.value = SyncPhase.error;
      }
    } catch (_) {
      phaseNotifier.value = SyncPhase.error;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _ensureTokens() async {
    var tokens = await _tokenStore.read();
    if (tokens != null) {
      _tokens = tokens;
      return;
    }
    try {
      tokens = await _api.login(email!, password!);
    } on SyncApiException catch (e) {
      if (e.statusCode == 401) {
        tokens = await _api.register(email!, password!);
      } else if (e.statusCode == 409) {
        tokens = await _api.login(email!, password!);
      } else {
        rethrow;
      }
    }
    await _tokenStore.write(tokens);
    _tokens = tokens;
  }

  Future<bool> _refreshTokens() async {
    final current = await _tokenStore.read();
    if (current == null) return false;
    try {
      final pair = await _api.refresh(current.refreshToken);
      await _tokenStore.write(pair);
      _tokens = pair;
      return true;
    } on SyncApiException {
      await _tokenStore.clear();
      _tokens = null;
      return false;
    }
  }

  Future<void> _runSyncLoop() async {
    final ownClientId = await opLogger.clientId();
    var rounds = 0;
    while (rounds < 20) {
      rounds++;
      final pending = await opLogger.pendingOps();
      var queueDrained = true;
      if (pending.isNotEmpty) {
        phaseNotifier.value = SyncPhase.pushing;
        final ops = [
          for (final o in pending)
            if (o.remoteId != null) _toWireOp(o),
        ];
        await _api.push(bookId!, ops, accessToken: _tokens!.accessToken);
        await opLogger.markPushed([for (final o in pending) o.id]);
        // 注意：push 不推进游标。游标仅随 pull 前进，
        // 否则并发期间到达的其他客户端 op 会被自己的 push 游标跳过（数据丢失）。
        queueDrained = pending.length < 500;
      }

      phaseNotifier.value = SyncPhase.pulling;
      final since = await opLogger.lastSyncedSeq();
      final pull = await _api.pull(bookId!, since, accessToken: _tokens!.accessToken);
      // 本机 op 已物化到本地库，跳过避免重复建行
      final foreign = pull.ops.where((o) => o.clientId != ownClientId).toList();
      if (foreign.isNotEmpty) {
        phaseNotifier.value = SyncPhase.merging;
        // 解析必须把本机同实体 op 一并纳入：保证平局（同 lamport）时
        // 两端候选集一致 → 确定性收敛（评审 B1 收敛性修复）
        final own = await opLogger.ownOpsForRemoteIds(pull.ops.map((o) => o.entityId));
        await _merger.merge([
          ...foreign,
          ...own.map(_syncOpToRemoteOp),
        ]);
        // 合并中观察到的远端 lamport 参与本地时钟（因果序，评审 B2）
        await opLogger.recordRemoteLamports(foreign.map((o) => o.lamport));
      }
      if (pull.nextSeq > since) {
        await opLogger.setLastSyncedSeq(pull.nextSeq);
      }

      if (queueDrained && pull.ops.isEmpty) break;
    }
  }

  Map<String, dynamic> _toWireOp(SyncOp row) {
    return {
      'entity': row.entity,
      'entity_id': row.remoteId,
      'op': row.op.name,
      'payload': jsonDecode(row.payload),
      'lamport': row.lamport,
      'client_id': row.clientId,
    };
  }

  RemoteOp _syncOpToRemoteOp(SyncOp row) {
    return RemoteOp(
      entity: row.entity,
      entityId: row.remoteId!,
      op: row.op.name,
      lamport: row.lamport,
      clientId: row.clientId,
      payload: jsonDecode(row.payload) as Map<String, dynamic>?,
    );
  }
}
