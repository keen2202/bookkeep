import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass_tokens.dart';
import '../theme/tokens.dart';
import 'glass_panel.dart';

/// FG-OVL 统一提示条（Spec §4.7；BK-FG-022）：G5 玻璃胶囊（σ44、fill
/// 0.85/0.30、全圆角），floating、成功 income 图标 / 失败 expense 图标、
/// 时长 2.5s、可滑动关闭。ScaffoldMessenger 调用点收敛出口。
abstract final class AppSnack {
  static const _duration = Duration(milliseconds: 2500);

  /// 成功提示（success 绿图标）
  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_outline, context.appColors.income);

  /// 失败提示（danger 红图标）
  static void error(BuildContext context, String message) =>
      _show(context, message, Icons.error_outline, context.appColors.expense);

  /// 中性信息
  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_outline, null);

  static void _show(BuildContext context, String message, IconData icon, Color? iconColor) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: _duration,
          dismissDirection: DismissDirection.horizontal,
          backgroundColor: Colors.transparent,
          elevation: 0,
          // G5 胶囊玻璃（真实磨砂由 GlassPanel 承载）
          content: GlassPanel(
            level: GlassLevel.g5,
            borderRadius: AppRadius.pillAll,
            shadows: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: context.text.bodyMedium
                        ?.copyWith(color: context.palette.textPrimary),
                    child: Text(message),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
