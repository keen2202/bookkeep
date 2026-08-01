import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database_provider.dart';
import '../../data/repositories/lock_repository.dart';
import 'biometric.dart';

/// 后台自动上锁阈值（Spec §3.6：30s）
const autoLockAfter = Duration(seconds: 30);

/// 隐私锁状态（BK-T-008）
class LockState {
  const LockState({
    required this.pinConfigured,
    required this.biometricEnabled,
    required this.locked,
    this.backgroundedAt,
  });

  final bool pinConfigured;
  final bool biometricEnabled;
  final bool locked;
  final DateTime? backgroundedAt;

  /// 脱敏判定：锁定或后台驻留期间金额掩码显示（覆盖系统预览/切换快照）
  bool get masked => pinConfigured && (locked || backgroundedAt != null);

  LockState copyWith({bool? locked, DateTime? backgroundedAt, bool clearBackgrounded = false}) {
    return LockState(
      pinConfigured: pinConfigured,
      biometricEnabled: biometricEnabled,
      locked: locked ?? this.locked,
      backgroundedAt: clearBackgrounded ? null : (backgroundedAt ?? this.backgroundedAt),
    );
  }
}

/// 锁状态机：unlocked → masked（后台）→ locked（超时/手动）；解锁回 unlocked
class LockController extends StateNotifier<LockState> {
  LockController(
    this._repo,
    this._biometric, {
    required bool initiallyLocked,
    required bool initiallyBiometric,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        super(LockState(
          pinConfigured: initiallyLocked,
          biometricEnabled: initiallyBiometric,
          locked: initiallyLocked,
        ));

  final LockRepository _repo;
  final BiometricAuth _biometric;
  final DateTime Function() _now;

  Future<bool> unlockWithPin(String pin) async {
    if (!await _repo.verifyPin(pin)) return false;
    state = state.copyWith(locked: false, clearBackgrounded: true);
    return true;
  }

  Future<bool> unlockWithBiometric() async {
    if (!state.pinConfigured || !state.biometricEnabled) return false;
    if (!await _biometric.available()) return false;
    final ok = await _biometric.authenticate();
    if (ok) state = state.copyWith(locked: false, clearBackgrounded: true);
    return ok;
  }

  Future<void> enable(String pin) async {
    await _repo.setPin(pin);
    state = const LockState(
      pinConfigured: true,
      biometricEnabled: true,
      locked: false,
    );
  }

  /// 关闭隐私锁需先通过当前 PIN 校验
  Future<bool> disable(String pin) async {
    if (!await _repo.verifyPin(pin)) return false;
    await _repo.removePin();
    state = const LockState(pinConfigured: false, biometricEnabled: false, locked: false);
    return true;
  }

  /// 修改 PIN：旧 PIN 校验失败返回 false
  Future<bool> changePin(String oldPin, String newPin) async {
    if (!await _repo.verifyPin(oldPin)) return false;
    await _repo.setPin(newPin);
    return true;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _repo.setBiometricEnabled(enabled);
    state = LockState(
      pinConfigured: state.pinConfigured,
      biometricEnabled: enabled,
      locked: state.locked,
      backgroundedAt: state.backgroundedAt,
    );
  }

  void lockNow() {
    if (state.pinConfigured) state = state.copyWith(locked: true, clearBackgrounded: true);
  }

  /// 应用进入后台：立即脱敏（系统快照不泄露金额），记录时间用于超时判定
  void appBackgrounded() {
    if (!state.pinConfigured) return;
    state = state.copyWith(backgroundedAt: _now());
  }

  /// 应用回前台：后台 ≤ 30s 直接恢复；超过则要求解锁
  void appResumed() {
    if (!state.pinConfigured || state.backgroundedAt == null) return;
    final elapsed = _now().difference(state.backgroundedAt!);
    if (elapsed >= autoLockAfter) {
      state = state.copyWith(locked: true, clearBackgrounded: true);
    } else {
      state = state.copyWith(clearBackgrounded: true);
    }
  }
}

final lockRepositoryProvider = Provider<LockRepository>((ref) {
  return LockRepository(ref.watch(databaseProvider));
});

final biometricProvider = Provider<BiometricAuth>((ref) {
  return LocalAuthBiometric();
});

final lockControllerProvider = StateNotifierProvider<LockController, LockState>((ref) {
  return LockController(
    ref.watch(lockRepositoryProvider),
    ref.watch(biometricProvider),
    initiallyLocked: false,
    initiallyBiometric: false,
  );
});

/// 金额脱敏开关：锁定态或后台驻留期间为 true（列表/报表/账户，Spec §3.6）
final amountMaskProvider = Provider<bool>((ref) {
  return ref.watch(lockControllerProvider).masked;
});
