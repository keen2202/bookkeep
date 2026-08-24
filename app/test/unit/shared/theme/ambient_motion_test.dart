import 'package:flutter/scheduler.dart' show Ticker;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/theme/glass/ambient_motion.dart';
import 'package:bookkeep_app/shared/theme/glass/glass_quality.dart';

void main() {
  // 控制器构造依赖 WidgetsBinding（observer 注册 + Ticker）
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AmbientMotionController：漂移（fake clock，AC-03）', () {
    test('36s 周期漂移：推进后光斑中心偏移 > 0', () {
      final c = AmbientMotionController(ticker: Ticker((_) {}));
      addTearDown(c.dispose);
      // 初始相位：blob 位于 anchor + orbit·sin/cos(0)，即轨道起点
      final initial = c.blobDriftOffset(0);
      c.advance(const Duration(seconds: 9));
      final offset = c.blobDriftOffset(0);
      expect((offset - initial).distance, greaterThan(0),
          reason: 'fake clock 推进 9s（1/4 周期）后应偏离初始位置');
      // 椭圆轨道约束：|dx| ≤ 0.06、|dy| ≤ 0.04
      expect(offset.dx.abs(), lessThanOrEqualTo(0.06 + 1e-9));
      expect(offset.dy.abs(), lessThanOrEqualTo(0.04 + 1e-9));
    });

    test('四光斑相位错开 90°：同一时刻偏移互不相同', () {
      final c = AmbientMotionController(ticker: Ticker((_) {}));
      addTearDown(c.dispose);
      c.advance(const Duration(seconds: 3));
      final offsets = [
        for (var i = 0; i < 4; i++) c.blobDriftOffset(i),
      ];
      expect(offsets.toSet().length, 4, reason: '相位错开 π/2');
    });

    test('周期无缝：36s 后回到初始相位（正弦往复无接缝）', () {
      final c = AmbientMotionController(ticker: Ticker((_) {}));
      addTearDown(c.dispose);
      final initial = c.blobDriftOffset(0);
      c.advance(const Duration(seconds: 36));
      expect((c.blobDriftOffset(0) - initial).distance, lessThan(1e-6));
    });
  });

  group('pulse / breathe', () {
    test('push 脉冲：+3% 位移 600ms easeOutCubic 归位', () {
      final c = AmbientMotionController(ticker: Ticker((_) {}));
      addTearDown(c.dispose);
      c.pulse(direction: const Offset(0, -1));
      expect(c.pulseOffset.dy, closeTo(-0.03, 1e-9), reason: '满幅 +3%');
      c.advance(const Duration(milliseconds: 300));
      final mid = c.pulseOffset.dy.abs();
      expect(mid, lessThan(0.03), reason: 'easeOutCubic 衰减中');
      expect(mid, greaterThan(0));
      c.advance(const Duration(milliseconds: 300));
      expect(c.pulseOffset, Offset.zero, reason: '600ms 归位');
    });

    test('Tab 呼吸：强度 ×0.5 → 1.0（500ms）', () {
      final c = AmbientMotionController(ticker: Ticker((_) {}));
      addTearDown(c.dispose);
      c.breathe();
      expect(c.breatheScale, closeTo(0.5, 1e-9));
      c.advance(const Duration(milliseconds: 250));
      expect(c.breatheScale, inExclusiveRange(0.5, 1.0));
      c.advance(const Duration(milliseconds: 250));
      expect(c.breatheScale, closeTo(1.0, 1e-6));
    });

    test('背景图模式默认不发脉冲；手动开启后放行（§4.6）', () {
      final c = AmbientMotionController(ticker: Ticker((_) {}));
      addTearDown(c.dispose);
      c.configure(imageMode: true);
      c.pulse(direction: const Offset(1, 0));
      expect(c.pulseOffset, Offset.zero, reason: 'imageMode 默认关脉冲');
      c.configure(imagePulseEnabled: true);
      c.pulse(direction: const Offset(1, 0));
      expect(c.pulseOffset.dx, greaterThan(0), reason: '用户手开后放行');
    });
  });

  group('GLS-013 动效降级矩阵（任一条件成立即完全静止）', () {
    test('① disableAnimations → 静止于初始相位且 pulse 无效', () {
      final c = AmbientMotionController(ticker: Ticker((_) {}));
      addTearDown(c.dispose);
      c.advance(const Duration(seconds: 10));
      expect(c.animate, isTrue);
      c.configure(animationsDisabled: true);
      expect(c.animate, isFalse);
      expect(c.phaseSeconds, 0, reason: '复位初始相位');
      c.pulse(direction: const Offset(0, -1));
      expect(c.pulseOffset, Offset.zero, reason: '禁用动效时不发脉冲');
    });

    test('② quality==saver → 静止', () {
      final c = AmbientMotionController(ticker: Ticker((_) {}));
      addTearDown(c.dispose);
      c.advance(const Duration(seconds: 5));
      c.configure(quality: GlassQuality.saver);
      expect(c.animate, isFalse);
      expect(c.phaseSeconds, 0);
      c.breathe();
      expect(c.breatheScale, 1.0, reason: 'saver 下 breathe 不生效');
    });

    test('③ 设置关动效 → 静止', () {
      final c = AmbientMotionController(ticker: Ticker((_) {}));
      addTearDown(c.dispose);
      c.configure(motionEnabled: false);
      expect(c.animate, isFalse);
      c.advance(const Duration(seconds: 5));
      expect(c.phaseSeconds, 0);
    });

    test('④ 应用后台（WidgetsBindingObserver lifecycle）→ 静止；恢复继续', () {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      final c = AmbientMotionController(ticker: Ticker((_) {}));
      addTearDown(() => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
      addTearDown(c.dispose);
      c.advance(const Duration(seconds: 2));
      // 经 WidgetsBindingObserver 验证后台暂停（lifecycle 回调同步分发）
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(c.isBackgrounded, isTrue);
      expect(c.animate, isFalse);
      expect(c.phaseSeconds, 0);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(c.isBackgrounded, isFalse);
      expect(c.animate, isTrue);
      c.advance(const Duration(seconds: 2));
      expect(c.phaseSeconds, greaterThan(0));
    });

    test('⑤ 锁定态 → 静止', () {
      final c = AmbientMotionController(ticker: Ticker((_) {}));
      addTearDown(c.dispose);
      c.configure(locked: true);
      expect(c.animate, isFalse);
      expect(c.phaseSeconds, 0);
    });

    test('降级解除后恢复动画', () {
      final c = AmbientMotionController(ticker: Ticker((_) {}));
      addTearDown(c.dispose);
      c.configure(motionEnabled: false);
      expect(c.animate, isFalse);
      c.configure(motionEnabled: true);
      expect(c.animate, isTrue);
      c.advance(const Duration(seconds: 1));
      expect(c.blobDriftOffset(0).distance, greaterThan(0));
    });
  });
}
