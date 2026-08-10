import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// 统一提示条（设计文档 §3.4）：floating、成功 income 图标 / 失败 expense 图标、
/// 时长 2.5s、可滑动关闭。ScaffoldMessenger 调用点收敛出口（Spec §6）。
abstract final class AppSnack {
  static const _duration = Duration(milliseconds: 2500);

  /// 成功提示（income 绿图标）
  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_outline, context.appColors.income);

  /// 失败提示（expense 红图标）
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
          content: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
