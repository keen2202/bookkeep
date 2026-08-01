import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/features/quick_entry/amount_parser.dart';

void main() {
  group('AmountParser.parse（元 → 分）', () {
    test('parses plain yuan amounts', () {
      expect(AmountParser.parse('12'), 1200);
      expect(AmountParser.parse('10000'), 1000000);
    });

    test('parses decimals with up to two fractional digits', () {
      expect(AmountParser.parse('12.34'), 1234);
      expect(AmountParser.parse('12.3'), 1230);
      expect(AmountParser.parse('.5'), 50);
      expect(AmountParser.parse('0.01'), 1);
    });

    test('supports simple addition and subtraction expressions', () {
      expect(AmountParser.parse('12+3.5'), 1550);
      expect(AmountParser.parse('100-30.25'), 6975);
      expect(AmountParser.parse('1+2+3'), 600);
    });

    test('rejects malformed input', () {
      expect(AmountParser.parse(''), isNull);
      expect(AmountParser.parse('abc'), isNull);
      expect(AmountParser.parse('12.345'), isNull);
      expect(AmountParser.parse('1.2.3'), isNull);
      expect(AmountParser.parse('+12'), isNull);
      expect(AmountParser.parse('12*3'), isNull);
      expect(AmountParser.parse('12-'), isNull);
      expect(AmountParser.parse('-5'), isNull);
    });

    test('rejects zero and amounts beyond the upper bound', () {
      expect(AmountParser.parse('0'), isNull);
      expect(AmountParser.parse('0.00'), isNull);
      expect(AmountParser.parse('100000000001'), isNull); // > 10^13 分
    });

    test('accepts the upper bound exactly', () {
      expect(AmountParser.parse('100000000000'), 10000000000000);
    });

    test('rejects negative expression results', () {
      expect(AmountParser.parse('5-10'), isNull);
    });
  });
}
