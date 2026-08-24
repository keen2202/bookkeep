import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';
import 'glass_layers.dart';
import 'glass_quality.dart';

/// 背景图模式作用域（Spec §4.6）：AppBackground 在内容层外注入，
/// GlassPanel 据此对 L1 填充加厚 +0.06（上限 0.80）。未注入时视为关闭。
class GlassImageModeScope extends InheritedWidget {
  const GlassImageModeScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  /// 向上查找背景图模式；无作用域（纯组件测试等）按关闭处理
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GlassImageModeScope>()
          ?.enabled ??
      false;

  @override
  bool updateShouldNotify(GlassImageModeScope oldWidget) =>
      oldWidget.enabled != enabled;
}

/// 玻璃个性化作用域（GLS-014 渲染桥）：AppBackground 把持久化偏好投影为
/// InheritedWidget——背景/玻璃渲染层只消费作用域值，不依赖 Provider 容器
/// （纯组件测试与 Golden 无需 ProviderScope）。
class GlassPrefsScope extends InheritedWidget {
  const GlassPrefsScope({
    super.key,
    required this.motionEnabled,
    required this.intensity,
    required super.child,
  });

  /// 环境光动效总开关（用户偏好）
  final bool motionEnabled;

  /// 用户请求的光斑强度（ContrastGuard 钳制在 AmbientGradient 内完成）
  final AmbientIntensity intensity;

  static GlassPrefsScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassPrefsScope>() ??
      const GlassPrefsScope(
        motionEnabled: true,
        intensity: AmbientIntensity.standard,
        child: SizedBox.shrink(),
      );

  @override
  bool updateShouldNotify(GlassPrefsScope oldWidget) =>
      oldWidget.motionEnabled != motionEnabled ||
      oldWidget.intensity != intensity;
}

/// 锁定态作用域（GLS-013 降级矩阵）：壳层（app.dart builder）注入真实锁状态，
/// AmbientGradient 据此静止；未注入（测试）按未锁定处理。
class AmbientLockScope extends InheritedWidget {
  const AmbientLockScope({
    super.key,
    required this.locked,
    required super.child,
  });

  final bool locked;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AmbientLockScope>()?.locked ??
      false;

  @override
  bool updateShouldNotify(AmbientLockScope oldWidget) =>
      oldWidget.locked != locked;
}

/// ContrastGuard 兜底增量作用域（Spec §4.5）：AmbientGradient 把钳制后的
/// 运行时填充增量下发给玻璃面板（panel 层生效；不写盘、不改用户设置；
/// 当前全部预设达标时恒为 0）。
class GlassGuardScope extends InheritedWidget {
  const GlassGuardScope({
    super.key,
    required this.extraFillAlpha,
    required super.child,
  });

  final double extraFillAlpha;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GlassGuardScope>()
          ?.extraFillAlpha ??
      0;

  @override
  bool updateShouldNotify(GlassGuardScope oldWidget) =>
      oldWidget.extraFillAlpha != extraFillAlpha;
}

