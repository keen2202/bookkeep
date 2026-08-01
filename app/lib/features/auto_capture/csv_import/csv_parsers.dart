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
  _BaseParser(this.name, this._rowParser);

  @override
  final String name;
  final _RowParser _rowParser;

  /// 支付宝/微信账单首行为表头
  static const headerSkip = 1;

  @override
  List<CaptureCandidate> parse(String csv) {
    final rows = parseCsv(csv);
    final result = <CaptureCandidate>[];
    for (var i = headerSkip; i < rows.length; i++) {
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
}

String _clean(String s) => s.replaceAll(RegExp(r'["\s]'), '');

/// 支付宝账单 CSV（交易时间,交易分类,交易对方,商品说明,收/支,金额,支付方式,交易状态,...
/// 支出金额为负数、收入为正数；状态过滤：交易成功/还款成功
class AlipayCsvParser extends _BaseParser {
  AlipayCsvParser() : super('支付宝', _parseRow);

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
  WechatCsvParser() : super('微信', _parseRow);

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

/// 金额 → 分（正数绝对值；已带负号时按收/支方向语义处理）
int? _parseAmount(String raw) {
  final cleaned = _clean(raw).replaceAll('¥', '').replaceAll('元', '');
  final negative = cleaned.startsWith('-');
  final number = cleaned.replaceFirst('-', '');
  final value = double.tryParse(number);
  if (value == null) return null;
  final minor = (value * 100).round();
  return negative ? -minor : minor;
}
