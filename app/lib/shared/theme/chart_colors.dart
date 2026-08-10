import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 图表序列色（设计文档 §3.4 / Spec §6 收敛清单）：
/// 从 palette 与语义色派生，禁止裸 hex；浅深主题自动适配。
List<Color> chartSeriesColors(BuildContext context) {
  final p = context.palette;
  final s = context.appColors;
  return [
    p.primary,
    p.secondary,
    s.income,
    s.warning,
    s.expense,
    Color.lerp(p.primary, p.secondary, 0.5)!,
    Color.lerp(p.primary, p.textSecondary, 0.45)!,
    Color.lerp(s.warning, s.expense, 0.5)!,
  ];
}
