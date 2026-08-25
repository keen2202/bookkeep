import 'package:flutter/material.dart';

import 'glass_tokens.dart';
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

/// 语义色（收支金额/预警等**数据语义**，延续 doc-09/13 的 WCAG 锁定值，
/// 不随主题漂移；GlassThemeColors.success/danger 为 Spec §2.1 的
/// **交互件** Token——danger 着色玻璃按钮与输入错误环使用）。
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
    accent: GlassThemeColors.primaryLight,
  );

  static const dark = AppColors(
    income: Color(0xFF81C784),
    expense: Color(0xFFE57373),
    warning: Color(0xFFFFB74D),
    accent: GlassThemeColors.primaryDark,
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

/// 消费侧统一入口：颜色/Token/字阶全应用唯一取用处
extension AppThemeX on BuildContext {
  /// 语义色（收入绿/支出红/预警橙）
  AppColors get appColors => Theme.of(this).extension<AppColors>() ?? AppColors.light;

  /// 设计 Token（palette/金额字阶）
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ??
      AppTokens(
        palette: kThemePresetsV2.first.palette,
        brightness: Brightness.light,
      );

  /// 当前主题完整调色板
  ThemePalette get palette => tokens.palette;

  /// 全局字阶
  TextTheme get text => Theme.of(this).textTheme;
}

/// 在任意颜色上保证可辨的前景色（动态对比选择，用于 secondary/error 等派生位）
Color onColorFor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1C1C1E);

/// 应用主题组装（FGDS v1.0）：
/// - 预制主题（t1..t8）：完整 ThemeData 直出，ColorScheme 显式构造；
/// - 自定义模式（[preset] 为 null 或 id == 'custom'）：fromSeed 派生主色，
///   其余槽位与预制主题共用同一中性组（背景仍为 §2.2 白名单底色）；
/// - [customMode] 指示构建浅色或深色槽位。
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

/// 预制主题：显式构造 ColorScheme + 组件主题
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

/// 自定义种子色路径：仅主色随种子派生，中性槽位与玻璃参数同全局统一
/// （BK-FG-032；背景仍为 Spec §2.2 白名单底色，不做亮度钳制派生）。
ThemeData _buildCustomTheme(Brightness brightness, Color seedColor) {
  final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  final pseudo = ThemePalette(
    brightness: brightness,
    primary: scheme.primary,
    onPrimary: GlassThemeColors.onPrimary,
    primaryContainer: scheme.primaryContainer,
    secondary: scheme.secondary,
    background: brightness == Brightness.dark
        ? GlassBackground.baseDark
        : GlassBackground.baseLight,
    surface: brightness == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFFFFFFF),
    surfaceVariant: brightness == Brightness.dark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA),
    scrim: const Color(0xFF000000),
    textPrimary: GlassTextColors.primary(brightness),
    textSecondary: GlassTextColors.secondary(brightness),
    textTertiary: GlassTextColors.tertiary(brightness),
    textDisabled: GlassTextColors.disabled(brightness),
    border: brightness == Brightness.dark
        ? const Color(0xFFFFFFFF).withValues(alpha: 0.16)
        : const Color(0xFF000000).withValues(alpha: 0.12),
    divider: brightness == Brightness.dark
        ? const Color(0xFFFFFFFF).withValues(alpha: 0.08)
        : const Color(0xFF000000).withValues(alpha: 0.06),
  );
  final semantic = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  return _assemble(
    scheme: scheme,
    palette: pseudo,
    brightness: brightness,
    semantic: semantic.copyWith(accent: scheme.primary),
  );
}

