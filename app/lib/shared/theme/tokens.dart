import 'package:flutter/material.dart';

import 'glass/glass_layers.dart';
import 'glass/glass_quality.dart';
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
// 玻璃拟态 Token（Glassmorphism v2 图标基准 → v3 层级函数消费端）
// ---------------------------------------------------------------------------
abstract final class AppGlass {
  /// 图标玻璃容器基准尺寸（不含内边距时的图标字号由调用方传入）
  static const double iconContainerSize = 40;

  /// 玻璃容器圆角（与卡片 md 对齐，保证轻盈统一）
  static const double iconRadius = 12;

  /// 玻璃背景高斯模糊半径上限（图标级 BackdropFilter；v3 起实际 σ 由
  /// [resolveGlassSpec] 按画质档解析，standard 档归零走 fill-only）
  static const double iconBlurSigma = 10;

  /// 玻璃描边宽度（Spec §2.1：恒 1 逻辑像素）
  static const double borderWidth = 1;

  /// 浅色 L1 基准填充（兼容别名；= rgba(255,255,255,0.20) 需求给定基准。
  /// v3 新代码请使用 `resolveGlassSpec(tier: GlassTier.panel)`）
  static const Color fillLight = Color(0x33FFFFFF);

  /// 深色主题玻璃填充旧常量（兼容保留，不再被组件消费；
  /// v3 深色填充 = palette.surface × 层级 α，带主题色温非纯黑）
  static const Color fillDark = Color(0x1AFFFFFF);

  /// 浅色玻璃描边（D5 兼容别名：已收敛至 Spec §2.1 规范值 L1 浅 α0.20；
  /// 旧漂移值 0x99FFFFFF 已清零）
  static const Color borderLight = Color(0x33FFFFFF);

  /// 深色玻璃描边（D5 兼容别名：L1 深 α0.16 实值；旧漂移值 0x38FFFFFF
  /// 已清零——合成对比度仅约 1.4:1 不可见，见 Spec §2.4 验算）
  static const Color borderDark = Color(0x29FFFFFF);

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

  /// 玻璃卡片统一装饰（Glassmorphism v3）：
  /// 半透明磨砂填充 + 高光发丝描边 + 柔悬浮阴影，取值全部来自
  /// [resolveGlassSpec]（L1 panel 层级函数，D5 唯一入口）。
  ///
  /// 性能说明（Spec §10）：背景层已在 Navigator 之下预渲染，卡片自身
  /// σ 按画质档解析——standard/saver 档为 fill-only 零 saveLayer，
  /// 保证长列表滚动不掉帧。
  static BoxDecoration glassCardDecoration({
    required bool isDark,
    required ThemePalette palette,
    GlassQuality quality = GlassQuality.standard,
    bool imageBackgroundMode = false,
  }) {
    final spec = resolveGlassSpec(
      tier: GlassTier.panel,
      brightness: isDark ? Brightness.dark : Brightness.light,
      palette: palette,
      quality: quality,
      imageBackgroundMode: imageBackgroundMode,
    );
    return BoxDecoration(
      color: spec.fill,
      borderRadius: AppRadius.mdAll,
      border: Border.all(color: spec.borderColor, width: borderWidth),
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
// AppTokens：随主题携带的 Token 扩展（Spec §4.2/§4.3 + v3 玻璃画质档）
// ---------------------------------------------------------------------------
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.palette,
    required this.brightness,
    this.glassQuality = GlassQuality.standard,
  });

  final ThemePalette palette;
  final Brightness brightness;

  /// 玻璃画质三档（v3）：随主题携带，GlassPanel/AppCard/GlassIcon 从
  /// ThemeExtension 读取（不依赖 ProviderScope，纯组件测试可直渲染）。
  /// 默认 standard（D6），main() 启动时按持久化设置重建主题注入。
  final GlassQuality glassQuality;

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

  /// 卡片装饰（玻璃拟态 v3：层级函数解析的填充/描边/阴影）
  BoxDecoration get cardDecoration => AppGlass.glassCardDecoration(
        isDark: isDark,
        palette: palette,
        quality: glassQuality,
      );

  @override
  AppTokens copyWith({
    ThemePalette? palette,
    Brightness? brightness,
    GlassQuality? glassQuality,
  }) {
    return AppTokens(
      palette: palette ?? this.palette,
      brightness: brightness ?? this.brightness,
      glassQuality: glassQuality ?? this.glassQuality,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      palette: palette.lerp(other.palette, t),
      brightness: t < 0.5 ? brightness : other.brightness,
      // 画质档离散切换：过场中点后取目标档（σ 分支不插值，避免中间态节点结构漂移）
      glassQuality: t < 0.5 ? glassQuality : other.glassQuality,
    );
  }
}
