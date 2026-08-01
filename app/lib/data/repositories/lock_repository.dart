import 'package:drift/drift.dart';

import '../local/database.dart';
import '../../core/security/pin_hash.dart';

/// 隐私锁持久化（app_meta；Spec §3.6 / BK-T-008）
class LockRepository {
  LockRepository(this.db);
  final AppDatabase db;

  static const _pinHashKey = 'privacy_pin_hash';
  static const _biometricKey = 'privacy_biometric_enabled';

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
  }

  /// 校验 PIN；哈希缺失（未配置）返回 false
  Future<bool> verifyPin(String pin) async {
    final stored = await _get(_pinHashKey);
    if (stored == null) return false;
    return verifyPinHash(pin, stored);
  }

  Future<void> removePin() async {
    await _remove(_pinHashKey);
    await _remove(_biometricKey);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _set(_biometricKey, '$enabled');
  }
}
