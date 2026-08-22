import 'package:flutter/material.dart';

import '../app_theme.dart';

/// 环境光渐变背景（Glassmorphism v2，设计文档 §5.1）：
/// 无自定义背景图时的默认全局背景层——主题 [ThemePalette.background] 底色 +
/// 三个主题环境光色斑（[ThemePalette.ambient]，RadialGradient 软衰减），
/// 为磨砂玻璃卡片提供可透出的色彩层次，构成"玻璃 UI"的底层光环境。
///
/// 设计约定：
/// - 浅色主题：明亮粉彩光斑（晨雾/晴空/暮紫/蜜桃），通透轻盈；
/// - 深色主题：深邃霓虹光晕（石墨/极光/竹林/绛紫），低亮度高饱和；
/// - 光斑布局固定（左上/右中/左下），随主题切换整体过渡。
///
/// 性能（Spec §10）：纯静态绘制（无动画、无 saveLayer）；调用方以
/// RepaintBoundary 隔离本层与内容层，滚动零额外开销，仅在切主题时重绘。
class AmbientGradient extends StatelessWidget {
  const AmbientGradient({super.key, this.child});

  /// 叠加在渐变之上的内容层（可选；不传时仅渲染背景本身）
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // 兜底：自定义伪调色板未携带 ambient 时由 M3 派生色合成
    final ambient = palette.ambient.length >= 3
        ? palette.ambient
        : <Color>[
            palette.primaryContainer,
            palette.surfaceVariant,
            palette.primaryContainer,
          ];
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: palette.background),
        _Blob(ambient[0], const Alignment(-0.75, -0.85), 0.90, 0.70),
        _Blob(ambient[1], const Alignment(0.95, -0.05), 0.80, 0.65),
        _Blob(ambient[2], const Alignment(-0.15, 1.05), 0.95, 0.60),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

/// 单个环境光斑：中心实色 → 边缘全透明的高斯式软衰减
class _Blob extends StatelessWidget {
  const _Blob(this.color, this.center, this.widthFactor, this.heightFactor);

  final Color color;
  final Alignment center;
  final double widthFactor;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: center,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        heightFactor: heightFactor,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.95),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
