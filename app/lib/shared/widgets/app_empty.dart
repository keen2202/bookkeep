import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'app_button.dart';

/// 统一空态（设计文档 §3.4）：插画位（图标占位）+ title + bodySmall + 可选主按钮。
/// 账单/报表/日历等空态收敛出口（Spec §6）。
class AppEmpty extends StatelessWidget {
  const AppEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 插画位：primaryContainer 圆底 + primary 图标
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: palette.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: palette.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: context.text.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton.primary(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
