import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// 统一卡片（设计文档 §3.4 / Spec §6）：玻璃拟态（Glassmorphism v2）——
/// 半透明磨砂填充 + 高光发丝描边 + 柔悬浮阴影（浅深主题同构，取值见
/// [AppGlass.glassCardDecoration]）。可点卡片按压水波纹 + 背景 4% 变化。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padded = true,
    this.margin,
    this.color,
  });

  final Widget child;

  /// 传入即可点（水波纹 + 按压背景 4% 变化）
  final VoidCallback? onTap;

  /// 内边距（默认 md=16；false 时零填充，由 child 自管）
  final bool padded;

  final EdgeInsetsGeometry? margin;

  /// 覆盖底色（默认 palette.glassFill 玻璃填充；传不透明色可关闭通透感）
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    // 玻璃卡片装饰：磨砂填充（透出环境光/背景图）+ 高光描边 + 悬浮阴影
    final decoration = tokens.cardDecoration.copyWith(color: color);

    final content = padded
        ? Padding(padding: AppSpacing.cardPadding, child: child)
        : child;

    return Container(
      margin: margin,
      decoration: decoration,
      child: onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: AppRadius.mdAll,
                // 按压背景 4% 变化
                overlayColor: WidgetStatePropertyAll(
                  palette.scrim.withValues(alpha: 0.04),
                ),
                child: content,
              ),
            ),
    );
  }
}
