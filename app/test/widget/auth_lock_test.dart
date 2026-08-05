import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/repositories/lock_repository.dart';
import 'package:bookkeep_app/features/accounts/accounts_page.dart';
import 'package:bookkeep_app/features/auth_lock/biometric.dart';
import 'package:bookkeep_app/features/auth_lock/lock_controller.dart';
import 'package:bookkeep_app/features/auth_lock/lock_gate.dart';

/// 设置 PIN：PBKDF2 的 Future.delayed 让出点需真实事件循环（testWidgets 假时钟不推进），
/// 故经 runAsync 执行（BK-T-008）。
Future<void> setupPin(WidgetTester tester, LockRepository repo, String pin) =>
    tester.runAsync(() => repo.setPin(pin));

void main() {
  late AppDatabase db;
  late LockRepository repo;
  late FakeBiometricAuth bio;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LockRepository(db);
    bio = FakeBiometricAuth();
  });

  tearDown(() => db.close());

  Widget gateApp({required bool initiallyLocked, bool initiallyBiometric = false}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        biometricProvider.overrideWithValue(bio),
        lockControllerProvider.overrideWith((ref) => LockController(
              repo,
              bio,
              initiallyLocked: initiallyLocked,
              initiallyBiometric: initiallyBiometric,
            )),
      ],
      child: const MaterialApp(
        builder: lockGateBuilder,
        home: Scaffold(body: Center(child: Text('PRIVATE_CONTENT'))),
      ),
    );
  }

  /// 输入 PIN：逐键点击并推进假时钟，触发 PinPad 提交与 PBKDF2 让出点
  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump(const Duration(milliseconds: 30));
    }
    // 第 6 位触发 onSubmit：等待提交回调 + PIN 校验完成 + 状态重建
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  group('LockGate', () {
    testWidgets('未配置锁时直接显示内容', (tester) async {
      await tester.pumpWidget(gateApp(initiallyLocked: false));
      expect(find.text('PRIVATE_CONTENT'), findsOneWidget);
      expect(find.text('bookkeep 已锁定'), findsNothing);
    });

    testWidgets('锁定态显示锁屏并隐藏内容（杀进程重进仍锁）', (tester) async {
      await setupPin(tester, repo, '123456');
      await tester.pumpWidget(gateApp(initiallyLocked: true));
      await tester.pump();
      expect(find.text('bookkeep 已锁定'), findsOneWidget);
      expect(find.text('PRIVATE_CONTENT'), findsNothing);
    });

    testWidgets('正确 PIN 解锁后显示内容', (tester) async {
      await setupPin(tester, repo, '123456');
      await tester.pumpWidget(gateApp(initiallyLocked: true));
      await tester.pump();
      expect(find.text('bookkeep 已锁定'), findsOneWidget);

      await enterPin(tester, '123456');

      expect(find.text('PRIVATE_CONTENT'), findsOneWidget);
      expect(find.text('bookkeep 已锁定'), findsNothing);
    });

    testWidgets('错误 PIN 保持锁定并提示', (tester) async {
      await setupPin(tester, repo, '123456');
      await tester.pumpWidget(gateApp(initiallyLocked: true));
      await tester.pump();

      await enterPin(tester, '000000');

      expect(find.text('bookkeep 已锁定'), findsOneWidget);
      expect(find.text('PIN 错误，请重试'), findsOneWidget);
      expect(find.text('PRIVATE_CONTENT'), findsNothing);
    });

    testWidgets('生物识别解锁', (tester) async {
      await setupPin(tester, repo, '123456');
      bio.supported = true;
      bio.result = true;
      await tester.pumpWidget(gateApp(initiallyLocked: true, initiallyBiometric: true));
      await tester.pumpAndSettle();

      expect(find.text('生物识别解锁'), findsOneWidget);
      await tester.tap(find.text('生物识别解锁'));
      await tester.pumpAndSettle();

      expect(find.text('PRIVATE_CONTENT'), findsOneWidget);
      expect(bio.authenticateCalls, 1);
    });
  });

  group('金额脱敏（Spec §3.6）', () {
    testWidgets('后台驻留期间账户页金额掩码显示', (tester) async {
      await db.into(db.accounts).insert(AccountsCompanion.insert(
            accountType: AccountType.cash,
            name: '钱包',
            currency: 'CNY',
            createdAt: DateTime.utc(2026, 8, 1),
          ));

      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          biometricProvider.overrideWithValue(bio),
          lockControllerProvider.overrideWith((ref) => LockController(
                repo,
                bio,
                initiallyLocked: false,
                initiallyBiometric: false,
              )),
        ],
        child: const MaterialApp(home: AccountsPage()),
      ));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('¥0.00'), findsWidgets);

      // 启用隐私锁（解锁态，锁屏不遮挡）；PBKDF2 需真实事件循环
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AccountsPage)),
      );
      final notifier = container.read(lockControllerProvider.notifier);
      await tester.runAsync(() => notifier.enable('123456'));
      await tester.pump();
      expect(find.text('¥0.00'), findsWidgets);

      // 后台驻留：不锁定但金额脱敏
      notifier.appBackgrounded();
      await tester.pump();

      expect(find.text('¥***'), findsWidgets);
      expect(find.text('¥0.00'), findsNothing);
    });
  });
}
