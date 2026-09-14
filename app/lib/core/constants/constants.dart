/// 汇率定点刻度：1e6 表示 6 位小数（rate 1.0 = 1000000）
const kRateScale = 1000000;

/// 金额上下限（分）：0 < amount <= 10^13（01-开发建议 BK-P0-001）
const kMaxAmountMinor = 10000000000000;

/// 同步/账本服务端地址：优先编译期注入 SERVER_URL，缺省本地开发地址。
/// 发布构建必须注入 https 地址（HttpSyncApi 会强制校验，Spec R-06）。
const kServerBaseUrl = String.fromEnvironment(
  'SERVER_URL',
  defaultValue: 'http://localhost:3000',
);
