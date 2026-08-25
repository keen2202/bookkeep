import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass_tokens.dart';
import '../theme/tokens.dart';
import 'app_button.dart';
import 'glass_panel.dart';

/// FG-OVL 统一对话框（Spec §4.7；BK-FG-022）：G4 玻璃面板（σ36、fill
/// 0.80/0.24、R20）+ `glass.scrim` 遮罩 α0.32。AlertDialog 的全项目收敛出口。
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassPanel(
        level: GlassLevel.g4,
        borderRadius: AppRadius.lgAll,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.md),
            DefaultTextStyle.merge(
              style: context.text.bodyLarge,
              child: content,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

/// 确认对话框（danger=true 时确认键为危险样式）。
/// 返回 true=确认 / false=取消 / null=背板点击。
/// 背板遮罩为 Spec §2.3 `glass.scrim`（#000000 α0.32）。
Future<bool?> showAppConfirm(
  BuildContext context, {
  required String title,
  required String content,
  String confirmText = '确定',
  String cancelText = '取消',
  bool danger = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: GlassBackground.scrimOf(Colors.black),
    builder: (dialogContext) => AppDialog(
      title: title,
      content: Text(content),
      actions: [
        AppButton.text(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelText),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (danger)
          AppButton.danger(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmText),
          )
        else
          AppButton.primary(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmText),
          ),
      ],
    ),
  );
}
