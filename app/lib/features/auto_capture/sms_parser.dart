import '../../data/local/tables/transactions_table.dart';
import '../../domain/services/capture_candidate.dart';

/// 短信/通知文本抽取（Spec §4.2 / BK-T-011）：正则抽取金额/商户/收支方向。
/// 纯规则引擎（LLM 接口抽象层见 voice_entry_sheet.dart，默认关闭）。
class SmsCaptureParser {
  // 金额：优先货币符号后的金额（避免误匹配尾号等前置数字），支持千分位
  static final _currencyAmountRe =
      RegExp(r'[¥￥]\s*((?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?)');
  static final _plainAmountRe =
      RegExp(r'((?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?)');
  // 支出方向词：排除「付款方/收款方」标签与「支付宝」/「【支付】」品牌
  static final _expenseRe = RegExp(
      r'(支出|消费|扣款|支付(?![宝】])|付款(?!方)|转账(?:给|至)|还款|花了?|买(?:了|东西))');
  static final _incomeRe = RegExp(r'(收入|入账|到账|收款(?!方)|收到|转入)');
  // 对方抽取：标签后跟分隔符（商户：X / 付款方：Y / 来自：Z），或「向 X 付款」
  static final _counterpartyRe = RegExp(
    r'(?:商户|付款方|收款方|汇款人|来自)\s*[：:]\s*([^\s，。,；;]+)'
    r'|(?:支付|付款|消费|到账|收到|收款)\s*[：:于至]\s*([^\s，。,；;]+)'
    r'|(?:向|给)\s*([^\s，。,；;]+?)\s*(?:支付|付款|消费|转账)',
  );

  /// 解析单条短信；无法确认金额/方向时返回 null（不产生候选）
  CaptureCandidate? parse(String text) {
    final amountMatch =
        _currencyAmountRe.firstMatch(text) ?? _plainAmountRe.firstMatch(text);
    if (amountMatch == null) return null;
    final amountMinor = _parseAmount(amountMatch.group(1)!);
    if (amountMinor == null || amountMinor == 0) return null;

    final isExpense = _expenseRe.hasMatch(text);
    final isIncome = _incomeRe.hasMatch(text);
    if (isExpense == isIncome) return null; // 方向不明或两者皆无 → 跳过

    final counterparty = _counterpartyRe.firstMatch(text)?.group(1) ??
        _counterpartyRe.firstMatch(text)?.group(2) ??
        _counterpartyRe.firstMatch(text)?.group(3) ??
        '未知商户';
    return CaptureCandidate(
      amountMinor: isExpense ? -amountMinor : amountMinor,
      occurredAt: DateTime.now(),
      counterparty: counterparty,
      type: isExpense ? TransactionType.expense : TransactionType.income,
      source: 'sms',
      raw: text,
    );
  }

  int? _parseAmount(String s) {
    final cleaned = s.replaceAll(',', '');
    final value = double.tryParse(cleaned);
    return value == null ? null : (value * 100).round();
  }
}
