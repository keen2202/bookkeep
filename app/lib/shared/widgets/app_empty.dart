import 'package:flutter/material.dart';

import '../icons/bk_icon.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'app_button.dart';

/// 统一空态（设计文档 §3.4）：插画位（图标占位）+ title + bodySmall + 可选主按钮。
/// 账单/报表/日历等空态收敛出口（Spec §6）。
///
/// BK-ICON（BK-IC-022 / 34 D4 / §7.5）：
/// - 插画位支持 [icon]（Material，兼容）或 [bkName]（单层主形，推荐）；
/// - 容器 96×96 `primaryContainer.withValues(alpha: 0.5)` 圆底；
/// - 主图形 44、`palette.primary`；**禁止**二层装饰。
class AppEmpty extends StatelessWidget {
  const AppEmpty({
    super.key,
    this.icon,
    this.bkName,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : assert(
          icon != null || bkName != null,
          'AppEmpty 需要 icon 或 bkName 之一',
        );

  /// Material 插画图标（兼容既有调用点）
  final IconData? icon;

  /// BK-ICON 设计 ID（如 `BkIcons.billEmpty`）；优先于 [icon]
  final String? bkName;

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Widget illustration;
    if (bkName != null) {
      illustration = BkIcon(
        bkName!,
        size: 44,
        color: palette.primary,
      );
    } else {
      illustration = Icon(icon, size: 44, color: palette.primary);
    }
    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 插画位：primaryContainer 圆底 + primary 图标（D4 单层主形）
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: palette.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Center(child: illustration),
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
