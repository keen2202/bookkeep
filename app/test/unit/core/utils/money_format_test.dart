import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/core/utils/money_format.dart';

void main() {
  test('formats positive amounts', () {
    expect(formatMoney(12345), '¥123.45');
    expect(formatMoney(1000), '¥10.00');
    expect(formatMoney(1), '¥0.01');
  });

  test('formats negative amounts with a single leading minus', () {
    expect(formatMoney(-2550), '-¥25.50');
    expect(formatMoney(-100), '-¥1.00');
  });
}
