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

  group('compactTickLabel（报表/现金流 y 轴可读刻度）', () {
    test('小额原样（元.分）', () {
      expect(compactTickLabel(12345), '123.45');
      expect(compactTickLabel(0), '0.00');
      expect(compactTickLabel(999999), '9999.99'); // 1 万以下不进「万」档
    });

    test('万档按 1,000,000 分换算（修复 10 倍刻度错位）', () {
      // ¥20,000 = 2,000,000 分 → 2.0万（旧实现错标 20.0万）
      expect(compactTickLabel(2000000), '2.0万');
      expect(compactTickLabel(1234567), '1.2万');
      expect(compactTickLabel(99999999), '100.0万'); // 1 百万以下仍为万档
    });

    test('百万档按 100,000,000 分换算', () {
      expect(compactTickLabel(150000000), '1.5百万');
      expect(compactTickLabel(250000000), '2.5百万');
    });

    test('负值保留单个符号（修复「--」双负号）', () {
      expect(compactTickLabel(-2000000), '-2.0万');
      expect(compactTickLabel(-150000000), '-1.5百万');
      expect(compactTickLabel(-12345), '-123.45');
    });
  });

  group('niceAxisStep（y 轴好看刻度步长）', () {
    test('落在 1/2/5×10^k 档位', () {
      expect(niceAxisStep(300000), 500000); // 3 → 5
      expect(niceAxisStep(25000), 50000); // 2.5 → 5
      expect(niceAxisStep(1800000), 2000000); // 1.8 → 2
      expect(niceAxisStep(1000000), 1000000); // 1 → 1
      expect(niceAxisStep(900000), 1000000); // 0.9 → 1
      expect(niceAxisStep(0.35), 0.5);
    });

    test('非正/异常输入回退 1', () {
      expect(niceAxisStep(0), 1);
      expect(niceAxisStep(-5), 1);
      expect(niceAxisStep(double.nan), 1);
      expect(niceAxisStep(double.infinity), 1);
    });
  });
}
