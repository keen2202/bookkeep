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
// 玻璃拟态图标 Token（UI 图标重构，Glassmorphism）
// ---------------------------------------------------------------------------
abstract final class AppGlass {
  /// 图标玻璃容器基准尺寸（不含内边距时的图标字号由调用方传入）
  static const double iconContainerSize = 40;

  /// 玻璃容器圆角（与卡片 md 对齐，保证轻盈统一）
  static const double iconRadius = 12;

  /// 玻璃背景高斯模糊半径（图标级 BackdropFilter 使用）
  static const double iconBlurSigma = 10;

  /// 玻璃描边宽度
  static const double borderWidth = 1;

  /// 浅色主题玻璃填充：白色 20% 通透层
  static const Color fillLight = Color(0x33FFFFFF);

  /// 深色主题玻璃填充：白色 10% 通透层（避免过亮破坏夜间氛围）
  static const Color fillDark = Color(0x1AFFFFFF);

  /// 浅色主题玻璃描边：白色 50% 高光
  static const Color borderLight = Color(0x80FFFFFF);

  /// 深色主题玻璃描边：白色 25% 微光
  static const Color borderDark = Color(0x40FFFFFF);

  /// 玻璃图标统一阴影：y=2、blur=10、8% 黑
  static const List<BoxShadow> iconShadow = [
    BoxShadow(offset: Offset(0, 2), blurRadius: 10, color: Color(0x14000000)),
  ];

  /// 玻璃卡片阴影（浅色）：y=4、blur=18、10% 黑，轻盈悬浮
  static const List<BoxShadow> cardShadowLight = [
    BoxShadow(offset: Offset(0, 4), blurRadius: 18, color: Color(0x1A000000)),
  ];

  /// 玻璃卡片阴影（深色）：y=4、blur=18、25% 黑，暗部光晕
  static const List<BoxShadow> cardShadowDark = [
    BoxShadow(offset: Offset(0, 4), blurRadius: 18, color: Color(0x40000000)),
  ];

  /// 玻璃卡片统一装饰（Glassmorphism v2）：
  /// 半透明磨砂填充（透出环境光/背景图）+ 高光发丝描边 + 柔悬浮阴影。
  ///
  /// 性能说明（Spec §10）：背景层（环境光渐变或背景图+8px 全局模糊）已在
  /// Navigator 之下预模糊，卡片自身不再叠加 BackdropFilter，保证长列表滚动
  /// 不掉帧；通透感由 [ThemePalette.glassFill] 的 alpha 直接呈现。
  static BoxDecoration glassCardDecoration({
    required bool isDark,
    required ThemePalette palette,
  }) {
    return BoxDecoration(
      color: palette.glassFill,
      borderRadius: AppRadius.mdAll,
      border: Border.all(color: palette.glassBorder, width: borderWidth),
      boxShadow: isDark ? cardShadowDark : cardShadowLight,
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

  /// 卡片装饰（玻璃拟态：磨砂填充 + 高光描边 + 悬浮阴影，浅深同构）
  BoxDecoration get cardDecoration => AppGlass.glassCardDecoration(
        isDark: isDark,
        palette: palette,
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
