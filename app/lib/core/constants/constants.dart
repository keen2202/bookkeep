/// 汇率定点刻度：1e6 表示 6 位小数（rate 1.0 = 1000000）
const kRateScale = 1000000;

/// 金额上下限（分）：0 < amount <= 10^13（01-开发建议 BK-P0-001）
const kMaxAmountMinor = 10000000000000;