/// 玻璃面板（Glassmorphism v3，Spec §3）：L1–L4 四层通用的唯一玻璃容器出口
/// （D1：一个出口保证一致性，降级只改一处）。
///
/// 渲染顺序（Spec §3.1）：
/// `阴影层 → ClipRRect → BackdropFilter(σ, Clip.hardEdge) →
///  Container(fill+border) → ForegroundDecoration(topHighlight
///  [, innerSheen]) → child`；
///
/// - σ=0（standard 档 L1/L2 主路径）时跳过 ClipRRect+BackdropFilter 直接
///   渲染——零 saveLayer（D2 列表性能决策，widget 树断言锁定）；
/// - BackdropFilter 双保险裁剪（Spec §3.2）：`clipBehavior: Clip.hardEdge`
///   保证矩形采样边界不溢出模糊光晕，圆角由外层 ClipRRect 承担，
///   二者缺一不可（BackdropFilter 自身 clipBehavior 不支持圆角形状）；
/// - 交互态（Spec §3.1 行为三）：hover 描边 α+0.08 / 高光 +0.05
///   （120ms easeOut）；按压填充叠加 scrim α0.04（150ms）；
/// - [innerSheen]：图表容器专属底部微反光（§5.4），任何画质档恒开。
class GlassPanel extends StatefulWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.tier = GlassTier.panel,
    this.borderRadius,
    this.onTap,
    this.padding,
    this.colorOverride,
    this.blurOverride,
    this.innerSheen = false,
  });

  final Widget child;

  /// 玻璃层级（默认 L1 内容面板层）
  final GlassTier tier;

  /// 圆角（默认卡片 md；L3 弹层传 lg）
  final BorderRadius? borderRadius;

  /// 传入即可点（水波纹 + 按压 scrim + hover 三态过渡）
  final VoidCallback? onTap;

  /// 内边距（不传则由调用方自管）
  final EdgeInsetsGeometry? padding;

  /// 覆盖填充色（默认层级解析值；传不透明色可关闭通透感）
  final Color? colorOverride;

  /// 覆盖模糊 σ（null=按画质档解析；0=强制 fill-only）
  final double? blurOverride;

  /// 图表容器底部微反光（玻璃厚度反光，单 drawRect）
  final bool innerSheen;

  @override
  State<GlassPanel> createState() => _GlassPanelState();
}

class _GlassPanelState extends State<GlassPanel> {
  bool _hover = false;
  bool _press = false;

  void _setHover(bool v) {
    if (_hover != v) setState(() => _hover = v);
  }

  void _setPress(bool v) {
    if (_press != v) setState(() => _press = v);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final imageMode = GlassImageModeScope.of(context);
    var spec = resolveGlassSpec(
      tier: widget.tier,
      brightness: tokens.brightness,
      palette: tokens.palette,
      quality: tokens.glassQuality,
      imageBackgroundMode: imageMode,
    );
    if (widget.blurOverride != null) {
      spec = GlassSpec(
        fill: spec.fill,
        sigmaX: widget.blurOverride!,
        sigmaY: widget.blurOverride!,
        borderColor: spec.borderColor,
        topHighlight: spec.topHighlight,
        highlightAlphaTop: spec.highlightAlphaTop,
        shadows: spec.shadows,
      );
    }

    // 交互态解析（Spec §3.1 行为三）：hover 描边 α+0.08 / 高光 +0.05；
    // 按压填充叠加 scrim α0.04（lerp 近似合成，保持装饰可动画化）
    var borderColor = spec.borderColor;
    var highlightAlpha = spec.highlightAlphaTop;
    if (_hover) {
      borderColor =
          Colors.white.withValues(alpha: (spec.borderColor.a + 0.08).clamp(0.0, 1.0));
      highlightAlpha = (highlightAlpha + 0.05).clamp(0.0, 1.0);
    }
    var fill = widget.colorOverride ?? spec.fill;
    // ContrastGuard 兜底（Spec §4.5）：panel 层运行时叠加钳制增量
    if (widget.tier == GlassTier.panel) {
      final guardExtra = GlassGuardScope.of(context);
      if (guardExtra > 0 && widget.colorOverride == null) {
        fill = fill.withValues(alpha: (fill.a + guardExtra).clamp(0.0, 1.0));
      }
    }
    if (_press) fill = Color.lerp(fill, Colors.black, 0.04)!;

    final radius = widget.borderRadius ?? AppRadius.mdAll;
    final duration = Duration(milliseconds: _press ? 150 : 120);

    final foreground = _GlassForegroundDecoration(
      topGradient: spec.topHighlight == null
          ? null
          : LinearGradient(
              begin: Alignment.topCenter,
              end: const Alignment(0, 0.45),
              colors: [
                Colors.white.withValues(alpha: highlightAlpha),
                Colors.white.withValues(alpha: 0),
              ],
            ),
      solidLineAlpha: spec.topHighlight == null ? highlightAlpha : null,
      innerSheen: widget.innerSheen,
      radius: radius,
    );

    // 表面容器：填充 + 描边 + 前景高光（hover/press 过渡 120/150ms easeOut）
    final surface = AnimatedContainer(
      key: const ValueKey('glass-surface'),
      duration: duration,
      curve: Curves.easeOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: AppGlass.borderWidth),
      ),
      foregroundDecoration: foreground,
      child: widget.child,
    );

    // 阴影独立于裁剪层之外（避免 ClipRRect 裁掉阴影，GlassIcon 同款结构）
    Widget content = DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: spec.shadows),
      child: spec.isFillOnly
          ? surface
          : ClipRRect(
              key: const ValueKey('glass-clip'),
              borderRadius: radius,
              child: BackdropFilter(
                key: const ValueKey('glass-blur'),
                // 双保险裁剪（Spec §3.2）：bounded blur 只从对象边界矩形内
                // 采样，杜绝圆角外侧溢出模糊光晕（本 SDK 中即旧版
                // BackdropFilter(clipBehavior: Clip.hardEdge) 的等价 API）；
                // 圆角形状由外层 ClipRRect 承担，二者缺一不可。
                filterConfig: ImageFilterConfig.blur(
                  sigmaX: spec.sigmaX,
                  sigmaY: spec.sigmaY,
                  bounded: true,
                ),
                child: surface,
              ),
            ),
    );

    if (widget.onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPress(true),
          onTapUp: (_) => _setPress(false),
          onTapCancel: () => _setPress(false),
          onTap: widget.onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}

