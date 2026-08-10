import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme/app_theme.dart';

/// 自绘数字键盘（Spec §3.1 / BK-P0-001：禁用系统键盘弹起延迟）
class AmountKeyboard extends StatelessWidget {
  const AmountKeyboard({super.key, required this.onKey, this.onConfirm});

  final ValueChanged<String> onKey;
  final VoidCallback? onConfirm;

  static const _rows = [
    ['7', '8', '9', '⌫'],
    ['4', '5', '6', '+'],
    ['1', '2', '3', '-'],
    ['C', '0', '.', '确定'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      // 审查 U-3：edge-to-edge 下「确定」键不被系统手势区遮挡（保留底部 SafeArea）
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in _rows)
              Row(
                children: [
                  for (final key in row)
                    Expanded(child: _Key(label: key, onKey: onKey, onConfirm: onConfirm)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onKey, required this.onConfirm});

  final String label;
  final ValueChanged<String> onKey;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final isAction = label == '⌫' || label == 'C';
    final isConfirm = label == '确定';
    // 审查 U-12：读屏可识别按键 + 触控反馈
    return Semantics(
      button: true,
      label: isConfirm
          ? '确认'
          : isAction
              ? (label == '⌫' ? '退格' : '清除')
              : '数字 $label',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          if (isConfirm) {
            onConfirm?.call();
          } else {
            onKey(label);
          }
        },
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: isAction
              ? Icon(label == '⌫' ? Icons.backspace_outlined : Icons.clear, size: 22)
              : Text(
                  label,
                  // UI 重构（Spec §6）：字号收敛至字阶——数字 headline(22)/确定 title(17)
                  style: isConfirm
                      ? context.text.titleLarge?.copyWith(
                          color: context.palette.primary,
                        )
                      : context.text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                ),
        ),
      ),
    );
  }
}
