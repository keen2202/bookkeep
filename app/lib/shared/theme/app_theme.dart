import 'package:flutter/material.dart';

import 'theme_presets.dart';
import 'tokens.dart';

/// 默认主题种子色（品牌主色 teal 600；仅 custom 模式使用）
const kDefaultSeedColor = Color(0xFF00897B);

/// 8 色调色板（审查 U-5：语义色统一提取至 constants，浅深两态可复用）
const kAppPalette = <Color>[
  kDefaultSeedColor, // teal 600（品牌主色）
  Color(0xFF26A69A), // teal 400
  Color(0xFF80CBC4), // teal 200
  Color(0xFF2E7D32), // green 800（收入）
  Color(0xFFC62828), // red 800（支出）
  Color(0xFFEF6C00), // orange 800（预警）
  Color(0xFF90A4AE), // blue-grey 300
  Color(0xFF546E7A), // blue-grey 600
];

/// 语义色（设计文档 §3.5：income/expense/warning 全主题静态锁定，
/// 浅深两套，对比度达 WCAG 4.5:1，不随主题漂移）
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.income,
    required this.expense,
    required this.warning,
    required this.accent,
  });

  final Color income;
  final Color expense;
  final Color warning;
  final Color accent;

  static const light = AppColors(
    income: Color(0xFF2E7D32),
    expense: Color(0xFFC62828),
    warning: Color(0xFFC2410C),
    accent: Color(0xFF00796B),
  );

  static const dark = AppColors(
    income: Color(0xFF81C784),
    expense: Color(0xFFE57373),
    warning: Color(0xFFFFB74D),
    accent: Color(0xFF4DB6AC),
  );

  @override
  AppColors copyWith({Color? income, Color? expense, Color? warning, Color? accent}) {
    return AppColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

/// 消费侧统一入口（Spec §3.3）：颜色/Token/字阶全应用唯一取用处
extension AppThemeX on BuildContext {
  /// 语义色（收入绿/支出红/预警橙，浅深锁定）
  AppColors get appColors => Theme.of(this).extension<AppColors>() ?? AppColors.light;

  /// 设计 Token（palette/金额字阶/卡片装饰）
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ??
      AppTokens(
        palette: kThemePresetsV2.first.palette,
        brightness: Brightness.light,
      );

  /// 当前主题完整调色板
  ThemePalette get palette => tokens.palette;

  /// 全局字阶（设计文档 §3.2 七级）
  TextTheme get text => Theme.of(this).textTheme;
}

/// 在任意颜色上保证可辨的前景色（动态对比选择，用于 secondary/error 等派生位）
Color onColorFor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A1A1A);

