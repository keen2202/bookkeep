import 'package:flutter/material.dart';

/// 主题切换过场（FGDS v1.0，Spec §6 状态切换档 / 设计文档 §9）：
/// MaterialApp.builder 内包一层，ThemeData 变化时以 200ms 色彩插值过渡
/// （ThemeDataTween 覆盖 ColorScheme、TextTheme 及 AppColors/AppTokens 等
/// ThemeExtension 的 lerp），禁止闪变。
class ThemeTransition extends StatefulWidget {
  const ThemeTransition({super.key, required this.child});

  final Widget child;

  /// 过场时长（Spec §6：状态切换 200ms）
  static const duration = Duration(milliseconds: 200);

  @override
  State<ThemeTransition> createState() => _ThemeTransitionState();
}

class _ThemeTransitionState extends State<ThemeTransition> {
  ThemeData? _previous;

  @override
  Widget build(BuildContext context) {
    final current = Theme.of(context);
    final previous = _previous;
    _previous = current;
    if (previous == null || previous == current) return widget.child;
    return TweenAnimationBuilder<ThemeData>(
      tween: ThemeDataTween(begin: previous, end: current),
      duration: ThemeTransition.duration,
      curve: Curves.easeOutCubic,
      builder: (context, theme, child) => Theme(data: theme, child: child!),
      child: widget.child,
    );
  }
}
