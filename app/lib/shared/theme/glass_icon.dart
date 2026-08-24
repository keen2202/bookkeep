import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'glass/glass_layers.dart';
import 'tokens.dart';

/// 玻璃拟态图标容器（UI 图标重构；Glassmorphism v3 GLS-008）。
///
/// v3：填充/描边/σ 改读 `resolveGlassSpec(panel)`——与卡片完全同源
/// （Spec §5.3），σ 按画质档解析（standard/saver 档 fill-only 无磨砂节点，
/// [blur]=false 可强制关闭）。旧 [AppGlass] 常量保留兼容但不再消费。
///
/// 规范：1px 白系描边、12px 圆角（与卡片体系一致）、y=2 blur=10 8% 黑阴影；
/// 图标本体颜色继承 IconTheme 或语义色，禁止纯黑置于玻璃容器上。
class GlassIcon extends StatelessWidget {
  const GlassIcon({
    super.key,
    required this.icon,
    this.size = 22,
    this.padding = const EdgeInsets.all(AppSpacing.xs),
    this.radius,
    this.color,
    this.blur = true,
  });

  final IconData icon;

  /// 图标字号
  final double size;

  /// 玻璃容器内边距
  final EdgeInsetsGeometry padding;

  /// 容器圆角（默认取 AppGlass.iconRadius）
  final double? radius;

  /// 图标颜色；不传时继承外层 IconTheme（可由 NavigationBar/AppBar 等自动着色）
  final Color? color;

  /// 是否允许 BackdropFilter 磨砂；true 时仍受画质档裁决
  /// （standard/saver 档 L1 为 fill-only，实际不产生模糊节点）
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final spec = resolveGlassSpec(
      tier: GlassTier.panel,
      brightness: tokens.brightness,
      palette: tokens.palette,
      quality: tokens.glassQuality,
    );
    // 小图标容器按 v2 基线保留更通透的白基填充观感：
    // 浅色 = 白 α0.20（L1 high 基准）/ 深色 = surface α0.66 过厚，取白 α0.10
    final isDark = tokens.isDark;
    final fill = isDark ? const Color(0x1AFFFFFF) : Colors.white.withValues(alpha: 0.20);
    final r = radius ?? AppGlass.iconRadius;
    final borderRadius = BorderRadius.circular(r);

    if (!blur || spec.isFillOnly) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: borderRadius,
          border:
              Border.all(color: spec.borderColor, width: AppGlass.borderWidth),
          boxShadow: AppGlass.iconShadow,
        ),
        child: Icon(icon, size: size, color: color),
      );
    }

    // 高保真档：外层阴影 → ClipRRect → BackdropFilter → 玻璃面
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: AppGlass.iconShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: spec.sigmaX,
            sigmaY: spec.sigmaY,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: borderRadius,
              border: Border.all(
                color: spec.borderColor,
                width: AppGlass.borderWidth,
              ),
            ),
            child: Icon(icon, size: size, color: color),
          ),
        ),
      ),
    );
  }
}

/// 玻璃拟态图标按钮：将 [IconButton] 的图标统一放入 [GlassIcon]。
/// 用于 AppBar 操作、快速记账退出等需要明确可点击的图标入口。
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 20,
    this.padding = const EdgeInsets.all(AppSpacing.xs),
    this.color,
    this.blur = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final EdgeInsetsGeometry padding;
  final Color? color;

  /// 是否启用玻璃磨砂；小图标/低端机可关闭。
  final bool blur;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: GlassIcon(
        icon: icon,
        size: size,
        padding: padding,
        color: color,
        blur: blur,
      ),
    );
  }
}
