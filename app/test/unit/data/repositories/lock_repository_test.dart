import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/repositories/lock_repository.dart';

void main() {
  late AppDatabase db;
  late LockRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LockRepository(db);
  });

  tearDown(() => db.close());

  test('未配置时 initialState 为未锁定', () async {
    final s = await repo.initialState();
    expect(s.configured, isFalse);
    expect(s.biometricEnabled, isFalse);
  });

  test('设置 PIN 后开启；校验正确/错误；生物识别默认开启', () async {
    await repo.setPin('135790');
    final s = await repo.initialState();
    expect(s.configured, isTrue);
    expect(s.biometricEnabled, isTrue);
    expect(await repo.verifyPin('135790'), isTrue);
    expect(await repo.verifyPin('135791'), isFalse);
    expect(await repo.verifyPin(''), isFalse);
  });

  test('关闭后清除哈希与生物识别开关', () async {
    await repo.setPin('135790');
    await repo.removePin();
    expect(await repo.pinConfigured(), isFalse);
    expect(await repo.initialState(), (configured: false, biometricEnabled: false));
  });

  test('生物识别开关持久化', () async {
    await repo.setPin('135790');
    await repo.setBiometricEnabled(false);
    final s = await repo.initialState();
    expect(s.configured, isTrue);
    expect(s.biometricEnabled, isFalse);
  });

  test('存储值不含明文 PIN', () async {
    await repo.setPin('135790');
    final rows = await (db.select(db.appMeta)).get();
    final values = rows.map((r) => r.value).join('\n');
    expect(values, isNot(contains('135790')));
  });

  test('连续失败 5 次进入 30s 冷却；成功后清零（Spec R-07）', () async {
    await repo.setPin('135790');
    final base = DateTime(2026, 1, 1, 12, 0, 0);
    for (var i = 0; i < 4; i++) {
      expect(await repo.verifyPin('000000', now: base), isFalse);
      expect(await repo.isLockedOut(now: base), isFalse);
    }
    expect(await repo.verifyPin('000000', now: base), isFalse);
    expect(await repo.isLockedOut(now: base), isTrue);
    // 冷却中正确 PIN 也拒绝
    expect(await repo.verifyPin('135790', now: base.add(const Duration(seconds: 5))), isFalse);
    // 冷却结束
    expect(
      await repo.verifyPin('135790', now: base.add(const Duration(seconds: 31))),
      isTrue,
    );
    expect(await repo.pinFailCount(), 0);
  });
}
