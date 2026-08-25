import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass_tokens.dart';
import '../theme/tokens.dart';

/// 玻璃降级作用域（BK-FG-003）：壳层把用户「禁用磨砂」偏好投影进来，
/// GlassPanel/GlassIcon 据此跳过 BackdropFilter 并以 fill α +0.10 补偿
/// （Spec §3 派生规则 / 任务分解 BK-FG-003）。未注入时按开启处理。
class GlassPrefsScope extends InheritedWidget {
  const GlassPrefsScope({
    super.key,
    required this.blurEnabled,
    required super.child,
  });

  final bool blurEnabled;

  static GlassPrefsScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassPrefsScope>() ??
      const GlassPrefsScope(blurEnabled: true, child: SizedBox.shrink());

  @override
  bool updateShouldNotify(GlassPrefsScope oldWidget) =>
      oldWidget.blurEnabled != blurEnabled;
}

/// 玻璃面板（FGDS v1.0，Spec §3 层级参数表；BK-FG-003）：
/// G1–G5 通用的唯一玻璃容器出口。
///
/// 渲染顺序（五层，逐项对齐 §3 参数表）：
/// `环境投影 → ClipRRect → BackdropFilter(σ) → 填充(#FFFFFF×α) +
/// 外侧 0.5px 深色勾边 → 内侧 0.5px 白高光描边 + 顶部内高光渐变
/// （覆盖高度 40%，自上而下线性和到 0）→ child`；
///
/// - [fillLevel]（嵌套升档，Spec §3 派生规则）：卡片嵌套最多一层，
///   内层用下一档填充值但**不新增 BackdropFilter**、圆角 12——
///   内层的透明感来自外层容器的整体模糊（设计文档 §4.3）；
/// - 降级：[GlassPrefsScope] 关闭磨砂或 [forceFillOnly] 时跳过模糊节点，
///   fill α +0.10 补偿；
/// - 可点面板按压反馈走 FG-BTN pressed 规则（Spec §4.5 点击反馈行：
///   fill 0.48/0.09 + scale 0.98 + 顶部内阴影近似）。
class GlassPanel extends StatefulWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.level = GlassLevel.g2,
    this.borderRadius,
    this.onTap,
    this.padding,
    this.fillLevel,
    this.forceFillOnly = false,
    this.shadows = true,
    this.fillOverride,
    this.blurSigmaOverride,
  });

  /// 嵌套内层容器便捷构造：宿主 [host] 的下一档填充值、零新增模糊节点、
  /// 圆角 12、无投影（Spec §4.5 嵌套行）。
  factory GlassPanel.nested({
    Key? key,
    required Widget child,
    required GlassLevel host,
    EdgeInsetsGeometry? padding,
  }) {
    return GlassPanel(
      key: key,
      level: host,
      fillLevel: nestedFillLevel(host),
      forceFillOnly: true,
      shadows: false,
      borderRadius: BorderRadius.circular(AppRadius.md),
      padding: padding,
      child: child,
    );
  }

  final Widget child;

  /// 玻璃层级（默认 G2 内容面板层）
  final GlassLevel level;

  /// 覆盖填充/描边/高光的层级（嵌套升档用；blur 仍取 [level] 但被
  /// [forceFillOnly] 抑制）
  final GlassLevel? fillLevel;

  /// 圆角（默认取层级表；胶囊等特殊形态由调用方传入）
  final BorderRadius? borderRadius;

  /// 传入即可点（FG-CARD 点击反馈：pressed 参数矩阵）
  final VoidCallback? onTap;

  final EdgeInsetsGeometry? padding;

  /// 强制跳过模糊节点（嵌套层 / 行级元素）
  final bool forceFillOnly;

  /// 是否渲染环境投影（嵌套层关闭）
  final bool shadows;

  /// 覆盖填充色（着色玻璃变体用，如 GlassIcon tint / FAB；取值须来自
  /// Token 组合，禁止页面散写）
  final Color? fillOverride;

  /// 覆盖模糊 σ（FG-BTN 状态矩阵等规格内离散值；仅 shared/widgets 消费）
  final double? blurSigmaOverride;

  @override
  State<GlassPanel> createState() => _GlassPanelState();
}

