import '../../data/local/tables/transactions_table.dart';

/// 自动记账候选（Spec §4.2 / BK-T-011）：解析/识别结果必须经确认页才可入账
/// （禁止静默写入）。来源：CSV 导入 / 通知短信解析。
class CaptureCandidate {
  const CaptureCandidate({
    required this.amountMinor,
    required this.occurredAt,
    required this.counterparty,
    required this.type,
    this.categoryName,
    this.source,
    this.raw,
  });

  /// 金额（分；支出为负，收入为正）
  final int amountMinor;
  final DateTime occurredAt;
  /// 对方（商户/对方账户），作为备注与去重键
  final String counterparty;
  final TransactionType type;
  /// 建议分类名（可空；确认页可改）
  final String? categoryName;
  final String? source;
  final String? raw;

  /// 去重键：金额 + 时间（秒级）+ 对方（Spec §4.2 去重（金额+时间+对方））
  String dedupKey() =>
      '$amountMinor|${occurredAt.toUtc().millisecondsSinceEpoch ~/ 1000}|$counterparty';
}

/// 候选解析结果
class CaptureParseResult {
  const CaptureParseResult({required this.candidates, this.parsed, this.failed = 0});
  final List<CaptureCandidate> candidates;
  final int? parsed;
  final int failed;
}