/// 组件主题显式构造：两条路径（预制/自定义）共用同一组装器。
/// 浮层族（dialog/sheet/menu/snackbar）按 G4/G5 填充着色；真实磨砂由
/// 对应的收敛出口组件（AppDialog/AppSheet/AppSnack/GlassPanel）承载。
ThemeData _assemble({
  required ColorScheme scheme,
  required ThemePalette palette,
  required Brightness brightness,
  required AppColors semantic,
}) {
  final dark = brightness == Brightness.dark;
  final tokens = AppTokens(palette: palette, brightness: brightness);
  final textTheme = AppText.buildTextTheme(palette);

  // 层级填充解析（Spec §3 参数表；颜色仅供 M3 组件主题兜底槽位）
  final g2Fill = resolveGlassSpec(
          level: GlassLevel.g2, brightness: brightness, blurEnabled: true)
      .fill;
  // 输入框降档填充（Spec §4.8：默认 0.45 浅 / 0.10 深；禁用态
  // 0.24/0.05 由 AppTextField 显式覆盖 fillColor）
  final inputFill =
      const Color(0xFFFFFFFF).withValues(alpha: dark ? 0.10 : 0.45);
  final g4Fill = resolveGlassSpec(level: GlassLevel.g4, brightness: brightness)
      .fill;
  final g5Fill = resolveGlassSpec(level: GlassLevel.g5, brightness: brightness)
      .fill;
  final g3Fill = resolveGlassSpec(level: GlassLevel.g3, brightness: brightness)
      .fill;

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    // 背景（Spec §2.2）：Scaffold 底色即白名单底色，AppBackground 同色叠加
    scaffoldBackgroundColor:
        dark ? GlassBackground.baseDark : GlassBackground.baseLight,
    disabledColor: palette.textDisabled,
    hintColor: palette.textTertiary,
    extensions: [semantic, tokens],
    textTheme: textTheme,
    // AppBar 由 GlassAppBar（G3 吸附层）承载模糊；主题只管字色与零海拔
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: palette.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
    ),
    // 卡片：真实磨砂由 AppCard→GlassPanel 承载，Card 仅作语义容器兜底
    cardTheme: CardThemeData(
      color: g2Fill,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: palette.divider, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    // 底部导航栏：G3 填充（真实磨砂由自定义 GlassBottomBar 承载）
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: g3Fill,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.primary
                : palette.textSecondary,
          )),
    ),
    // 底部弹层（Spec §4.7）：G4 填充 + 顶部圆角 20 + 遮罩 α0.32
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: g4Fill,
      modalBarrierColor: GlassBackground.scrimOf(const Color(0xFF000000)),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: g4Fill,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyLarge,
    ),
    // SnackBar（Spec §4.7）：G5 胶囊由 AppSnack 承载，主题兜底透明容器
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
      backgroundColor: g5Fill,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: palette.textPrimary,
      ),
      actionTextColor: palette.primary,
    ),
    // 输入框（Spec §4.8）：G2 降档填充、R12/H44、聚焦环 primary α0.50、
    // 错误环 danger α0.60、禁用 fill 0.24/0.05
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      constraints: const BoxConstraints(minHeight: 44),
      labelStyle: textTheme.bodyLarge,
      hintStyle: textTheme.bodyLarge?.copyWith(color: palette.textTertiary),
      errorStyle: textTheme.bodySmall?.copyWith(color: semantic.expense),
      border: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: palette.border, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: palette.border, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(
          color: palette.primary.withValues(alpha: 0.50),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(
          color: semantic.expense.withValues(alpha: 0.60),
          width: 0.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(
          color: semantic.expense.withValues(alpha: 0.60),
          width: 2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: palette.border, width: 0.5),
      ),
    ),
    // 下拉菜单/弹出菜单（Spec §4.7）：G4 填充 + R20 + 发丝描边
    popupMenuTheme: PopupMenuThemeData(
      color: g4Fill,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: palette.border, width: 0.5),
      ),
      textStyle: textTheme.bodyLarge,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(g4Fill),
        elevation: const WidgetStatePropertyAll(0),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: AppRadius.lgAll,
            side: BorderSide(color: palette.border, width: 0.5),
          ),
        ),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(g4Fill),
        elevation: const WidgetStatePropertyAll(0),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: AppRadius.lgAll,
            side: BorderSide(color: palette.border, width: 0.5),
          ),
        ),
      ),
    ),
    // 复选框/开关：选中侧主色实心（功能控件，非选中态呈现，AC-07 不适用）
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: palette.border, width: 1),
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? palette.primary
              : Colors.transparent),
      checkColor: WidgetStatePropertyAll(palette.onPrimary),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? palette.primary
              : palette.surfaceVariant),
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? palette.onPrimary
              : palette.textSecondary),
      trackOutlineColor: WidgetStatePropertyAll(palette.border),
    ),
    // Chip（筛选类小控件）：未选 G2 降档填充；选中走 FG-SEL 叠加层近似
    // （primary α0.12 顶渐变叠加 + 外缘 primary α0.30 描边，无实色填充）
    chipTheme: ChipThemeData(
      backgroundColor: inputFill,
      side: BorderSide(
        color: palette.border,
        width: 0.5,
      ),
      selectedColor: palette.primary.withValues(alpha: 0.12),
      checkmarkColor: palette.primary,
      labelStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.primary,
      inactiveTrackColor: palette.divider,
      thumbColor: palette.surface,
      overlayColor: palette.primary.withValues(alpha: 0.12),
      trackHeight: 4,
    ),
    iconTheme: IconThemeData(color: palette.textPrimary),
    dividerTheme: DividerThemeData(
      color: palette.divider,
      thickness: 0.5,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      textColor: palette.textPrimary,
      iconColor: palette.textSecondary,
      subtitleTextStyle: textTheme.bodyMedium,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.primary),
    // FAB（Spec §4.7）：G5 着色玻璃由调用处承载，主题关闭默认外观
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),
  );
}
