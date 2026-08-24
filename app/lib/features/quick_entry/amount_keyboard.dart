import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme/app_theme.dart';

/// 自绘数字键盘（Spec §3.1 / BK-P0-001：禁用系统键盘弹起延迟）
class AmountKeyboard extends StatelessWidget {
  const AmountKeyboard({
    super.key,
    required this.onKey,
    this.onConfirm,
    this.onBackspace,
    this.onClear,
  });

  /// 数字 / '.' / '+' / '-'
  final ValueChanged<String> onKey;
  final VoidCallback? onConfirm;

  /// ⌫ 退格 / C 清除（独立回调：动作键不经 [onKey] 字符过滤，
  /// 否则 pressKey 无法识别会被静默丢弃——修复退格/清除键失灵）
  final VoidCallback? onBackspace;
  final VoidCallback? onClear;

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
                    Expanded(
                      child: _Key(
                        label: key,
                        onKey: onKey,
                        onConfirm: onConfirm,
                        onBackspace: onBackspace,
                        onClear: onClear,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.onKey,
    required this.onConfirm,
    this.onBackspace,
    this.onClear,
  });

  final String label;
  final ValueChanged<String> onKey;
  final VoidCallback? onConfirm;
  final VoidCallback? onBackspace;
  final VoidCallback? onClear;

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
          } else if (label == '⌫') {
            onBackspace?.call();
          } else if (label == 'C') {
            onClear?.call();
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
