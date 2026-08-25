import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass_tokens.dart';
import 'glass_panel.dart';

/// 图标容器尺寸档位（Spec §4.1：28 / 36 / 44 正方形三档）
enum GlassIconSize {
  /// 辅助图标（导航栏、AppBar 动作）
  s28(GlassIconTokens.size28),

  /// 列表图标
  s36(GlassIconTokens.size36),

  /// 主要功能图标
  s44(GlassIconTokens.size44);

  const GlassIconSize(this.side);

  final double side;
}

/// FG-ICON 功能性图标容器（Spec §4.1 / 设计文档 §5.1；BK-FG-010）：
///
/// - 尺寸 28/36/44 三档，圆角 = 边长 ×0.28（连续圆角近似 squircle）；
/// - 材质 = G1 全部参数（σ12、fill 0.55/0.10、双层描边、顶部内高光、
///   环境投影 0/2/8/α0.04），经 [GlassPanel] 单一出口渲染；
/// - 图标本体尺寸 = 容器 ×0.55（15.4/19.8/24.2），默认 `text.primary`
///   实色绘制，可选 [tint] 主题色变体（fill 混入 primary α0.10/α0.08）；
/// - 豁免：表格单元格内的文字型符号不设容器。
class GlassIcon extends StatelessWidget {
  const GlassIcon({
    super.key,
    required this.icon,
    this.size = GlassIconSize.s36,
    this.tint = false,
    this.color,
  });

  final IconData icon;

  /// 容器尺寸档位
  final GlassIconSize size;

  /// 主题色 tint 变体：容器填充混入主题色（Spec §4.1 tint 变体行）
  final bool tint;

  /// 覆盖图标本体颜色（默认 text.primary；tint 时默认 color.primary）
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = context.tokens.isDark;
    final side = size.side;

    var fill = resolveGlassSpec(
      level: GlassLevel.g1,
      brightness: palette.brightness,
    ).fill;
    var iconColor =
        color ?? (tint ? palette.primary : palette.textPrimary);
    if (tint) {
      // tint 变体：容器 fill 混入主题色 α0.10（浅）/ α0.08（深）叠加
      fill = Color.alphaBlend(
        palette.primary.withValues(
          alpha: dark
              ? GlassIconTokens.tintOverlayDark
              : GlassIconTokens.tintOverlayLight,
        ),
        fill,
      );
    }

    return GlassPanel(
      level: GlassLevel.g1,
      borderRadius: BorderRadius.circular(side * GlassIconTokens.radiusFactor),
      fillOverride: fill,
      child: SizedBox.square(
        dimension: side,
        child: Center(
          child: Icon(
            icon,
            // 图标本体 = 容器 × 0.55（Spec §4.1）
            size: side * GlassIconTokens.iconScale,
            color: iconColor,
            // 线条风格对齐 SF Symbols 的近似：优先调用方传入 outlined 族图标
            applyTextScaling: true,
          ),
        ),
      ),
    );
  }
}
