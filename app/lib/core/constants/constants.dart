/// 汇率定点刻度：1e6 表示 6 位小数（rate 1.0 = 1000000）
const kRateScale = 1000000;

/// 金额上下限（分）：0 < amount <= 10^13（01-开发建议 BK-P0-001）
const kMaxAmountMinor = 10000000000000;

/// 无显式账本上下文时的本地账本分区 id（BK-T-010）：
/// 仅作为列默认值与测试回退值；生产当前账本来自 app_meta（随机 uuid，
/// v4 迁移保留既有 sync_book_id），避免固定 id 造成跨用户服务端账本串扰。
const kDefaultBookId = '00000000-0000-4000-8000-000000000001';

/// 同步/账本服务端地址（开发环境；发布版经配置注入）
const kServerBaseUrl = 'http://localhost:3000';
