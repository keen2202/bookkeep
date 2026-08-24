import 'package:flutter/material.dart';

import 'glass/glass_layers.dart';
import 'glass/glass_quality.dart';
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

/// 应用主题组装（Spec §4 + v3 §5 组件主题玻璃化）：
/// - 预制主题（t1..t8）：完整 ThemeData 直出，ColorScheme 显式构造（D1，不再 fromSeed）；
/// - 自定义模式（[preset] 为 null 或 id == 'custom'）：退回旧 fromSeed 路径
///   （D3，观感与旧版一致），此时 [customSeed] 为种子色，[customMode] 指示构建
///   浅色或深色槽位（MaterialApp theme/darkTheme 各调一次；system 由调用方
///   按槽位传 light/dark，不会传入）；
/// - [quality]：玻璃画质三档（v3 D6 默认 standard），决定组件主题的
///   σ 分支与填充补偿；Golden 全部以 standard 档渲染（Spec §10）。
ThemeData buildTheme(
  AppThemePreset? preset, {
  Color? customSeed,
  ThemeMode? customMode,
  GlassQuality quality = GlassQuality.standard,
}) {
  if (preset == null || preset.id == AppThemePreset.customId) {
    final brightness = switch (customMode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      // 兜底：未指定槽位时跟随平台（正常调用路径不会走到）
      _ => WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    return _buildCustomTheme(brightness, customSeed ?? kDefaultSeedColor,
        quality: quality);
  }
  return _buildPresetTheme(preset, quality: quality);
}

/// 预制主题：显式构造 ColorScheme + 组件主题（Spec §4.4，禁用 fromSeed 隐式派生）
ThemeData _buildPresetTheme(
  AppThemePreset preset, {
  GlassQuality quality = GlassQuality.standard,
}) {
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
    quality: quality,
  );
}

/// 自定义种子色（旧路径）：fromSeed 派生 + 伪调色板（Token/组件主题照常生效，
/// 表面取值对齐旧版 M3 默认，观感不跳变，Spec §10 风险行）。
/// v3：glass 系字段由 ThemePalette 派生 getter 提供；ambient 补齐第 4 元素；
/// 背景「非纯黑/纯白」禁令（Spec §4.7）经 [clampBackgroundLuminance] 兜底
/// ——M3 深色 surface 相对亮度可能低至 ~0.007，越界即按二分插值提亮/压暗。
ThemeData _buildCustomTheme(
  Brightness brightness,
  Color seedColor, {
  GlassQuality quality = GlassQuality.standard,
}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  final pseudo = ThemePalette(
    brightness: brightness,
    primary: scheme.primary,
    onPrimary: scheme.onPrimary,
    primaryContainer: scheme.primaryContainer,
    secondary: scheme.secondary,
    background: clampBackgroundLuminance(scheme.surface),
    surface: scheme.surface,
    surfaceVariant: scheme.surfaceContainerHighest,
    scrim: scheme.scrim,
    textPrimary: scheme.onSurface,
    textSecondary: scheme.onSurfaceVariant,
    textDisabled: scheme.outline,
    border: scheme.outlineVariant,
    divider: scheme.outlineVariant,
    // 环境光 Token（v2 起）：由 M3 派生色合成；v3 补第 4 色（同族混色）
    ambient: [
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.surfaceContainerHighest,
      Color.lerp(scheme.primaryContainer, scheme.secondaryContainer, 0.5)!,
    ],
  );
  final semantic = dark ? AppColors.dark : AppColors.light;
  return _assemble(
    scheme: scheme,
    palette: pseudo,
    brightness: brightness,
    semantic: semantic.copyWith(accent: scheme.primary),
    quality: quality,
  );
}

/// 背景相对亮度合法区间（开区间，Spec §4.7：禁止纯黑/纯白）
const kBackgroundLumMin = 0.01;
const kBackgroundLumMax = 0.99;

/// 把派生背景钳入相对亮度 (0.01, 0.99)：越界时向白（过暗）或向黑（过亮）
/// 二分插值，取最小可行偏移以保留原色温观感（12 轮收敛精度远高于视觉
/// 可辨阈值）。预制主题取值已合规，本函数仅服务 custom 派生路径兜底。
Color clampBackgroundLuminance(Color color) {
  bool ok(double lum) =>
      lum > kBackgroundLumMin && lum < kBackgroundLumMax;
  if (ok(glassRelativeLuminance(color))) return color;
  final anchor = glassRelativeLuminance(color) <= kBackgroundLumMin
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF000000);
  var lo = 0.0;
  var hi = 1.0;
  for (var i = 0; i < 12; i++) {
    final mid = (lo + hi) / 2;
    if (ok(glassRelativeLuminance(Color.lerp(color, anchor, mid)!))) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return Color.lerp(color, anchor, hi)!;
}

