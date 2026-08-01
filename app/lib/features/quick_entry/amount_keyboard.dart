import 'package:flutter/material.dart';

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
    return InkWell(
      onTap: () => isConfirm ? onConfirm?.call() : onKey(label),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        child: isAction
            ? Icon(label == '⌫' ? Icons.backspace_outlined : Icons.clear, size: 22)
            : Text(
                label,
                style: TextStyle(
                  fontSize: isConfirm ? 16 : 22,
                  fontWeight: isConfirm ? FontWeight.bold : FontWeight.normal,
                  color: isConfirm ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
      ),
    );
  }
}
