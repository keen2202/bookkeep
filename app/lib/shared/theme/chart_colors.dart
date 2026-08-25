import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'theme_presets.dart';

/// 图表序列色（FGDS v1.0 收敛版）：
/// 旧 v3 的「环境光斑派生」随 ambient Token 一并拆除（Spec §8 清除清单）。
/// 序列改为 `主题色系 + 语义色` 派生：前 5 位保持品牌/语义锚定
/// （主色/次色/收入/预警/支出），后 3 位由主色容器色/次色向语义色收敛插值，
/// 保证任意主题下序列可辨且不出现裸 hex（chart_colors_test 锁定）。
List<Color> chartSeriesColorsFromPalette(ThemePalette palette, AppColors s) {
  return [
    palette.primary,
    palette.secondary,
    s.income,
    s.warning,
    s.expense,
    // 主容器色 → 主色收敛（同族深阶）
    Color.lerp(palette.primaryContainer, palette.primary, 0.45)!,
    // 次色 → 主色收敛
    Color.lerp(palette.secondary, palette.primary, 0.40)!,
    // 容器色 → 预警中性过渡
    Color.lerp(palette.primaryContainer, s.warning, 0.50)!,
  ];
}

/// 消费侧入口（context 版）
List<Color> chartSeriesColors(BuildContext context) =>
    chartSeriesColorsFromPalette(context.palette, context.appColors);
