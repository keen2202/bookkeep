import 'package:flutter/material.dart';

/// 主题切换过场（Spec §4.5 / BK-UI-004）：MaterialApp.builder 内包一层，
/// ThemeData 变化时以 250ms 色彩插值过渡（ThemeDataTween 覆盖 ColorScheme、
/// TextTheme 及 AppColors/AppTokens 等 ThemeExtension 的 lerp）。
class ThemeTransition extends StatefulWidget {
  const ThemeTransition({super.key, required this.child});

  final Widget child;

  /// 过场时长（设计文档 §3.4：主题切换 250ms）
  static const duration = Duration(milliseconds: 250);

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
