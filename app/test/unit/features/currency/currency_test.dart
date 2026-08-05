import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/core/constants/constants.dart';
import 'package:bookkeep_app/core/utils/money.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/currency_repository.dart';
import 'package:bookkeep_app/data/repositories/reports_repository.dart';
import 'package:bookkeep_app/data/repositories/transaction_repository.dart';
import 'package:bookkeep_app/domain/services/account_balance_calculator.dart';
import 'package:bookkeep_app/features/currency/exchange_rate_service.dart';

void main() {
  group('Money 定点换算（Spec §4.5）', () {
    test('四舍五入到分：正数 half-up', () {
      // 100.00 USD × 7.1 = 710.00 CNY
      expect(Money.convert(amountMinor: 10000, rateScaled: 7100000), 71000);
      // 0.055 → 0.06（half-up）
      expect(Money.convert(amountMinor: 100, rateScaled: 550000), 55);
      expect(Money.convert(amountMinor: 100, rateScaled: 554999), 55);
      expect(Money.convert(amountMinor: 100, rateScaled: 555000), 56);
    });

    test('负数舍入一致', () {
      expect(Money.convert(amountMinor: -100, rateScaled: 555000), -56);
      expect(Money.convert(amountMinor: -100, rateScaled: 554999), -55);
    });

    test('无浮点参与：整数域运算（10 万次无误差）', () {
      for (var i = 0; i < 100000; i++) {
        final rate = 1000000 + (i % 500000);
        final result = Money.convert(amountMinor: i, rateScaled: rate);
        expect(result, (i * rate + 500000) ~/ 1000000);
      }
    });

    test('快照语义：历史流水不随汇率波动', () {
      // 100 USD 记账时快照 7.1 → 71000 分
      const money = Money(amountMinor: 10000, currency: 'USD', rateSnapshot: 7100000);
      expect(money.toBaseMinor(), 71000);
      // 快照不变，汇率变化不影响历史
      expect(const Money(amountMinor: 10000, currency: 'USD', rateSnapshot: 7100000)
          .toBaseMinor(), 71000);
      expect(const Money(amountMinor: 10000, currency: 'USD', rateSnapshot: 7200000)
          .toBaseMinor(), 72000);
    });
  });

  group('CurrencyRepository（100+ 币种 seed）', () {
    late AppDatabase db;
    late CurrencyRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = CurrencyRepository(db);
    });

    tearDown(() => db.close());

    test('v6 迁移回归：新库 schemaVersion 6 且币种表可写', () async {
      expect(db.schemaVersion, 6);
      await repo.installSeeds();
      expect(await db.select(db.currencies).get(), isNotEmpty);
    });

    test('seed 安装幂等且数量 ≥ 100', () async {
      final first = await repo.installSeeds();
      expect(first, greaterThanOrEqualTo(100));
      final second = await repo.installSeeds();
      expect(second, 0); // 幂等
      final currencies = await repo.listCurrencies();
      expect(currencies.length, greaterThanOrEqualTo(100));
      expect(currencies.map((c) => c.code), containsAll(['CNY', 'USD', 'EUR', 'JPY']));
    });

    test('手动汇率 + 读取', () async {
      await repo.setManualRate('USD', 7.25);
      expect(await repo.rateScaled('USD'), (7.25 * kRateScale).round());
      expect(await repo.rateScaled('CNY'), kRateScale);
    });
  });

  group('ExchangeRateService（24h 缓存 + 降级）', () {
    late AppDatabase db;
    late ExchangeRateService service;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      service = ExchangeRateService(db);
    });

    tearDown(() => db.close());

    test('缓存新鲜期内不刷新（24h TTL）', () async {
      await CurrencyRepository(db).setManualRate('USD', 7.0);
      final now = DateTime(2026, 8, 1, 12);
      // 手动汇率始终直接使用
      expect(await service.rateScaled('USD', now: now), 7000000);
    });

    test('缓存过期 + 获取失败 → 回退缓存（降级非实时）', () async {
      await db.into(db.currencies).insert(CurrenciesCompanion.insert(
            code: 'USD',
            name: '美元',
            symbol: const Value(r'$'),
            rateScaled: 6500000,
            updatedAt: DateTime(2026, 7, 1), // 一个月前 → 过期
          ));
      final now = DateTime(2026, 8, 1);
      // 默认源 fetchRates 返回 null → 回退缓存 6.5
      expect(await service.rateScaled('USD', now: now), 6500000);
    });

    test('缓存过期 + 源返回新汇率 → 刷新并生效', () async {
      await db.into(db.currencies).insert(CurrenciesCompanion.insert(
            code: 'USD',
            name: '美元',
            symbol: const Value(r'$'),
            rateScaled: 6500000,
            updatedAt: DateTime(2026, 7, 1),
          ));
      final service2 = ExchangeRateService(
        db,
        source: _FakeSource({'USD': 7.3}),
      );
      expect(await service2.rateScaled('USD', now: DateTime(2026, 8, 1)), 7300000);
      // 已刷新 → 缓存新鲜
      expect(await service2.rateScaled('USD', now: DateTime(2026, 8, 1)), 7300000);
    });
  });

  group('聚合接入换算（账户净资产 / 报表）', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('净资产：美元账户余额按汇率折算主币种', () async {
      final usdAccountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
            bookId: const Value('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
            accountType: AccountType.cash,
            name: '美元账户',
            currency: 'USD',
            initialBalance: const Value(10000), // 100.00 USD
            createdAt: DateTime.utc(2026, 8, 1),
          ));
      const calc = AccountBalanceCalculator();
      final balances = calc.balancesByAccount(
        accounts: await db.select(db.accounts).get(),
        transactions: const [],
      );
      // 7.1 汇率 → 100 USD = 710 CNY
      final netWorth = calc.netWorth(
        types: {usdAccountId: AccountType.cash},
        balances: balances,
        currencies: {usdAccountId: 'USD'},
        converter: (currency, amount) =>
            Money.convert(amountMinor: amount, rateScaled: 7100000),
      );
      expect(netWorth, 71000);
    });

    test('报表：多币种流水折算后合计（精度到分）', () async {
      final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
            bookId: const Value('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
            accountType: AccountType.cash,
            name: '钱包',
            currency: 'CNY',
            createdAt: DateTime.utc(2026, 8, 1),
          ));
      final repo = TransactionRepository(db, bookId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      await repo.createTransaction(
        accountId: accountId,
        type: TransactionType.expense,
        amountMinor: -1000,
        occurredAt: DateTime.utc(2026, 8, 1, 10),
        currency: 'CNY',
      );
      await repo.createTransaction(
        accountId: accountId,
        type: TransactionType.expense,
        amountMinor: -10000, // 100 USD × 7.1 = 710 CNY
        occurredAt: DateTime.utc(2026, 8, 1, 11),
        currency: 'USD',
        rateSnapshot: 7100000,
      );
      final reports = ReportsRepository(db, bookId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      final totals = await reports.dailyTotals(
        start: DateTime.utc(2026, 8, 1),
        end: DateTime.utc(2026, 8, 2),
        rates: {'USD': 7100000},
      );
      expect(totals.single.expenseMinor, 1000 + 71000); // 精度到分
    });
  });
}

class _FakeSource implements ExchangeRateSource {
  _FakeSource(this.rates);
  final Map<String, double> rates;

  @override
  Future<Map<String, double>?> fetchRates() async => rates;
}
