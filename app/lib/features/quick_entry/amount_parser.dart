import '../../core/constants/constants.dart';

/// 金额输入解析（Spec §3.1 / BK-P0-001）：
/// 元 → 整数分；支持 + / - 简易运算式；非法输入返回 null。
/// 校验：0 < amount ≤ 10^13 分。
class AmountParser {
  // 允许尾部小数点（如 "25." = 2500 分）
  static const _term = r'\d+(\.\d{0,2})?|\.\d{1,2}';
  static final _expression =
      RegExp('^($_term)([+-]($_term))*\$');
  static final _token = RegExp('$_term|[+-]');

  static int? parse(String input) {
    final text = input.trim();
    if (text.isEmpty || !_expression.hasMatch(text)) return null;

    var total = 0;
    var op = 1;
    for (final token in _token.allMatches(text).map((m) => m.group(0)!)) {
      if (token == '+') {
        op = 1;
      } else if (token == '-') {
        op = -1;
      } else {
        total += op * _toMinor(token);
      }
    }
    if (total <= 0 || total > kMaxAmountMinor) return null;
    return total;
  }

  static int _toMinor(String term) {
    final parts = term.split('.');
    final yuan = parts[0].isEmpty ? 0 : int.parse(parts[0]);
    final cents = parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0;
    return yuan * 100 + cents;
  }
}