/// 面板前景装饰：顶部高光（渐变或 solidLine 双细线）+ 图表 innerSheen。
/// 仅一次带 shader 的 drawRect/层，无 saveLayer、无独立图层
/// （Spec §3.2 成本论证：视口面板 ≤8 时净增 <0.1ms；列表行不使用本组件）。
class _GlassForegroundDecoration extends Decoration {
  const _GlassForegroundDecoration({
    this.topGradient,
    this.solidLineAlpha,
    required this.innerSheen,
    required this.radius,
  });

  /// 顶部高光渐变（gradient 模式）；solidLine 模式为 null
  final Gradient? topGradient;

  /// solidLine 模式顶部实线强度（1px 实线 + 其下 1px 半强线）
  final double? solidLineAlpha;

  /// 图表容器底部微反光（Spec §5.4）
  final bool innerSheen;

  final BorderRadius radius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _GlassForegroundPainter(this);

  @override
  bool operator ==(Object other) =>
      other is _GlassForegroundDecoration &&
      other.topGradient == topGradient &&
      other.solidLineAlpha == solidLineAlpha &&
      other.innerSheen == innerSheen &&
      other.radius == radius;

  @override
  int get hashCode =>
      Object.hash(topGradient, solidLineAlpha, innerSheen, radius);
}

class _GlassForegroundPainter extends BoxPainter {
  _GlassForegroundPainter(this.decoration);

  final _GlassForegroundDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final rect = offset & size;
    final r = decoration.radius;
    final clip = RRect.fromRectAndCorners(
      rect,
      topLeft: r.topLeft,
      topRight: r.topRight,
      bottomLeft: r.bottomLeft,
      bottomRight: r.bottomRight,
    );
    canvas.save();
    canvas.clipRRect(clip);

    final gradient = decoration.topGradient;
    if (gradient != null) {
      canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    } else if (decoration.solidLineAlpha != null) {
      // solidLine 降级（Spec §3.2）：1px 实线（α_top）+ 其下 1px 半强线
      final a = decoration.solidLineAlpha!;
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, 1),
        Paint()..color = Colors.white.withValues(alpha: a),
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top + 1, rect.width, 1),
        Paint()..color = Colors.white.withValues(alpha: a * 0.5),
      );
    }

    if (decoration.innerSheen) {
      // 底部 4% 白自下而上微渐变（玻璃厚度反光，单 drawRect，§5.4）
      const sheen = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment(0, 0.92),
        colors: [
          Color(0x0FFFFFFF),
          Color(0x00FFFFFF),
        ],
      );
      canvas.drawRect(rect, Paint()..shader = sheen.createShader(rect));
    }

    canvas.restore();
  }
}
