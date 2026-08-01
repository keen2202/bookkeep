/// 轻量 CSV 解析（BK-T-011/BK-T-012）：支持引号包裹、字段内逗号/引号/换行转义。
/// 支付宝/微信账单导出格式为逗号分隔，无外部依赖。
List<List<String>> parseCsv(String input, {String eol = '\n'}) {
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var inQuotes = false;
  var i = 0;

  void endField() {
    row.add(field.toString());
    field = StringBuffer();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = [];
  }

  while (i < input.length) {
    final ch = input[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
    } else {
      switch (ch) {
        case '"':
          inQuotes = true;
        case ',':
          endField();
        default:
          if (ch == eol || (eol == '\n' && ch == '\r' && i + 1 < input.length && input[i + 1] == '\n')) {
            if (ch == '\r') i++; // 跳过 \r\n 的 \r
            endRow();
          } else {
            field.write(ch);
          }
      }
    }
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// CSV 字段转义（导出用；BK-T-012）
String escapeCsvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
