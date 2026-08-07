import '../../../core/utils/csv.dart';
import '../../../data/local/tables/transactions_table.dart';
import '../../../domain/services/capture_candidate.dart';

/// CSV 解析器策略（Spec §4.2 / BK-T-011）：每渠道一个 Parser，统一输出候选
abstract class CsvTransactionParser {
  String get name;
  List<CaptureCandidate> parse(String csv);
}

/// 解析失败时跳过该行，返回 null 行
typedef _RowParser = CaptureCandidate? Function(Map<String, String> row, String raw);

class _BaseParser implements CsvTransactionParser {
  _BaseParser(this.name, this._rowParser, this._headerMarkers);

  @override
  final String name;
  final _RowParser _rowParser;

  /// 表头识别标记（审查 L-9）：前若干行可能是元信息（导出时间/账户等），
  /// 表头行定位后从下一行开始解析，元信息行不再被误判
  final List<String> _headerMarkers;

  /// 表头自动定位窗口（4-20 行元信息头）
  static const maxHeaderScanRows = 20;

  @override
  List<CaptureCandidate> parse(String csv) {
    final rows = parseCsv(csv);
    final headerIndex = _locateHeader(rows);
    if (headerIndex == null) return const [];
    final result = <CaptureCandidate>[];
    for (var i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || (row.length == 1 && row.first.trim().isEmpty)) continue;
      final raw = row.join(',');
      final map = <String, String>{
        for (var c = 0; c < row.length; c++) 'c$c': row[c].trim(),
      };
      final candidate = _rowParser(map, raw);
      if (candidate != null) result.add(candidate);
    }
    return result;
  }

  /// 在前 [maxHeaderScanRows] 行内定位表头行（含全部标记列）；找不到返回 null
  int? _locateHeader(List<List<String>> rows) {
    final scanEnd = rows.length < maxHeaderScanRows ? rows.length : maxHeaderScanRows;
    for (var i = 0; i < scanEnd; i++) {
      final joined = rows[i].join(',');
      if (_headerMarkers.every(joined.contains)) return i;
    }
    return null;
  }
}

String _clean(String s) => s.replaceAll(RegExp(r'["\s]'), '');

/// 支付宝账单 CSV（交易时间,交易分类,交易对方,商品说明,收/支,金额,支付方式,交易状态,...
/// 支出金额为负数、收入为正数；状态过滤：交易成功/还款成功
class AlipayCsvParser extends _BaseParser {
  AlipayCsvParser()
      : super('支付宝', _parseRow, const ['交易时间', '交易分类', '收/支', '金额']);

  static CaptureCandidate? _parseRow(Map<String, String> row, String raw) {
    final time = row['c0'];
    final counterparty = row['c2'] ?? '';
    final direction = row['c4'];
    final amountRaw = row['c5'];
    final status = row['c7'] ?? '';
    if (time == null || direction == null || amountRaw == null) return null;
    if (!status.contains('成功')) return null;

    final occurredAt = DateTime.tryParse(time);
    if (occurredAt == null) return null;

    final amount = _parseAmount(amountRaw);
    if (amount == null || amount == 0) return null;

    final isExpense = direction.contains('支出');
    final isIncome = direction.contains('收入');
    if (!isExpense && !isIncome) return null;

    return CaptureCandidate(
      amountMinor: isExpense ? -amount : amount,
      occurredAt: occurredAt,
      counterparty: counterparty,
      type: isExpense ? TransactionType.expense : TransactionType.income,
      source: 'alipay',
      raw: raw,
    );
  }
}

/// 微信支付账单 CSV（交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,...
class WechatCsvParser extends _BaseParser {
  WechatCsvParser()
      : super('微信', _parseRow, const ['交易时间', '交易类型', '收/支', '金额']);

  static CaptureCandidate? _parseRow(Map<String, String> row, String raw) {
    final time = row['c0'];
    final counterparty = row['c2'] ?? '';
    final direction = row['c4'];
    final amountRaw = row['c5'];
    final status = row['c7'] ?? '';
    if (time == null || direction == null || amountRaw == null) return null;
    if (!status.contains('支付成功') && !status.contains('已收款')) return null;

    final occurredAt = DateTime.tryParse(time);
    if (occurredAt == null) return null;

    final amount = _parseAmount(amountRaw);
    if (amount == null || amount == 0) return null;

    final isExpense = direction.contains('支出');
    final isIncome = direction.contains('收入');
    if (!isExpense && !isIncome) return null;

    return CaptureCandidate(
      amountMinor: isExpense ? -amount : amount,
      occurredAt: occurredAt,
      counterparty: counterparty,
      type: isExpense ? TransactionType.expense : TransactionType.income,
      source: 'wechat',
      raw: raw,
    );
  }
}

/// 金额 → 分（审查 L-9：整数域解析，杜绝 double 精度误差；
/// 已带负号时按收/支方向语义处理）
int? _parseAmount(String raw) {
  final cleaned = _clean(raw).replaceAll('¥', '').replaceAll('元', '').replaceAll(',', '');
  final negative = cleaned.startsWith('-');
  final number = cleaned.replaceFirst('-', '');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(number);
  if (match == null) return null;
  final yuan = int.parse(match.group(1)!);
  final centsRaw = match.group(2) ?? '';
  final cents = int.parse(centsRaw.padRight(2, '0'));
  final minor = yuan * 100 + cents;
  return negative ? -minor : minor;
}
