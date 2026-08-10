import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_button.dart';

/// 统一对话框（设计文档 §3.4）：圆角 lg、标题 title + 内容 body + 按钮区右对齐；
/// 危险操作确认按钮用 danger 样式。AlertDialog 的全项目收敛出口（Spec §6）。
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
    return AlertDialog(
      title: Text(title),
      content: DefaultTextStyle.merge(
        style: Theme.of(context).textTheme.bodyLarge,
        child: content,
      ),
      actions: actions,
    );
  }
}

/// 确认对话框（danger=true 时确认键为危险样式）。
/// 返回 true=确认 / false=取消 / null=背板点击。
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
