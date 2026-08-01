import '../../core/constants/constants.dart';

/// 金额值对象（Spec §4.5 / BK-T-014）：整数最小货币单位 + 币种 + 汇率快照。
/// 换算在定点整数域完成（禁止 float/double 直接参与金额运算）。
class Money {
  const Money({required this.amountMinor, required this.currency, this.rateSnapshot});

  /// 分
  final int amountMinor;
  final String currency;

  /// 记账时汇率快照（相对主币种，kRateScale 刻度）；null = 主币种
  final int? rateSnapshot;

  /// 定点换算为指定币种金额（汇率刻度 kRateScale；四舍五入到分）。
  /// 汇率变化不回溯历史：换算基于快照（Spec §4.5 历史流水不随汇率波动）。
  static int convert({
    required int amountMinor,
    required int rateScaled,
    int scale = kRateScale,
  }) {
    // 正负数统一四舍五入（half-up）：分子加符号相关的一半
    final half = amountMinor >= 0 ? scale ~/ 2 : -(scale ~/ 2);
    return (amountMinor * rateScaled + half) ~/ scale;
  }

  /// 按当前汇率快照折算到主币种（分）；无快照视为主币种
  int toBaseMinor() {
    final rate = rateSnapshot ?? kRateScale;
    return convert(amountMinor: amountMinor, rateScaled: rate);
  }
}

/// 定点舍入测试工具：half-up 语义
int roundToMinor(double value) => (value * 100).round();
