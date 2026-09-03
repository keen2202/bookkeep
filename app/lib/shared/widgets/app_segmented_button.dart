import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 分段控件选中底色 α：primary 低透明叠加，与 `chipTheme.selectedColor`
/// （app_theme.dart）同口径，满足玻璃规范 AC-07「禁实色填充选中态」。
const double _kSelectedFillAlpha = 0.12;

/// FG-SEL 分段选择控件（BK-DOC-28 需求7 / Spec §2.7、§3 C8）：
/// `SegmentedButton<T>` 的全项目收敛出口。
///
/// M3 框架默认在选中段头部渲染 ✔（`showSelectedIcon: true`），此处统一关闭，
/// 改以「primary α0.12 底 + primary 前景」突显选中（AC7-1 / AC7-2）。
/// 页面不得各自散写 `showSelectedIcon`（AC7-4）。
///
/// 不变的部分：
/// - 选中语义仍由 `SegmentedButton` 承担，读屏可辨 selected，颜色不是唯一
///   语义通道（AC7-3 无障碍）；
/// - 禁用段不受影响——框架仅对非禁用段套用 `selectedBackgroundColor` /
///   `selectedForegroundColor`，故记账页「转账」锁定态样式照旧（AC7-3）。
class AppSegmentedButton<T> extends StatelessWidget {
  const AppSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    this.onSelectionChanged,
    this.multiSelectionEnabled = false,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;

  /// 为空则全部段禁用（同 `SegmentedButton` 语义）
  final void Function(Set<T> newSelection)? onSelectionChanged;

  final bool multiSelectionEnabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SegmentedButton<T>(
      segments: segments,
      selected: selected,
      onSelectionChanged: onSelectionChanged,
      multiSelectionEnabled: multiSelectionEnabled,
      showSelectedIcon: false,
      style: ButtonStyle(
        selectedBackgroundColor: WidgetStatePropertyAll(
          palette.primary.withValues(alpha: _kSelectedFillAlpha),
        ),
        selectedForegroundColor: WidgetStatePropertyAll(palette.primary),
      ),
    );
  }
}
