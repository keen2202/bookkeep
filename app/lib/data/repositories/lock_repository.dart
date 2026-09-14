import 'package:drift/drift.dart';

import '../local/database.dart';
import '../../core/security/pin_hash.dart';

/// 隐私锁持久化（app_meta；Spec §3.6 / BK-T-008）
class LockRepository {
  LockRepository(this.db);
  final AppDatabase db;

  static const _pinHashKey = 'privacy_pin_hash';
  static const _biometricKey = 'privacy_biometric_enabled';
  static const _failsKey = 'privacy_pin_fails';
  static const _lockUntilKey = 'privacy_pin_lock_until';

  /// 连续失败 ≥5 锁 30s，≥10 锁 5min（Spec R-07）
  static const failThresholdSoft = 5;
  static const failThresholdHard = 10;
  static const lockDurationSoft = Duration(seconds: 30);
  static const lockDurationHard = Duration(minutes: 5);

  Future<String?> _get(String key) async {
    final rows = await (db.select(db.appMeta)..where((t) => t.key.equals(key))).get();
    return rows.isEmpty ? null : rows.single.value;
  }

  Future<void> _set(String key, String value) async {
    await db.into(db.appMeta).insert(
          AppMetaCompanion.insert(key: key, value: value),
          onConflict: DoUpdate((_) => AppMetaCompanion(value: Value(value))),
        );
  }

  Future<void> _remove(String key) async {
    await (db.delete(db.appMeta)..where((t) => t.key.equals(key))).go();
  }

  /// 启动初始状态（进程被杀重进仍锁：pinConfigured → 启动即锁定）
  Future<({bool configured, bool biometricEnabled})> initialState() async {
    final configured = await pinConfigured();
    if (!configured) return (configured: false, biometricEnabled: false);
    final bio = await _get(_biometricKey) == 'true';
    return (configured: true, biometricEnabled: bio);
  }

  Future<bool> pinConfigured() async => await _get(_pinHashKey) != null;

  Future<void> setPin(String pin) async {
    final stored = await hashPin(pin);
    await _set(_pinHashKey, stored);
    await _set(_biometricKey, 'true');
    await clearPinAttempts();
  }

  /// 当前是否处于 PIN 试错冷却期
  Future<bool> isLockedOut({DateTime? now}) async {
    final raw = await _get(_lockUntilKey);
    if (raw == null) return false;
    final until = DateTime.tryParse(raw)?.toLocal();
    if (until == null) return false;
    return (now ?? DateTime.now()).isBefore(until);
  }

  Future<int> pinFailCount() async => int.tryParse(await _get(_failsKey) ?? '') ?? 0;

  /// 冷却截止时间（null 表示未锁定）
  Future<DateTime?> pinLockUntil() async {
    final raw = await _get(_lockUntilKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> clearPinAttempts() async {
    await _remove(_failsKey);
    await _remove(_lockUntilKey);
  }

  Future<void> recordPinFailure({DateTime? now}) async {
    final fails = await pinFailCount() + 1;
    await _set(_failsKey, '$fails');
    final n = now ?? DateTime.now();
    if (fails >= failThresholdHard) {
      await _set(_lockUntilKey, n.add(lockDurationHard).toIso8601String());
    } else if (fails >= failThresholdSoft) {
      await _set(_lockUntilKey, n.add(lockDurationSoft).toIso8601String());
    }
  }

  /// 校验 PIN；哈希缺失（未配置）或冷却中返回 false
  Future<bool> verifyPin(String pin, {DateTime? now}) async {
    if (await isLockedOut(now: now)) return false;
    final stored = await _get(_pinHashKey);
    if (stored == null) return false;
    final ok = await verifyPinHash(pin, stored);
    if (ok) {
      await clearPinAttempts();
    } else {
      await recordPinFailure(now: now);
    }
    return ok;
  }

  Future<void> removePin() async {
    await _remove(_pinHashKey);
    await _remove(_biometricKey);
    await clearPinAttempts();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _set(_biometricKey, '$enabled');
  }
}
