import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/repositories/lock_repository.dart';
import 'package:bookkeep_app/features/auth_lock/biometric.dart';
import 'package:bookkeep_app/features/auth_lock/lock_controller.dart';

import '../../../helpers/sqlite.dart';

void main() {
  ensureSqliteLoaded();
  late AppDatabase db;
  late LockRepository repo;
  late FakeBiometricAuth bio;
  late DateTime now;
  late LockController controller;

  LockController create({bool initiallyLocked = false}) => LockController(
        repo,
        bio,
        initiallyLocked: initiallyLocked,
        initiallyBiometric: initiallyLocked,
        now: () => now,
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LockRepository(db);
    bio = FakeBiometricAuth();
    now = DateTime(2026, 8, 1, 12, 0, 0);
    controller = create();
  });

  tearDown(() => db.close());

  test('未配置时所有操作保持解锁态', () async {
    expect(controller.state.locked, isFalse);
    expect(controller.state.masked, isFalse);
    controller.appBackgrounded();
    expect(controller.state.masked, isFalse);
  });

  test('启用后解锁态，可立即锁定', () async {
    await controller.enable('123456');
    expect(controller.state.pinConfigured, isTrue);
    expect(controller.state.locked, isFalse);
    controller.lockNow();
    expect(controller.state.locked, isTrue);
    expect(controller.state.masked, isTrue);
  });

  group('自动上锁（后台 30s）', () {
    setUp(() async {
      await controller.enable('123456');
    });

    test('后台立即脱敏，30s 内回前台恢复', () {
      controller.appBackgrounded();
      expect(controller.state.masked, isTrue);
      now = now.add(const Duration(seconds: 29));
      controller.appResumed();
      expect(controller.state.locked, isFalse);
      expect(controller.state.masked, isFalse);
    });

    test('后台超过 30s 回前台自动锁定', () {
      controller.appBackgrounded();
      now = now.add(const Duration(seconds: 30));
      controller.appResumed();
      expect(controller.state.locked, isTrue);
      expect(controller.state.masked, isTrue);
    });

    test('后台超过 30s（秒级边界）', () {
      controller.appBackgrounded();
      now = now.add(const Duration(seconds: 31));
      controller.appResumed();
      expect(controller.state.locked, isTrue);
    });

    test('锁定期间不因重复生命周期事件改变状态', () {
      controller.lockNow();
      controller.appBackgrounded();
      expect(controller.state.locked, isTrue);
      now = now.add(const Duration(seconds: 1));
      controller.appResumed();
      expect(controller.state.locked, isTrue);
    });
  });

  group('解锁', () {
    setUp(() async {
      await controller.enable('123456');
      controller.lockNow();
    });

    test('正确 PIN 解锁', () async {
      expect(await controller.unlockWithPin('123456'), isTrue);
      expect(controller.state.locked, isFalse);
    });

    test('错误 PIN 保持锁定', () async {
      expect(await controller.unlockWithPin('654321'), isFalse);
      expect(controller.state.locked, isTrue);
    });

    test('生物识别解锁（设备支持）', () async {
      bio.supported = true;
      bio.result = true;
      expect(await controller.unlockWithBiometric(), isTrue);
      expect(controller.state.locked, isFalse);
      expect(bio.authenticateCalls, 1);
    });

    test('设备不支持生物识别时回退 PIN', () async {
      bio.supported = false;
      expect(await controller.unlockWithBiometric(), isFalse);
      expect(controller.state.locked, isTrue);
    });

    test('生物识别失败不解锁', () async {
      bio.result = false;
      expect(await controller.unlockWithBiometric(), isFalse);
      expect(controller.state.locked, isTrue);
    });
  });

  group('关闭/修改 PIN', () {
    test('错误 PIN 无法关闭', () async {
      await controller.enable('123456');
      expect(await controller.disable('000000'), isFalse);
      expect(controller.state.pinConfigured, isTrue);
    });

    test('正确 PIN 关闭隐私锁', () async {
      await controller.enable('123456');
      expect(await controller.disable('123456'), isTrue);
      expect(controller.state.pinConfigured, isFalse);
      expect(controller.state.locked, isFalse);
      expect(await repo.pinConfigured(), isFalse);
    });

    test('修改 PIN：旧 PIN 错误失败，正确后新 PIN 生效', () async {
      await controller.enable('123456');
      expect(await controller.changePin('000000', '654321'), isFalse);
      expect(await controller.changePin('123456', '654321'), isTrue);
      expect(await repo.verifyPin('654321'), isTrue);
      expect(await repo.verifyPin('123456'), isFalse);
    });

    test('关闭生物识别开关', () async {
      await controller.enable('123456');
      await controller.setBiometricEnabled(false);
      expect(controller.state.biometricEnabled, isFalse);
      expect(await controller.unlockWithBiometric(), isFalse);
    });
  });

  group('启动即锁（进程被杀重进仍锁）', () {
    test('配置过 PIN 的设备冷启动为锁定态', () async {
      await repo.setPin('123456');
      final s = await repo.initialState();
      final restarted = create(initiallyLocked: s.configured);
      expect(restarted.state.locked, isTrue);
      expect(restarted.state.masked, isTrue);
      // 解锁后正常使用
      expect(await restarted.unlockWithPin('123456'), isTrue);
      expect(restarted.state.locked, isFalse);
    });
  });
}
