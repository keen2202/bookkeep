import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'glass_quality.dart';

/// 环境光动效控制器（Glassmorphism v3，Spec §4.2 / 设计文档 §4.2，GLS-012）：
/// 单控制器驱动全部背景动效（D4：不重建 Widget 树，成本锁死在背景层
/// RepaintBoundary 内的 CustomPainter 重绘）。
///
/// - **漂移**：36s/光斑 周期椭圆轨道（半轴 = 光斑尺寸 × (6%, 4%)），
///   相位错开 90°，sin/cos 正弦往复、无关键帧跳变、无限循环无接缝；
/// - **pulse**：push/pop 时全体光斑沿导航方向位移 +3%，600ms easeOutCubic 归位；
/// - **breathe**：Tab 切换强度 ×0.5 → 1.0，500ms；
/// - **关闭条件**（任一成立即停止 Ticker 并静止于初始相位）：
///   `disableAnimations`、quality==saver、设置关动效、App 后台、锁定态
///   （GLS-013 动效降级矩阵，各条件独立单元用例）。
class AmbientMotionController extends ChangeNotifier with WidgetsBindingObserver {
  /// [ticker] 仅供测试注入；生产使用默认 [Ticker]。
  AmbientMotionController({Ticker? ticker})
      : _injectedTicker = ticker {
    _ticker = _injectedTicker ?? Ticker(_onTick);
    WidgetsBinding.instance.addObserver(this);
  }

  final Ticker? _injectedTicker;
  late final Ticker _ticker;

  // ── 漂移参数（设计文档 §4.2 表）──

  /// 漂移周期（36s / 光斑）
  static const double driftPeriodSeconds = 36;

  /// 椭圆轨道半轴（占光斑尺寸比例）：长轴 ×6% / 短轴 ×4%
  static const double orbitXFactor = 0.06;
  static const double orbitYFactor = 0.04;

  /// 相位错开量（4 光斑均分周期）
  static const double phaseStep = math.pi / 2;

  /// pulse 幅度（+3%）与回弹时长（600ms easeOutCubic）
  static const double pulseAmplitude = 0.03;
  static const Duration pulseDuration = Duration(milliseconds: 600);

  /// breathe 时长（强度 ×0.5 → 1.0，500ms）
  static const Duration breatheDuration = Duration(milliseconds: 500);

  // ── 关闭条件状态位 ──
  
  /// 环境级强制静止闩（flutter test 下由 [AmbientMotion.instance] 置位；
  /// 渲染侧的 configure 无法解除——无限漂移 Ticker 会令 pumpAndSettle 永不收敛）
  bool _forceDisabled = false;
  bool _motionEnabled = true;
  bool _animationsDisabled = false;
  bool _locked = false;
  bool _backgrounded = false;
  GlassQuality _quality = GlassQuality.standard;
  bool _imageMode = false;
  bool _imagePulseEnabled = false;

  /// 是否处于动画有效态（任一关闭条件成立即 false）
  bool get animate =>
      !_forceDisabled &&
      _motionEnabled &&
      !_animationsDisabled &&
      !_locked &&
      !_backgrounded &&
      _quality != GlassQuality.saver;

  /// 测试环境强制静止（仅 [AmbientMotion.instance] 初始化时置一次）
  set forceDisabled(bool v) => _forceDisabled = v;

  bool get isBackgrounded => _backgrounded;
  bool get locked => _locked;
  bool get imageMode => _imageMode;

  /// 累计漂移相位（秒）；关闭时静止于初始相位 0
  double get phaseSeconds => _phaseSeconds;
  double _phaseSeconds = 0;

  Duration? _pulseElapsed;
  Offset? _pulseDirection;
  Duration? _breatheElapsed;
  Duration? _lastElapsed;

  /// 配置同步（渲染侧在 build 中按当前偏好/环境调用；状态翻转即启停
  /// Ticker）。不在 build 期同步通知监听者（避免 build 中 markNeedsPaint
  /// 断言），关闭态的重置由下一帧回调兜底刷新画布。
  void configure({
    bool? motionEnabled,
    bool? animationsDisabled,
    bool? locked,
    GlassQuality? quality,
    bool? imageMode,
    bool? imagePulseEnabled,
  }) {
    var changed = false;
    if (motionEnabled != null && motionEnabled != _motionEnabled) {
      _motionEnabled = motionEnabled;
      changed = true;
    }
    if (animationsDisabled != null &&
        animationsDisabled != _animationsDisabled) {
      _animationsDisabled = animationsDisabled;
      changed = true;
    }
    if (locked != null && locked != _locked) {
      _locked = locked;
      changed = true;
    }
    if (imageMode != null && imageMode != _imageMode) {
      _imageMode = imageMode;
      changed = true;
    }
    if (imagePulseEnabled != null && imagePulseEnabled != _imagePulseEnabled) {
      _imagePulseEnabled = imagePulseEnabled;
      changed = true;
    }
    if (quality != null && quality != _quality) {
      _quality = quality;
      changed = true;
    }
    if (changed) _syncTicker(notifyAfterFrame: true);
  }

  /// 页面切换脉冲（[AmbientRouteObserver] didPush/didPop 触发）：
  /// 背景图模式下默认不发脉冲（§4.6），用户手动开启后放行。
  void pulse({required Offset direction}) {
    if (!animate) return;
    if (_imageMode && !_imagePulseEnabled) return;
    _pulseDirection = direction;
    _pulseElapsed = Duration.zero;
    _syncTicker();
    notifyListeners();
  }

