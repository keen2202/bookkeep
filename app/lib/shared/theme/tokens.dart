import 'package:flutter/material.dart';

import 'theme_presets.dart';

/// 设计 Token 层（BK-UI-001，设计文档 §3）：
/// 一切间距/圆角/阴影/字阶必须来自本文件，禁止页面内裸值。
///
/// 三组常量 + [AppTokens] ThemeExtension（随主题携带 palette 与金额字阶）。

// ---------------------------------------------------------------------------
// 间距 Token（4pt 网格，设计文档 §3.3）
// ---------------------------------------------------------------------------
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets pagePadding = EdgeInsets.all(md);
  static const EdgeInsets sheetPadding =
      EdgeInsets.fromLTRB(md, sm, md, md);
}

// ---------------------------------------------------------------------------
// 圆角 Token（设计文档 §3.3）
// ---------------------------------------------------------------------------
abstract final class AppRadius {
  static const double sm = 8; // 输入框
  static const double md = 12; // 卡片
  static const double lg = 20; // 弹层
  static const double pill = 999; // 标签

  static final BorderRadius smAll = BorderRadius.circular(sm);
  static final BorderRadius mdAll = BorderRadius.circular(md);
  static final BorderRadius lgAll = BorderRadius.circular(lg);
  static final BorderRadius pillAll = BorderRadius.circular(pill);

  /// 底部弹层：仅顶部圆角
  static final BorderRadius sheetTop =
      const BorderRadius.vertical(top: Radius.circular(lg));
}

// ---------------------------------------------------------------------------
// 阴影 Token（设计文档 §3.3；深色主题用描边替代阴影）
// ---------------------------------------------------------------------------
abstract final class AppElevation {
  /// 卡片唯一阴影规格：y=2, blur=8, 8% 黑
  static const List<BoxShadow> card = [
    BoxShadow(offset: Offset(0, 2), blurRadius: 8, color: Color(0x14000000)),
  ];

  /// 底部弹层：y=-4, blur=16, 12% 黑
  static const List<BoxShadow> sheet = [
    BoxShadow(offset: Offset(0, -4), blurRadius: 16, color: Color(0x1F000000)),
  ];

  /// 卡片装饰按明暗分流：浅色阴影 / 深色描边
  static BoxDecoration cardDecoration({
    required Brightness brightness,
    required Color surface,
    required Color border,
  }) {
    final dark = brightness == Brightness.dark;
    return BoxDecoration(
      color: surface,
      borderRadius: AppRadius.mdAll,
      border: dark ? Border.all(color: border) : null,
      boxShadow: dark ? null : card,
    );
  }
}

// ---------------------------------------------------------------------------
// 字体系统（设计文档 §3.2，七级字阶）
// ---------------------------------------------------------------------------
abstract final class AppText {
  static const double displayAmountSize = 34; // w700 大数字
  static const double headlineSize = 22; // w600 页面主标题
  static const double titleSize = 17; // w600 卡片标题/列表主文案
  static const double bodySize = 15; // w400 正文
  static const double bodySmallSize = 13; // w400 辅助说明
  static const double captionSize = 12; // w400 时间戳/标签
  static const double amountSize = 17; // w600 列表金额（等宽数字）

  /// 等宽数字特性（金额列对齐）
  static const tabularFigures = [FontFeature('tnum')];

  /// 由调色板生成全局 TextTheme（映射到 M3 槽位）：
  /// displayAmount→displaySmall, headline→headlineSmall, title→titleLarge,
  /// body→bodyLarge, bodySmall→bodyMedium, caption→bodySmall。
  /// amount / displayAmount 经 [AppTokens.amountStyle] / [AppTokens.displayAmountStyle] 暴露。
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
// AppTokens：随主题携带的 Token 扩展（Spec §4.2/§4.3）
// ---------------------------------------------------------------------------
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({required this.palette, required this.brightness});

  final ThemePalette palette;
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  /// 列表金额（17sp w600 等宽数字）
  TextStyle get amountStyle => TextStyle(
        fontSize: AppText.amountSize,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: palette.textPrimary,
        fontFeatures: AppText.tabularFigures,
      );

  /// 大数字金额（34sp w700 等宽数字）
  TextStyle get displayAmountStyle => TextStyle(
        fontSize: AppText.displayAmountSize,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: palette.textPrimary,
        fontFeatures: AppText.tabularFigures,
      );

  /// 卡片装饰（浅色阴影 / 深色描边）
  BoxDecoration get cardDecoration => AppElevation.cardDecoration(
        brightness: brightness,
        surface: palette.surface,
        border: palette.border,
      );

  @override
  AppTokens copyWith({ThemePalette? palette, Brightness? brightness}) {
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