/// 组件主题显式构造（BK-UI-004 + 玻璃拟态 v3 §5）：两条路径（预制/自定义）
/// 共用同一组装器。玻璃组件主题全部经 [resolveGlassSpec] 按 tier 解析
/// （GLS-005：card/navigationBar/bottomSheet/dialog/snackBar 按层级；
/// GLS-006：表单族玻璃规格）。
ThemeData _assemble({
  required ColorScheme scheme,
  required ThemePalette palette,
  required Brightness brightness,
  required AppColors semantic,
  GlassQuality quality = GlassQuality.standard,
}) {
  final dark = brightness == Brightness.dark;
  final tokens = AppTokens(
    palette: palette,
    brightness: brightness,
    glassQuality: quality,
  );
  final textTheme = AppText.buildTextTheme(palette);

  // 层级规格解析（Spec §2.2）：L1 内容面板 / L2 吸附 / L3 浮层 / L4 悬浮提示
  final panelSpec = resolveGlassSpec(
    tier: GlassTier.panel,
    brightness: brightness,
    palette: palette,
    quality: quality,
  );
  final dockSpec = resolveGlassSpec(
    tier: GlassTier.dock,
    brightness: brightness,
    palette: palette,
    quality: quality,
  );
  final overlaySpec = resolveGlassSpec(
    tier: GlassTier.overlay,
    brightness: brightness,
    palette: palette,
    quality: quality,
  );
  final floatingSpec = resolveGlassSpec(
    tier: GlassTier.floating,
    brightness: brightness,
    palette: palette,
    quality: quality,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    // 玻璃拟态（Glassmorphism v2）：Scaffold 透明化，页面底色让位给
    // AppBackground 的环境光渐变 / 背景图+智能遮罩（设计文档 §5.1）。
    scaffoldBackgroundColor: Colors.transparent,
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
    // 卡片（v3 §5.1）：L1 面板填充 + 描边；clip antiAlias。
    // 阴影由 GlassPanel/AppCard 装饰承载（Card 仅作语义容器兜底）
    cardTheme: CardThemeData(
      color: panelSpec.fill,
      elevation: dark ? 0 : 2,
      shadowColor: palette.scrim.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: BorderSide(color: panelSpec.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    // 底部导航栏（v3 §5.1）：L2 吸附层填充；未选中 label/icon textSecondary，
    // 选中项 primary（AC-01：滚动内容穿透呈现真实磨砂，high 档起效）
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dockSpec.fill,
      indicatorColor: palette.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(textTheme.bodySmall),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.primary
                : palette.textSecondary,
          )),
    ),
    // 底部弹层 / 对话框（v3 §5.1）：L3 浮层填充 + lg 圆角；背板 scrim 54% 不变
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: overlaySpec.fill,
      modalBarrierColor: palette.scrim.withValues(alpha: 0.54),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: overlaySpec.fill,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyLarge,
    ),
    // SnackBar（v3 §5.1）：L4 悬浮提示层填充
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      backgroundColor: floatingSpec.fill,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: palette.textPrimary,
      ),
      actionTextColor: palette.primary,
    ),
    // 输入框（v3 §5.1）：玻璃填充浅 0x1FFFFFFF / 深 0x0FFFFFFF；
    // focus 光晕由 AppTextField 外层 AnimatedContainer 提供
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor:
          dark ? const Color(0x0FFFFFFF) : const Color(0x1FFFFFFF),
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
    // 下拉菜单/弹出菜单（v3 §5.1）：容器按 L3 规格渲染，elevation 0
    // （阴影归 GlassPanel/Menu 体系，禁 M3 默认海拔着色）
    popupMenuTheme: PopupMenuThemeData(
      color: overlaySpec.fill,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.smAll,
        side: BorderSide(color: overlaySpec.borderColor),
      ),
      textStyle: textTheme.bodyLarge,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(overlaySpec.fill),
        elevation: const WidgetStatePropertyAll(0),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: AppRadius.smAll,
            side: BorderSide(color: overlaySpec.borderColor),
          ),
        ),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(overlaySpec.fill),
        elevation: const WidgetStatePropertyAll(0),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: AppRadius.smAll,
            side: BorderSide(color: overlaySpec.borderColor),
          ),
        ),
      ),
    ),
    // 复选框/开关（v3 §5.1）：未选侧 L1 填充 + 描边；选中侧语义实心不变
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: panelSpec.borderColor, width: 1),
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? palette.primary
              : panelSpec.fill),
      checkColor: WidgetStatePropertyAll(palette.onPrimary),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? palette.primary
              : panelSpec.fill),
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? palette.onPrimary
              : palette.textSecondary),
      trackOutlineColor: WidgetStatePropertyAll(panelSpec.borderColor),
    ),
    // Chip（v3 §5.1）：未选 L1 填充；选中 primaryContainer α0.70
    chipTheme: ChipThemeData(
      backgroundColor: panelSpec.fill,
      side: BorderSide(color: panelSpec.borderColor),
      selectedColor: palette.primaryContainer.withValues(alpha: 0.70),
      checkmarkColor: palette.primary,
      labelStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
    ),
    // 滑杆（v3 §5.1）：inactive divider α0.5 / active primary；拇指白芯描边
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.primary,
      inactiveTrackColor: palette.divider.withValues(alpha: 0.5),
      thumbColor: palette.surface,
      overlayColor: palette.primary.withValues(alpha: 0.12),
      trackHeight: 4,
    ),
    iconTheme: IconThemeData(color: palette.textPrimary),
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