  /// Tab 切换呼吸（shell 回调触发）
  void breathe() {
    if (!animate) return;
    _breatheElapsed = Duration.zero;
    _syncTicker();
    notifyListeners();
  }

  /// 第 [index] 个光斑的椭圆轨道漂移偏移（占其尺寸分数）：
  /// position = anchor + orbit · sin/cos(2π·t/36 + index·90°)
  Offset blobDriftOffset(int index) {
    final angle =
        2 * math.pi * (_phaseSeconds / driftPeriodSeconds) + index * phaseStep;
    return Offset(
      orbitXFactor * math.sin(angle),
      orbitYFactor * math.cos(angle),
    );
  }

  /// 当前 pulse 位移（屏幕分数单位；未触发/已完成归零）
  Offset get pulseOffset {
    final elapsed = _pulseElapsed;
    final direction = _pulseDirection;
    if (elapsed == null || direction == null) return Offset.zero;
    final t =
        (elapsed.inMicroseconds / pulseDuration.inMicroseconds).clamp(0.0, 1.0);
    // +3% 位移，easeOutCubic 回弹归位
    return direction * (pulseAmplitude * (1 - Curves.easeOutCubic.transform(t)));
  }

  /// breathe 强度乘子（触发后 ×0.5 → 1.0；静止时 1.0）
  double get breatheScale {
    final elapsed = _breatheElapsed;
    if (elapsed == null) return 1.0;
    final t = (elapsed.inMicroseconds / breatheDuration.inMicroseconds)
        .clamp(0.0, 1.0);
    return 0.5 + 0.5 * Curves.easeOutCubic.transform(t);
  }

  /// Ticker 启停同步：animate 即运行（漂移常驻），否则停表并复位初始相位
  void _syncTicker({bool notifyAfterFrame = false}) {
    if (animate) {
      if (!_ticker.isActive) {
        _lastElapsed = null;
        _ticker.start();
      }
    } else {
      if (_ticker.isActive) _ticker.stop();
      // 关闭条件生效：静止于初始相位（Spec §4.2）
      _phaseSeconds = 0;
      _pulseElapsed = null;
      _pulseDirection = null;
      _breatheElapsed = null;
      _lastElapsed = null;
      if (notifyAfterFrame) {
        SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
        SchedulerBinding.instance.ensureVisualUpdate();
      } else {
        notifyListeners();
      }
    }
  }

  /// Ticker 心跳：按真实帧间隔推进相位与过渡计时器
  void _onTick(Duration elapsed) {
    final delta =
        _lastElapsed == null ? Duration.zero : elapsed - _lastElapsed!;
    _lastElapsed = elapsed;
    if (!animate) return;
    advance(delta);
  }

  /// 推进内部时钟（测试用 fake clock 入口：直接喂入增量断言确定性输出）
  @visibleForTesting
  void advance(Duration delta) {
    if (!animate) return;
    _phaseSeconds += delta.inMicroseconds / Duration.microsecondsPerSecond;
    if (_pulseElapsed != null) {
      _pulseElapsed = _pulseElapsed! + delta;
      if (_pulseElapsed! >= pulseDuration) {
        _pulseElapsed = null;
        _pulseDirection = null;
      }
    }
    if (_breatheElapsed != null) {
      _breatheElapsed = _breatheElapsed! + delta;
      if (_breatheElapsed! >= breatheDuration) _breatheElapsed = null;
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _backgrounded = false;
      case AppLifecycleState.inactive ||
            AppLifecycleState.paused ||
            AppLifecycleState.hidden ||
            AppLifecycleState.detached:
        _backgrounded = true;
    }
    _syncTicker(notifyAfterFrame: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ticker.isActive) _ticker.stop();
    _ticker.dispose();
    super.dispose();
  }
}

/// 环境光动效入口（应用生命周期单例）：背景层唯一动效源。
/// 单例常驻——路由切换不丢相位；测试可经 [inject] 换成受控实例。
class AmbientMotion {
  AmbientMotion._();

  static AmbientMotionController? _instance;

  /// 生产入口：懒创建全局单例。
  /// flutter test 环境下自动禁用动效（TestWidgetsFlutterBinding 检测）——
  /// 无限漂移 Ticker 会令 pumpAndSettle 永不收敛；Golden 断言静态帧，
  /// 视觉不受影响（光斑绘制与动画解耦）。单元测试用直接构造的控制器，
  /// 不经过本入口，降级矩阵用例不受影响。
  static AmbientMotionController get instance {
    if (_instance != null) return _instance!;
    final controller = AmbientMotionController();
    // 不直接依赖 flutter_test（dev 依赖）：按绑定运行类型识别测试环境
    final bindingType = WidgetsBinding.instance.runtimeType.toString();
    if (bindingType.contains('TestWidgetsFlutterBinding')) {
      controller.forceDisabled = true;
    }
    return _instance = controller;
  }

  /// 测试注入受控实例（返回旧实例便于恢复；传 null 仅清除）
  static AmbientMotionController? inject(AmbientMotionController? controller) {
    final old = _instance;
    _instance = controller;
    return old;
  }
}

/// 环境光路由观察者（Spec §4.2 触发源）：didPush/didPop 发方向脉冲。
/// 由壳层创建并挂入 MaterialApp.navigatorObservers（秒开入口共用同一
/// shell builder，observer 挂 navigator 层天然共享）。
class AmbientRouteObserver extends NavigatorObserver {
  AmbientRouteObserver({required this.onPulse});

  /// 方向脉冲回调（direction 为导航语义方向：push 向上、pop 向下）
  final void Function(Offset direction) onPulse;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPulse(const Offset(0, -1));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPulse(const Offset(0, 1));
  }
}
