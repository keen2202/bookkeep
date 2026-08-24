import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../contrast_guard.dart';
import '../glass/glass_panel.dart';
import '../glass/glass_quality.dart';
import '../glass/ambient_motion.dart';

/// 环境光渐变背景（Glassmorphism v3，设计文档 §4 / Spec §4，GLS-009）：
/// 无自定义背景图时的默认全局背景层（L0 环境层，自身即光源）——
///
/// - **4 光斑 Mesh**：[ThemePalette.ambient] 4 色成套，锚点固定
///   左上/右中/左下/右上（v2 为 3 光斑，v3 补第 4 色）；
/// - **分档软化曲线**（Spec §4.4）：standard 档三段缓衰减
///   `[0.95I@0, 0.45I@0.55, 0@1]` 把「模糊」预烘焙进渐变（fill-only 下无
///   硬边）；high/saver 档两段急衰减 `[0.95I@0, 0@1]`；
/// - **动态漂移**：36s/光斑 椭圆轨道 + 页面切换脉冲 + Tab 呼吸，由
///   [AmbientMotion] 单例控制器驱动、CustomPainter 仅重绘本层
///   （调用方 RepaintBoundary 隔离，内容层零重建）；
/// - **ContrastGuard 联动**：强度经钳制后生效，兜底填充增量经
///   [GlassGuardScope] 下发玻璃面板。
///
/// 渲染输入全部来自 ThemeExtension（画质档）与 InheritedWidget 作用域
/// （[GlassPrefsScope]/[AmbientLockScope]，由 AppBackground/app shell 注入）
/// ——本层零 Provider 依赖，纯组件测试与 Golden 可直接渲染。
class AmbientGradient extends StatelessWidget {
  const AmbientGradient({super.key, this.child});

  /// 叠加在渐变之上的内容层（可选；不传时仅渲染背景本身）
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final prefs = GlassPrefsScope.of(context);
    final locked = AmbientLockScope.of(context);
    final mq = MediaQuery.of(context);
    final controller = AmbientMotion.instance;

    // 兜底：自定义伪调色板未携带足量 ambient 时由 M3 派生色补齐
    final ambient = palette.ambient.length >= 4
        ? palette.ambient
        : <Color>[
            ...palette.ambient,
            Color.lerp(
              palette.primaryContainer,
              palette.primaryContainer.withValues(alpha: 0.6),
              0.5,
            )!,
          ];

    // ContrastGuard 对比度联动（§4.5）：强度钳制 + 兜底增量下发面板
    final effectiveIntensity = ContrastGuard.effectiveIntensity(
      palette: palette,
      requested: prefs.intensity,
    );
    final extraFillAlpha = ContrastGuard.extraFillAlpha(
      palette: palette,
      effective: effectiveIntensity,
    );

    controller.configure(
      motionEnabled: prefs.motionEnabled,
      animationsDisabled: mq.disableAnimations,
      locked: locked,
      quality: tokens.glassQuality,
      imageMode: false, // 渐变路径即非图像模式
    );
    final animate = controller.animate;

    return GlassGuardScope(
      extraFillAlpha: extraFillAlpha,
      child: CustomPaint(
        painter: _AmbientPainter(
          background: palette.background,
          blobs: [
            for (var i = 0; i < ambient.length && i < _anchors.length; i++)
              _BlobSpec(
                color: ambient[i],
                anchor: _anchors[i],
                widthFactor: _sizes[i].width,
                heightFactor: _sizes[i].height,
                drift: animate ? controller.blobDriftOffset(i) : Offset.zero,
              ),
          ],
          intensityFactor: effectiveIntensity.factor,
          breatheScale: animate ? controller.breatheScale : 1.0,
          pulseOffset: animate ? controller.pulseOffset : Offset.zero,
          softeningStops: tokens.glassQuality == GlassQuality.standard
              ? _standardStops
              : _fastStops,
          repaint: animate ? controller : null,
        ),
        child: child,
      ),
    );
  }

  /// 光斑布局锚点（设计文档 §4.1：左上 / 右中 / 左下 / 右上）
  static const _anchors = [
    Alignment(-0.75, -0.85),
    Alignment(0.95, -0.05),
    Alignment(-0.15, 1.05),
    Alignment(0.75, 0.85),
  ];

  /// 光斑尺寸因子（宽 × 高 占画布比例）
  static const _sizes = [
    Size(0.90, 0.70),
    Size(0.80, 0.65),
    Size(0.95, 0.60),
    Size(0.55, 0.45),
  ];
}

