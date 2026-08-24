import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'theme_presets.dart';

/// 图表序列色（Glassmorphism v3，Spec §5.4 / GLS-007）：
/// 分类色序列由 `palette.ambient + semantic` 派生（8 色），图表与所在主题
/// 光环境同源——锁定测试防漂移（chart_colors_test）。
///
/// 前 5 位保持品牌/语义锚定（主色/次色/收入/预警/支出），后 3 位从
/// 环境光斑向主色系收敛插值，保证任意主题下序列可辨且不出现裸 hex。
List<Color> chartSeriesColorsFromPalette(ThemePalette palette, AppColors s) {
  Color blob(int index, [Color fallback = Colors.grey]) => palette.ambient.length > index
      ? palette.ambient[index]
      : fallback;
  return [
    palette.primary,
    palette.secondary,
    s.income,
    s.warning,
    s.expense,
    // 环境光派生：左上光斑 → 主色收敛（同族深阶）
    Color.lerp(blob(0, palette.primaryContainer), palette.primary, 0.45)!,
    // 右中光斑 → 次色收敛
    Color.lerp(blob(1, palette.primaryContainer), palette.secondary, 0.40)!,
    // 右上光斑 → 预警/支出中性过渡
    Color.lerp(
        blob(3, palette.primaryContainer), s.warning, 0.50)!,
  ];
}

/// 消费侧入口（context 版）
List<Color> chartSeriesColors(BuildContext context) =>
    chartSeriesColorsFromPalette(context.palette, context.appColors);