class _GlassPanelState extends State<GlassPanel> {
  bool _press = false;

  void _setPress(bool v) {
    if (_press != v && widget.onTap != null) setState(() => _press = v);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = context.tokens.brightness;
    final scopeBlur = GlassPrefsScope.of(context).blurEnabled;
    // 结构性 fill-only（嵌套层）：不加降级补偿，严格取层级表填充值；
    // 用户降级：跳过模糊节点并叠加 fill α+0.10 补偿
    final structuralOnly = widget.forceFillOnly || widget.fillLevel != null;
    final blurEnabled = !structuralOnly && scopeBlur;

    // 填充侧规格（嵌套时取升档值）；模糊侧始终取 level
    final surfaceSpec = resolveGlassSpec(
      level: widget.fillLevel ?? widget.level,
      brightness: brightness,
      blurEnabled: blurEnabled,
      degradeCompensation: !structuralOnly,
    );
    final blurSigma = resolveGlassSpec(
      level: widget.level,
      brightness: brightness,
      blurEnabled: blurEnabled,
    );

    // 按压态（FG-BTN pressed 行：fill 0.48 浅 / 0.09 深 + 内阴影）
    final dark = brightness == Brightness.dark;
    var fill = widget.fillOverride ??
        (_press
            ? Colors.white.withValues(alpha: dark ? 0.09 : 0.48)
            : surfaceSpec.fill);

    final radius =
        widget.borderRadius ?? BorderRadius.circular(surfaceSpec.radius);

    // 表面容器：填充 + 外侧勾边；前景装饰承担内侧白高光 + 顶部内高光渐变
    Widget surface = AnimatedContainer(
      key: const ValueKey('glass-surface'),
      duration: GlassMotion.micro,
      curve: GlassMotion.curve,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: surfaceSpec.borderOuter, width: 0.5),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: surfaceSpec.borderInnerHighlight,
          width: 0.5,
        ),
        // 顶部内高光：组件高度 40% 白色渐变（上亮下消）；
        // 按压态叠加顶部内阴影近似（inset 0/1/3 #000 α0.08 的视觉替代）
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment(0, _press ? 0.10 : surfaceSpec.topHighlightCoverage),
          colors: _press
              ? [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.white.withValues(
                      alpha: dark
                          ? surfaceSpec.topHighlightAlpha
                          : surfaceSpec.topHighlightAlpha * 0.4),
                  Colors.transparent,
                ]
              : [
                  Colors.white.withValues(
                      alpha: dark
                          ? surfaceSpec.topHighlightAlpha
                          : surfaceSpec.topHighlightAlpha),
                  Colors.transparent,
                ],
          stops: _press ? const [0, 0.5, 1] : const [0, 1],
        ),
      ),
      child: widget.child,
    );

    // 真模糊层：仅容器级组件启用（设计文档 §4.3 性能边界）；
    // fill-only（降级/嵌套）时零 saveLayer 直接渲染
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: widget.shadows ? surfaceSpec.shadows : null,
      ),
      child: !blurEnabled
          ? surface
          : ClipRRect(
              key: const ValueKey('glass-clip'),
              borderRadius: radius,
              child: BackdropFilter(
                key: const ValueKey('glass-blur'),
                filter: ImageFilter.blur(
                  sigmaX: widget.blurSigmaOverride ?? blurSigma.blur,
                  sigmaY: widget.blurSigmaOverride ?? blurSigma.blur,
                ),
                child: surface,
              ),
            ),
    );

    if (widget.onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPress(true),
          onTapUp: (_) => _setPress(false),
          onTapCancel: () => _setPress(false),
          onTap: widget.onTap,
          child: content,
        ),
      );
      // 按压缩放 0.98（150ms，Spec §6 微交互动效）
      content = AnimatedScale(
        scale: _press ? 0.98 : 1,
        duration: GlassMotion.micro,
        curve: GlassMotion.curve,
        child: content,
      );
    }

    return content;
  }
}
