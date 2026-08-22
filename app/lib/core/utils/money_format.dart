import 'dart:math' as math;

/// 金额（整数最小货币单位）→ 显示字符串，如 12345 → "123.45"
String formatMoney(int minor, {String symbol = '¥'}) {
  final abs = minor.abs();
  final yuan = abs ~/ 100;
  final cents = (abs % 100).toString().padLeft(2, '0');
  final sign = minor < 0 ? '-' : '';
  return '$sign$symbol$yuan.$cents';
}

/// 锁定态金额掩码（Spec §3.6 脱敏：列表/报表/账户）
String maskedMoney({String symbol = '¥'}) => '$symbol***';

/// 报表/现金流坐标轴可读刻度：大额转「x.x万 / x.x百万」，小额原样；
/// 负值保留单个符号。金额单位为最小货币单位（分，1 万 = 1,000,000 分）。
/// 刻度错位修复：「万」此前按 100,000 分换算，标签放大 10 倍
/// （¥20,000 被标成「20.0万」）；且负值经 formatMoney 产生「--」双符号。
String compactTickLabel(int minor) {
  final abs = minor.abs();
  final sign = minor < 0 ? '-' : '';
  if (abs >= 100000000) return '$sign${(abs / 100000000).toStringAsFixed(1)}百万';
  if (abs >= 1000000) return '$sign${(abs / 1000000).toStringAsFixed(1)}万';
  return '$sign${formatMoney(abs, symbol: '')}';
}

/// 坐标轴「好看」的刻度步长（1/2/5×10^k）：用于柱状/折线 y 轴刻度均匀分布，
/// 避免默认间隔在极端量级下产生过密/过疏刻度（x/y 轴比例失衡的观感来源）。
double niceAxisStep(double rawStep) {
  if (rawStep <= 0 || rawStep.isNaN || rawStep.isInfinite) return 1;
  final magnitude =
      math.pow(10, (math.log(rawStep) / math.ln10).floorToDouble()).toDouble();
  final normalized = rawStep / magnitude;
  if (normalized <= 1) return magnitude;
  if (normalized <= 2) return 2 * magnitude;
  if (normalized <= 5) return 5 * magnitude;
  return 10 * magnitude;
}

