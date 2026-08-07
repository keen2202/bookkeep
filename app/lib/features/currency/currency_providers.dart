import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger_version.dart';
import '../../data/local/database.dart';
import '../../data/local/database_provider.dart';
import '../../data/repositories/currency_repository.dart';
import 'exchange_rate_service.dart';

/// 币种仓库（审查 F-8：账户币种下拉 / 汇率管理页共用）
final currencyRepositoryProvider = Provider<CurrencyRepository>(
  (ref) => CurrencyRepository(ref.watch(databaseProvider)),
);

/// 汇率服务（24h 缓存 + 手动汇率）
final exchangeRateServiceProvider = Provider<ExchangeRateService>(
  (ref) => ExchangeRateService(ref.watch(databaseProvider)),
);

/// 币种列表（汇率管理页；CNY 恒在首位）
final currenciesViewModelProvider = FutureProvider<List<Currency>>((ref) async {
  ref.watch(ledgerVersionProvider);
  return ref.watch(currencyRepositoryProvider).listCurrencies();
});
