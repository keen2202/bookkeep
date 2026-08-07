import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 8 色调色板（审查 U-5：语义色统一提取至 constants，浅深两态可复用）
const kAppPalette = <Color>[
  Color(0xFF00897B), // teal 600（品牌主色）
  Color(0xFF26A69A), // teal 400
  Color(0xFF80CBC4), // teal 200
  Color(0xFF2E7D32), // green 800（收入）
  Color(0xFFC62828), // red 800（支出）
  Color(0xFFEF6C00), // orange 800（预警）
  Color(0xFF90A4AE), // blue-grey 300
  Color(0xFF546E7A), // blue-grey 600
];

/// 语义色（审查 U-5/U-8）：红/绿/橙/teal 硬编码替换为语义色，
/// 深色模式自动适配（浅深两套，对比度达 WCAG 4.5:1）
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
    // 对比度验收：对白底 ≥ 4.5:1（橙 800/teal 600 不达标，取更深一档）
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

extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

/// 应用主题（审查 U-2）：浅深两态同源构建；系统栏样式随 Brightness 联动
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kAppPalette[0],
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    extensions: [dark ? AppColors.dark : AppColors.light],
    appBarTheme: AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