/// 应用主题组装（Spec §4）：
/// - 预制主题（t1..t8）：完整 ThemeData 直出，ColorScheme 显式构造（D1，不再 fromSeed）；
/// - 自定义模式（[preset] 为 null 或 id == 'custom'）：退回旧 fromSeed 路径
///   （D3，观感与旧版一致），此时 [customSeed] 为种子色，[customMode] 指示构建
///   浅色或深色槽位（MaterialApp theme/darkTheme 各调一次；system 由调用方
///   按槽位传 light/dark，不会传入）。
ThemeData buildTheme(
  AppThemePreset? preset, {
  Color? customSeed,
  ThemeMode? customMode,
}) {
  if (preset == null || preset.id == AppThemePreset.customId) {
    final brightness = switch (customMode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      // 兜底：未指定槽位时跟随平台（正常调用路径不会走到）
      _ => WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    return _buildCustomTheme(brightness, customSeed ?? kDefaultSeedColor);
  }
  return _buildPresetTheme(preset);
}

/// 预制主题：显式构造 ColorScheme + 组件主题（Spec §4.4，禁用 fromSeed 隐式派生）
ThemeData _buildPresetTheme(AppThemePreset preset) {
  final p = preset.palette;
  final dark = preset.isDark;
  final semantic = dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme(
    brightness: preset.brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.primaryContainer,
    onPrimaryContainer: p.textPrimary,
    secondary: p.secondary,
    onSecondary: onColorFor(p.secondary),
    secondaryContainer: p.primaryContainer,
    onSecondaryContainer: p.textPrimary,
    surface: p.surface,
    onSurface: p.textPrimary,
    surfaceContainerHighest: p.surfaceVariant,
    onSurfaceVariant: p.textSecondary,
    error: semantic.expense,
    onError: onColorFor(semantic.expense),
    errorContainer: semantic.expense.withValues(alpha: 0.12),
    onErrorContainer: semantic.expense,
    outline: p.border,
    outlineVariant: p.divider,
    scrim: p.scrim,
    shadow: p.scrim,
    // 保持调色板 surface 精确值，禁用 M3 海拔着色漂移
    surfaceTint: Colors.transparent,
    inverseSurface: p.textPrimary,
    onInverseSurface: p.background,
    inversePrimary: p.primaryContainer,
  );
  return _assemble(
    scheme: scheme,
    palette: p,
    brightness: preset.brightness,
    semantic: semantic.copyWith(accent: p.primary),
  );
}

/// 自定义种子色（旧路径）：fromSeed 派生 + 伪调色板（Token/组件主题照常生效，
/// 表面取值对齐旧版 M3 默认，观感不跳变，Spec §10 风险行）
ThemeData _buildCustomTheme(Brightness brightness, Color seedColor) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  final pseudo = ThemePalette(
    primary: scheme.primary,
    onPrimary: scheme.onPrimary,
    primaryContainer: scheme.primaryContainer,
    secondary: scheme.secondary,
    background: scheme.surface,
    surface: scheme.surface,
    surfaceVariant: scheme.surfaceContainerHighest,
    scrim: scheme.scrim,
    textPrimary: scheme.onSurface,
    textSecondary: scheme.onSurfaceVariant,
    textDisabled: scheme.outline,
    border: scheme.outlineVariant,
    divider: scheme.outlineVariant,
  );
  final semantic = dark ? AppColors.dark : AppColors.light;
  return _assemble(
    scheme: scheme,
    palette: pseudo,
    brightness: brightness,
    semantic: semantic.copyWith(accent: scheme.primary),
  );
}

/// 组件主题显式构造（BK-UI-004）：两条路径（预制/自定义）共用同一组装器
ThemeData _assemble({
  required ColorScheme scheme,
  required ThemePalette palette,
  required Brightness brightness,
  required AppColors semantic,
}) {
  final dark = brightness == Brightness.dark;
  final tokens = AppTokens(palette: palette, brightness: brightness);
  final textTheme = AppText.buildTextTheme(palette);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: palette.background,
    disabledColor: palette.textDisabled,
    hintColor: palette.textDisabled,
    extensions: [semantic, tokens],
    textTheme: textTheme,
    // AppBar 透明化（设计文档 §5.4.3）：与页面底色/背景遮罩一体化。
    // 注意：不再配置 systemOverlayStyle——状态栏图标明暗由 AppBackground
    // 按遮罩后有效亮度动态计算（设计文档 §5.2），静态值会覆盖动态结果
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: palette.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
    ),
    // 卡片：圆角 md；浅色海拔阴影 / 深色描边（设计文档 §3.3）
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: dark ? 0 : 2,
      shadowColor: palette.scrim.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: dark ? BorderSide(color: palette.border) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      indicatorColor: palette.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(textTheme.bodySmall),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      modalBarrierColor: palette.scrim.withValues(alpha: 0.54),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + AppSpacing.xs,
      ),
      labelStyle: textTheme.bodyMedium,
      hintStyle: textTheme.bodyMedium?.copyWith(color: palette.textDisabled),
      errorStyle: textTheme.bodySmall?.copyWith(color: semantic.expense),
      border: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: palette.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: semantic.expense),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: semantic.expense, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      backgroundColor: dark ? palette.surfaceVariant : palette.textPrimary,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: dark ? palette.textPrimary : palette.background,
      ),
      actionTextColor: palette.primary,
    ),
    dividerTheme: DividerThemeData(
      color: palette.divider,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      textColor: palette.textPrimary,
      iconColor: palette.textSecondary,
      subtitleTextStyle: textTheme.bodyMedium,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.primary),
  );
}
