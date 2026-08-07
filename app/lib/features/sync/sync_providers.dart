import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/constants.dart';
import '../../data/local/database.dart';
import '../../data/local/database_provider.dart';
import '../../data/repositories/op_logger.dart';
import '../books/books_providers.dart' show currentBookIdProvider;
import 'sync_api.dart';
import 'sync_engine.dart';
import 'sync_state.dart';
import 'token_store.dart';

/// 共享同步引擎持有者（审查 B-1 接线）：main() 启动时构建并 start()；
/// 设置页登录后复用；未登录纯本地降级。
SyncEngine? _sharedEngine;

SyncEngine? get sharedSyncEngine => _sharedEngine;

/// 构建共享引擎（幂等：已构建直接返回）。登录/登出会重建引擎。
SyncEngine ensureSharedSyncEngine({
  required AppDatabase db,
  required String bookId,
  TokenStore? tokenStore,
  SyncApi? api,
  String? email,
  String? password,
  void Function()? onMerged,
}) {
  final existing = _sharedEngine;
  if (existing != null) return existing;
  final engine = SyncEngine(
    opLogger: OpLogger(db),
    api: api ?? HttpSyncApi(baseUrl: kServerBaseUrl),
    tokenStore: tokenStore ?? SecureTokenStore(),
    bookId: bookId,
    email: email,
    password: password,
    onMerged: onMerged,
  );
  _sharedEngine = engine;
  engine.start();
  return engine;
}

/// 登出：清 token、停引擎，UI 回未登录态
Future<void> clearSharedSyncEngine() async {
  final engine = _sharedEngine;
  _sharedEngine = null;
  await engine?.dispose();
}

/// 同步 UI 状态：阶段 / 忙碌 / 消息（邮箱由设置页自行加载展示）
class SyncUiState {
  const SyncUiState({
    required this.phase,
    required this.busy,
    this.message,
  });

  final SyncPhase phase;
  final bool busy;
  final String? message;
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncUiState>(
  SyncStatusNotifier.new,
);

class SyncStatusNotifier extends Notifier<SyncUiState> {
  bool _busy = false;
  String? _message;
  SyncPhaseNotifier? _phaseSub;

  @override
  SyncUiState build() {
    _busy = false;
    _message = null;
    _phaseSub?.removeListener(_onPhase);
    final sub = sharedSyncEngine?.phaseNotifier;
    _phaseSub = sub;
    sub?.addListener(_onPhase);
    return _uiState();
  }

  SyncUiState _uiState() => SyncUiState(
        phase: _phaseSub?.value ?? SyncPhase.idle,
        busy: _busy,
        message: _message,
      );

  void _onPhase() {
    state = _uiState();
  }

  /// 登录/注册 → 持久化 token → 复用/重建引擎 → 立即同步追平 op-log
  Future<bool> login(String email, String password) async {
    final api = HttpSyncApi(baseUrl: kServerBaseUrl);
    final tokenStore = SecureTokenStore();
    TokenPair tokens;
    try {
      tokens = await api.login(email, password);
    } on SyncApiException catch (e) {
      try {
        if (e.statusCode == 401) {
          tokens = await api.register(email, password);
        } else if (e.statusCode == 409) {
          tokens = await api.login(email, password);
        } else {
          _setMessage('登录失败：${e.message}');
          return false;
        }
      } on SyncNetworkException catch (e2) {
        _setMessage('网络不可用：${e2.message}');
        return false;
      }
    } on SyncNetworkException catch (e) {
      _setMessage('网络不可用：${e.message}');
      return false;
    } catch (_) {
      _setMessage('登录失败，请重试');
      return false;
    }
    await tokenStore.write(tokens);
    await tokenStore.writeEmail(email);
    _busy = true;
    _onPhase();
    try {
      final engine = ensureSharedSyncEngine(
        db: ref.read(databaseProvider),
        bookId: ref.read(currentBookIdProvider),
        tokenStore: tokenStore,
        api: api,
        email: email,
        password: password,
      );
      await engine.sync();
      _message = '同步完成';
      return true;
    } on SyncNetworkException catch (e) {
      _message = '网络不可用，队列已保留（${e.message}）';
      return true;
    } catch (_) {
      _message = '登录成功，同步失败可稍后手动重试';
      return true;
    } finally {
      _busy = false;
      _onPhase();
    }
  }

  Future<void> logout() async {
    await SecureTokenStore().clear();
    await clearSharedSyncEngine();
    _message = null;
    _onPhase();
  }

  /// 手动同步
  Future<void> manualSync() async {
    final engine = sharedSyncEngine;
    if (engine == null) {
      _setMessage('未登录，请先登录');
      return;
    }
    _busy = true;
    _onPhase();
    try {
      await engine.sync();
      _message = '同步完成';
    } on SyncNetworkException {
      _message = '网络不可用，队列已保留';
    } catch (_) {
      _message = '同步失败，请重试';
    } finally {
      _busy = false;
      _onPhase();
    }
  }

  void _setMessage(String message) {
    _message = message;
    _onPhase();
  }
}
