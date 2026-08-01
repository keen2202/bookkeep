/// 金额（整数最小货币单位）→ 显示字符串，如 12345 → "123.45"
String formatMoney(int minor, {String symbol = '¥'}) {
  final abs = minor.abs();
  final yuan = abs ~/ 100;
  final cents = (abs % 100).toString().padLeft(2, '0');
  final sign = minor < 0 ? '-' : '';
  return '$sign$symbol$yuan.$cents';
}
