import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/features/auto_capture/sms_parser.dart';
import 'package:bookkeep_app/features/auto_capture/voice_entry_sheet.dart';

void main() {
  group('短信解析（Spec §4.2 金额抽取正则）', () {
    final parser = SmsCaptureParser();

    test('支出短信：金额/商户/方向正确', () {
      final c = parser.parse('【XX银行】您尾号1234的储蓄卡支出¥25.50，商户：星巴克');
      expect(c, isNotNull);
      expect(c!.amountMinor, -2550);
      expect(c.counterparty, '星巴克');
    });

    test('收入短信：到账为正', () {
      final c = parser.parse('【支付宝】转账到账，收款￥1,000.00元，付款方：王小明');
      expect(c, isNotNull);
      expect(c!.amountMinor, 100000);
      expect(c.counterparty, '王小明');
    });

    test('支付类短信用词抽取', () {
      final c = parser.parse('【微信支付】你已向 京东商城 付款 66.60元');
      expect(c, isNotNull);
      expect(c!.amountMinor, -6660);
      expect(c.counterparty, '京东商城');
    });

    test('金额缺失或方向不明时不产生候选', () {
      expect(parser.parse('【XX】您的余额为 100.00 元'), isNull); // 无收支方向
      expect(parser.parse('【XX】支出了一笔消费，请登录查看'), isNull); // 无金额
      expect(parser.parse('普通通知短信'), isNull);
    });

    test('10 个代表样本全部抽取正确', () {
      const samples = [
        '【银行】支出¥12.00 商户：便利店',
        '【银行】消费 45.5元 商户：滴滴出行',
        '【支付】向 美团 支付 30.00元',
        '【银行】转账至 李四 金额￥520.00',
        '【银行】还款 8,800.00元 至 招商银行',
        '【支付宝】到账 200.00元 付款方：张三',
        '【支付】收到转账 66.00元 来自：王五',
        '【银行】收入 1,234.56元 汇款人：公司财务',
        '【银行】支付 ¥3.50 商户：停车费',
        '【支付】收款 99.00元 付款方：赵六',
      ];
      for (final s in samples) {
        final c = parser.parse(s);
        expect(c, isNotNull, reason: '应能解析：$s');
        expect(c!.amountMinor, isNot(0));
        expect(c.counterparty, isNotEmpty);
      }
    });
  });

  group('语音规则引擎（LLM 抽象默认关闭）', () {
    const engine = VoiceRuleEngine();

    test('提取金额/方向/分类提示', () {
      final c = engine.extract('昨天午餐打车花了25元');
      expect(c, isNotNull);
      expect(c!.amountMinor, -2500);
      expect(c.type.name, 'expense');
      expect(c.categoryName, '交通'); // 打车 → 交通
    });

    test('时间锚点：昨天', () {
      final now = DateTime.now();
      final c = engine.extract('昨天吃饭支出50元')!;
      final yesterday = now.subtract(const Duration(days: 1));
      expect(c.occurredAt.year, yesterday.year);
      expect(c.occurredAt.month, yesterday.month);
      expect(c.occurredAt.day, yesterday.day);
    });

    test('时间锚点：HH:mm', () {
      final c = engine.extract('今天 14:30 去超市买东西花了88元')!;
      expect(c.occurredAt.hour, 14);
      expect(c.occurredAt.minute, 30);
    });

    test('方向不明的文本返回 null', () {
      expect(engine.extract('今天天气不错'), isNull);
    });
  });
}
