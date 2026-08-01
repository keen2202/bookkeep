import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/core/utils/csv.dart';
import 'package:bookkeep_app/features/auto_capture/csv_import/csv_parsers.dart';

/// 支付宝账单样本生成器：交易时间,交易分类,交易对方,商品说明,收/支,金额,支付方式,交易状态
String alipayRow({
  required String time,
  required String category,
  required String counterparty,
  required String direction,
  required String amount,
  String status = '交易成功',
}) {
  return '$time,$category,$counterparty,商品,$direction,$amount,余额宝,$status';
}

/// 微信账单样本生成器：交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态
String wechatRow({
  required String time,
  required String type,
  required String counterparty,
  required String direction,
  required String amount,
  String status = '支付成功',
}) {
  return '$time,$type,$counterparty,商品,$direction,$amount,零钱,$status';
}

void main() {
  group('支付宝解析（30+ 样本，Spec §4.2 映射准确）', () {
    final parser = AlipayCsvParser();

    test('解析 32 条混合收支样本', () {
      final rows = <String>['交易时间,交易分类,交易对方,商品说明,收/支,金额,支付方式,交易状态'];
      for (var i = 1; i <= 20; i++) {
        rows.add(alipayRow(
          time: '2026-07-${(i % 28 + 1).toString().padLeft(2, '0')} '
              '${(11 + i % 12).toString().padLeft(2, '0')}:${i.toString().padLeft(2, '0')}:00',
          category: i.isEven ? '餐饮' : '交通',
          counterparty: '商户$i',
          direction: '支出',
          amount: (i * 3.5).toStringAsFixed(2),
        ));
      }
      for (var i = 1; i <= 12; i++) {
        rows.add(alipayRow(
          time: '2026-07-${(i % 28 + 1).toString().padLeft(2, '0')} '
              '09:${(i + 10).toString()}:00',
          category: '工资',
          counterparty: '公司$i',
          direction: '收入',
          amount: (i * 100).toStringAsFixed(2),
        ));
      }
      final candidates = parser.parse(rows.join('\n'));
      expect(candidates, hasLength(32));
      expect(candidates.every((c) => c.type.name == 'expense' || c.type.name == 'income'), isTrue);
      expect(candidates[0].amountMinor, lessThan(0));
      expect(candidates[20].amountMinor, greaterThan(0));
    });

    test('失败状态与异常行被跳过（映射准确 ≥ 90%）', () {
      final csv = [
        '交易时间,交易分类,交易对方,商品说明,收/支,金额,支付方式,交易状态',
        alipayRow(time: '2026-07-01 10:00:00', category: '餐饮', counterparty: 'A', direction: '支出', amount: '10.00', status: '交易关闭'),
        alipayRow(time: '2026-07-01 11:00:00', category: '餐饮', counterparty: 'B', direction: '支出', amount: '12.50'),
        '2026-07-01 12:00:00,餐饮,"含,逗号""引号""",商品,支出,25.00,余额宝,交易成功',
        'malformed row without enough fields',
        alipayRow(time: 'bad-time', category: '餐饮', counterparty: 'C', direction: '支出', amount: '5.00'),
        alipayRow(time: '2026-07-01 13:00:00', category: '未知', counterparty: 'D', direction: '其他', amount: '5.00'),
      ].join('\n');
      final candidates = parser.parse(csv);
      // 12.50 支出 + 25.00（含逗号引号字段）→ 2 条；其余 4 条异常/失败被跳过
      expect(candidates, hasLength(2));
      expect(candidates[1].counterparty, '含,逗号"引号"');
      expect(candidates[1].amountMinor, -2500);
    });

    test('金额精度：小数转分正确', () {
      final csv = [
        '交易时间,交易分类,交易对方,商品说明,收/支,金额,支付方式,交易状态',
        alipayRow(time: '2026-07-01 10:00:00', category: '餐饮', counterparty: 'A', direction: '支出', amount: '0.10'),
        alipayRow(time: '2026-07-01 11:00:00', category: '餐饮', counterparty: 'B', direction: '支出', amount: '1234.56'),
        alipayRow(time: '2026-07-01 12:00:00', category: '收入', counterparty: 'C', direction: '收入', amount: '9999.99'),
      ].join('\n');
      final candidates = parser.parse(csv);
      expect(candidates[0].amountMinor, -10);
      expect(candidates[1].amountMinor, -123456);
      expect(candidates[2].amountMinor, 999999);
    });

    test('去重键：金额+时间+对方', () {
      final candidates = parser.parse([
        '交易时间,交易分类,交易对方,商品说明,收/支,金额,支付方式,交易状态',
        alipayRow(time: '2026-07-01 10:00:00', category: '餐饮', counterparty: 'A', direction: '支出', amount: '10.00'),
        alipayRow(time: '2026-07-01 10:00:00', category: '餐饮', counterparty: 'A', direction: '支出', amount: '10.00'),
        alipayRow(time: '2026-07-01 10:00:00', category: '餐饮', counterparty: 'A', direction: '支出', amount: '20.00'),
      ].join('\n'));
      expect(candidates, hasLength(3));
      expect(candidates[0].dedupKey(), candidates[1].dedupKey());
      expect(candidates[0].dedupKey(), isNot(candidates[2].dedupKey()));
    });
  });

  group('微信解析（30+ 样本）', () {
    final parser = WechatCsvParser();

    test('解析 30 条混合样本（含零钱/银行卡/退款跳过）', () {
      final rows = <String>['交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态'];
      for (var i = 1; i <= 30; i++) {
        rows.add(wechatRow(
          time: '2026-07-${(i % 28 + 1).toString().padLeft(2, '0')} 08:${(i % 60).toString().padLeft(2, '0')}:00',
          type: '商户消费',
          counterparty: '微信商户$i',
          direction: i.isEven ? '支出' : '收入',
          amount: (i * 2.25).toStringAsFixed(2),
        ));
      }
      for (var i = 1; i <= 5; i++) {
        rows.add(wechatRow(
          time: '2026-07-${(i % 28 + 1).toString().padLeft(2, '0')} 08:00:00',
          type: '商户消费',
          counterparty: '退款商户$i',
          direction: '支出',
          amount: (i * 3).toStringAsFixed(2),
          status: '已全额退款',
        ));
      }
      final candidates = parser.parse(rows.join('\n'));
      expect(candidates, hasLength(30)); // 退款 5 条跳过
      expect(candidates.every((c) => c.source == 'wechat'), isTrue);
    });

    test('收款/转账方向正确', () {
      final csv = [
        '交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态',
        wechatRow(time: '2026-07-01 09:00:00', type: '二维码收款', counterparty: '朋友A', direction: '收入', amount: '88.00', status: '已收款'),
        wechatRow(time: '2026-07-01 09:30:00', type: '转账', counterparty: '朋友B', direction: '支出', amount: '66.00'),
      ].join('\n');
      final candidates = parser.parse(csv);
      expect(candidates[0].amountMinor, 8800);
      expect(candidates[1].amountMinor, -6600);
      expect(candidates[0].counterparty, '朋友A');
    });
  });

  test('内置 CSV 解析器：引号/逗号/换行转义', () {
    const csv = 'a,"b,c","d""e",f\n"多行\n字段",g,h';
    final rows = parseCsv(csv);
    expect(rows, hasLength(2));
    expect(rows[0], ['a', 'b,c', 'd"e', 'f']);
    expect(rows[1], ['多行\n字段', 'g', 'h']);
  });
}
