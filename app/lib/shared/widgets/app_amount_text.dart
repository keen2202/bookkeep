import 'package:flutter/material.dart';

import '../../core/utils/money_format.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// 金额语气（收支自动着色，设计文档 §3.4 图表/金额规范）
enum AppAmountTone { income, expense, neutral }

/// 统一金额文本（Spec §6）：等宽数字（tabular-nums）+ 收支语义自动着色。
/// 全部金额展示位的收敛出口（替代页面内 titleSmall?.copyWith(color:) 写法）。
class AppAmountText extends StatelessWidget {
  const AppAmountText(
    this.text, {
    super.key,
    this.tone = AppAmountTone.neutral,
    this.large = false,
    this.color,
    this.style,
    this.textAlign,
    this.maxLines,
  });

  /// 最小货币单位金额（分）构造：自动格式化，默认按符号推导收支语气
  /// （负=支出红 / 正=收入绿 / 零=中性；[signed] 正值带 '+' 前缀）；
  /// [tone] 显式指定语气（如按交易类型着色）时优先于符号推导。
  factory AppAmountText.minor(
    int minor, {
    Key? key,
    bool masked = false,
    bool signed = true,
    bool large = false,
    AppAmountTone? tone,
    Color? color,
    TextStyle? style,
    TextAlign? textAlign,
  }) {
    final derived = tone ??
        (minor < 0
            ? AppAmountTone.expense
            : minor > 0
                ? AppAmountTone.income
                : AppAmountTone.neutral);
    final text = masked
        ? maskedMoney()
        : (signed && minor > 0 ? '+' : '') + formatMoney(minor);
    return AppAmountText(
      text,
      key: key,
      tone: derived,
      large: large,
      color: color,
      style: style,
      textAlign: textAlign,
    );
  }

  final String text;
  final AppAmountTone tone;

  /// 大数字档（displayAmount 34sp）；默认列表档（amount 17sp）
  final bool large;

  /// 显式颜色优先于语气着色
  final Color? color;

  /// 字阶覆盖（BK-DOC-26 需求1：如账单行金额对齐页面标题 titleLarge）；
  /// 语义着色与等宽数字仍然生效
  final TextStyle? style;

  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final appColors = context.appColors;
    final effectiveColor = color ??
        switch (tone) {
          AppAmountTone.income => appColors.income,
          AppAmountTone.expense => appColors.expense,
          AppAmountTone.neutral => tokens.palette.textPrimary,
        };
    final base = style ?? (large ? tokens.displayAmountStyle : tokens.amountStyle);
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      // 覆盖字阶时保持等宽数字（金额列纵向对齐不回归）
      style: base.copyWith(
        color: effectiveColor,
        fontFeatures: AppText.tabularFigures,
      ),
    );
  }
}
