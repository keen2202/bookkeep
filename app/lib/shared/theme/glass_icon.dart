import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'tokens.dart';

/// 玻璃拟态图标容器（UI 图标重构）。
///
/// 规范（与 `AppGlass` Token 对应）：
/// - 填充：浅色主题白色 20%、深色主题白色 10%（通透玻璃质感）；
/// - 描边：白色 50% / 25% 高光边，1px；
/// - 模糊：容器内 10px 高斯模糊，让底层内容透出磨砂效果；
/// - 阴影：y=2、blur=10、8% 黑，制造轻盈悬浮感；
/// - 圆角：12px，与卡片圆角体系一致。
///
/// 该组件是应用内图标玻璃化承载的统一出口；底部导航、FAB、顶栏操作等
/// 关键图标均通过它渲染，保证图标视觉语言一致。
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

  /// 是否启用 BackdropFilter 磨砂（小图标/低端机可关闭）
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final isDark = context.tokens.isDark;
    final fill = isDark ? AppGlass.fillDark : AppGlass.fillLight;
    final border = isDark ? AppGlass.borderDark : AppGlass.borderLight;
    final r = radius ?? AppGlass.iconRadius;
    final borderRadius = BorderRadius.circular(r);

    final glass = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(color: border, width: AppGlass.borderWidth),
        boxShadow: AppGlass.iconShadow,
      ),
      child: Icon(
        icon,
        size: size,
        color: color,
      ),
    );

    if (!blur) return glass;

    // 开启磨砂时：外层负责阴影，内层 ClipRRect + BackdropFilter 负责玻璃模糊，
    // 避免 Clip 裁掉阴影。
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: AppGlass.iconShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: AppGlass.iconBlurSigma,
            sigmaY: AppGlass.iconBlurSigma,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: borderRadius,
              border: Border.all(color: border, width: AppGlass.borderWidth),
            ),
            child: Icon(
              icon,
              size: size,
              color: color,
            ),
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