/// standard 档三段缓衰减（把模糊烘焙进渐变，Spec §4.4）
const _standardStops = [0.0, 0.55, 1.0];

/// high/saver 档两段急衰减
const _fastStops = [0.0, 1.0];

/// 单个光斑的绘制快照（控制器数值 → 画布参数的一次性投影）
class _BlobSpec {
  const _BlobSpec({
    required this.color,
    required this.anchor,
    required this.widthFactor,
    required this.heightFactor,
    required this.drift,
  });

  final Color color;
  final Alignment anchor;
  final double widthFactor;
  final double heightFactor;

  /// 漂移偏移（占光斑尺寸分数，来自椭圆轨道 sin/cos）
  final Offset drift;
}

/// 环境光画笔（D4：动画仅重绘 L0 RepaintBoundary 内的画布，不重建 Widget 树）
class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.background,
    required this.blobs,
    required this.intensityFactor,
    required this.breatheScale,
    required this.pulseOffset,
    required this.softeningStops,
    super.repaint,
  });

  final Color background;
  final List<_BlobSpec> blobs;
  final double intensityFactor;
  final double breatheScale;
  final Offset pulseOffset;
  final List<double> softeningStops;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    for (final blob in blobs) {
      final halfW = size.width * blob.widthFactor / 2;
      final halfH = size.height * blob.heightFactor / 2;
      // 锚点定位 + 椭圆轨道漂移 + 导航脉冲位移（占屏幕短边比例）
      var center = blob.anchor.withinRect(size.center(Offset.zero) & size);
      center += Offset(blob.drift.dx * halfW, blob.drift.dy * halfH);
      center += pulseOffset * size.shortestSide;
      final rect = Rect.fromCenter(
        center: center,
        width: halfW * 2,
        height: halfH * 2,
      );

      // 分档软化曲线（Spec §4.4）：peak alpha = 0.95 × 强度系数 I × breathe
      final peak = (0.95 * intensityFactor * breatheScale).clamp(0.0, 1.0);
      final RadialGradient gradient;
      if (softeningStops.length >= 3) {
        // standard：三段缓衰减 [0.95I @0, 0.45I @0.55, 0 @1]
        gradient = RadialGradient(
          colors: [
            blob.color.withValues(alpha: peak),
            blob.color.withValues(alpha: peak * 0.45),
            blob.color.withValues(alpha: 0),
          ],
          stops: softeningStops,
        );
      } else {
        // high/saver：两段急衰减 [0.95I @0, 0 @1]
        gradient = RadialGradient(
          colors: [
            blob.color.withValues(alpha: peak),
            blob.color.withValues(alpha: 0),
          ],
          stops: softeningStops,
        );
      }
      canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) {
    return oldDelegate.background != background ||
        oldDelegate.intensityFactor != intensityFactor ||
        oldDelegate.breatheScale != breatheScale ||
        oldDelegate.pulseOffset != pulseOffset ||
        oldDelegate.softeningStops != softeningStops ||
        !_blobListEquals(oldDelegate.blobs, blobs);
  }
}

bool _blobListEquals(List<_BlobSpec> a, List<_BlobSpec> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].color != b[i].color ||
        a[i].anchor != b[i].anchor ||
        a[i].widthFactor != b[i].widthFactor ||
        a[i].heightFactor != b[i].heightFactor ||
        a[i].drift != b[i].drift) {
      return false;
    }
  }
  return true;
}
