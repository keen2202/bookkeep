import 'package:drift/drift.dart';

import '../../core/constants/constants.dart';
import '../../data/local/database.dart';
import '../../data/repositories/currency_repository.dart';

/// 汇率源抽象（Spec §4.5 / BK-T-014）：HTTPS 获取并校验结构；失败回退缓存。
/// 本环境默认实现不联网（返回 null → 使用缓存/手动汇率），设备端接入真实源。
abstract class ExchangeRateSource {
  /// 返回 {code: rate}（相对主币种）；失败返回 null（降级）
  Future<Map<String, double>?> fetchRates();
}

class NullExchangeRateSource implements ExchangeRateSource {
  const NullExchangeRateSource();

  @override
  Future<Map<String, double>?> fetchRates() async => null;
}

/// 汇率服务（24h 缓存 + 手动修改 + 失败降级）：
/// - 缓存 TTL：updated_at 距今 < 24h 视为新鲜
/// - 获取失败 → 回退最近缓存并标记「非实时」
class ExchangeRateService {
  ExchangeRateService(this.db, {ExchangeRateSource? source})
      : _source = source ?? const NullExchangeRateSource(),
        _repo = CurrencyRepository(db);

  static const cacheTtl = Duration(hours: 24);

  final AppDatabase db;
  final ExchangeRateSource _source;
  final CurrencyRepository _repo;

  /// 获取币种汇率（kRateScale 刻度）；过期/缺失时尝试刷新，失败回退缓存
  Future<int> rateScaled(String code, {DateTime? now}) async {
    final current = now ?? DateTime.now();
    final row = await (db.select(db.currencies)..where((t) => t.code.equals(code)))
        .getSingleOrNull();
    if (row == null) return kRateScale;
    final fresh = row.updatedAt.isAfter(current.subtract(cacheTtl));
    if (fresh || row.isManual) return row.rateScaled;
    // 缓存过期：尝试刷新（失败静默回退缓存）
    final rates = await _source.fetchRates();
    if (rates != null && rates.containsKey(code)) {
      final scaled = (rates[code]! * kRateScale).round();
      await db.into(db.currencies).insert(
            CurrenciesCompanion.insert(
              code: code,
              name: row.name,
              symbol: Value(row.symbol),
              rateScaled: scaled,
              isManual: const Value(false),
              updatedAt: DateTime.now().toUtc(),
            ),
            onConflict: DoUpdate((_) => CurrenciesCompanion(
                  rateScaled: Value(scaled),
                  updatedAt: Value(DateTime.now().toUtc()),
                )),
          );
      return scaled;
    }
    return row.rateScaled; // 降级：缓存值（非实时）
  }

  Future<void> setManualRate(String code, double rate) => _repo.setManualRate(code, rate);
}
