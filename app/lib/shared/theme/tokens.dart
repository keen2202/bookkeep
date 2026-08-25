import 'package:flutter/material.dart';

import 'theme_presets.dart';

/// 设计 Token 层（BK-UI-001 延续；FGDS v1.0 收敛）：
/// 一切间距/圆角/阴影/字阶必须来自本文件，禁止页面内裸值。
///
/// 玻璃参数（blur/fill/描边/高光/投影）已全部迁往 `glass_tokens.dart`
/// 唯一参数源（BK-FG-001）；旧 `AppGlass` 装饰方法与 v2/v3 阴影别名
/// 一次性拆除（Spec §8 清除清单，AC-08）。

// ---------------------------------------------------------------------------
// 间距 Token（4pt 网格）
// ---------------------------------------------------------------------------
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// 卡片内边距（Spec §4.5：16，紧凑 12）
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(12);
  static const EdgeInsets pagePadding = EdgeInsets.all(md);

  /// 卡片间距（Spec §4.5：同组 12 / 跨组 20）
  static const double gapInGroup = 12;
  static const double gapAcrossGroups = 20;

  static const EdgeInsets sheetPadding =
      EdgeInsets.fromLTRB(md, sm, md, md);
}

// ---------------------------------------------------------------------------
// 圆角 Token（设计文档 §7 四档语言 + Spec §3 层级圆角行）
// ---------------------------------------------------------------------------
abstract final class AppRadius {
  static const double sm = 8; // 小控件
  static const double md = 12; // 按钮 / 输入框 / 嵌套容器
  static const double card = 16; // 卡片（G2）/ 浮条（G3）/ FAB
  static const double overlay = 20; // 浮层（G4）
  static const double toast = 14; // Toast（G5 非胶囊形态）
  static const double pill = 999; // 胶囊全圆角

  static final BorderRadius smAll = BorderRadius.circular(sm);
  static final BorderRadius mdAll = BorderRadius.circular(md);
  static final BorderRadius cardAll = BorderRadius.circular(card);
  static final BorderRadius lgAll = BorderRadius.circular(overlay);
  static final BorderRadius toastAll = BorderRadius.circular(toast);
  static final BorderRadius pillAll = BorderRadius.circular(pill);

  /// 底部弹层：仅顶部圆角（G4 = 20）
  static final BorderRadius sheetTop =
      const BorderRadius.vertical(top: Radius.circular(overlay));
}

// ---------------------------------------------------------------------------
// 字体系统（Spec §5 文字规格：正文15/标题17/大标题28/金额20/辅助13/时间戳12）
// ---------------------------------------------------------------------------
abstract final class AppText {
  static const double displayAmountSize = 28; // 大标题 28/700
  static const double headlineSize = 22; // 页面主标题（沿用既有槽位）
  static const double titleSize = 17; // 标题 17/600
  static const double bodySize = 15; // 正文 15/400
  static const double bodySmallSize = 13; // 辅助说明 13/400、表头 13/600
  static const double captionSize = 12; // 占位符、时间戳 12/400
  static const double amountSize = 20; // 金额 20/600（等宽数字）

  /// 等宽数字特性（金额列对齐）
  static const tabularFigures = [FontFeature('tnum')];

  /// 由调色板生成全局 TextTheme（映射到 M3 槽位）。
  static TextTheme buildTextTheme(ThemePalette p) {
    const base = TextTheme();
    return base.copyWith(
      displaySmall: TextStyle(
        fontSize: displayAmountSize,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: p.textPrimary,
        fontFeatures: tabularFigures,
      ),
      headlineSmall: TextStyle(
        fontSize: headlineSize,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: p.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: titleSize,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: p.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: bodySize,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: p.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: bodySmallSize,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: p.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: bodySize,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: p.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: bodySmallSize,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: p.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: captionSize,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: p.textSecondary,
      ),
      labelLarge: TextStyle(
        // 按钮文字（Spec §4.4 通用规格：15px/600）
        fontSize: bodySize,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: p.textPrimary,
      ),
      labelSmall: TextStyle(
        fontSize: captionSize,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: p.textSecondary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppTokens：随主题携带的 Token 扩展
// ---------------------------------------------------------------------------
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.palette,
    required this.brightness,
  });

  final ThemePalette palette;
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  /// 列表金额（20sp w600 等宽数字，Spec §5 金额档）
  TextStyle get amountStyle => TextStyle(
        fontSize: AppText.amountSize,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: palette.textPrimary,
        fontFeatures: AppText.tabularFigures,
      );

  /// 大数字金额（28sp w700 等宽数字，Spec §5 大标题档）
  TextStyle get displayAmountStyle => TextStyle(
        fontSize: AppText.displayAmountSize,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: palette.textPrimary,
        fontFeatures: AppText.tabularFigures,
      );

  @override
  AppTokens copyWith({
    ThemePalette? palette,
    Brightness? brightness,
  }) {
    return AppTokens(
      palette: palette ?? this.palette,
      brightness: brightness ?? this.brightness,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      palette: palette.lerp(other.palette, t),
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }
}
