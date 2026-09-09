import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// FG-SEL 可选标签（`ChoiceChip` 的全项目收敛出口，BK-DOC-31 需求2）：
/// M3 默认在选中项头部渲染 ✔（`showCheckmark: true`），此处统一关闭，
/// 改以「primary 前景 + 加粗」突显选中——底色与描边沿用 `chipTheme`
/// （selectedColor = primary α0.12，AC-07 禁实色填充），与
/// [AppSegmentedButton] 的选中语义同口径。
///
/// 页面不得各自散写 `showCheckmark` / 选中态配色。
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
  });

  final Widget label;
  final bool selected;

  /// 为空则不可点（同 `ChoiceChip` 语义）
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ChoiceChip(
      label: label,
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected,
      labelStyle: context.text.bodyMedium?.copyWith(
        color: selected ? palette.primary : palette.textPrimary,
        fontWeight: selected ? FontWeight.w600 : null,
      ),
    );
  }
}
