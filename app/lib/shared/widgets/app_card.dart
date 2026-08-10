import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// 统一卡片（设计文档 §3.4 / Spec §6）：圆角 md；
/// 浅色主题 elevation.card 阴影，深色主题 1px border 描边（二选一）。
/// 可点卡片按压水波纹 + 背景 4% 变化。
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

  /// 覆盖底色（默认 palette.surface）
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final decoration = tokens.isDark
        ? BoxDecoration(
            color: color ?? palette.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: palette.border),
          )
        : BoxDecoration(
            color: color ?? palette.surface,
            borderRadius: AppRadius.mdAll,
            boxShadow: AppElevation.card,
          );

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
