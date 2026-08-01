import 'package:drift/drift.dart';

/// 币种表（Spec §4.5 / BK-T-014）：内置 100+ ISO 4217；rate_scaled 为相对
/// 主币种（CNY）的汇率（kRateScale 刻度，1.0 = 1000000）；手动修改或缓存更新
/// 刷新 updated_at，供 24h TTL 判断。
class Currencies extends Table {
  TextColumn get code => text()(); // ISO 4217 三字母
  TextColumn get name => text()();
  TextColumn get symbol => text().withDefault(const Constant(''))();
  /// 相对主币种汇率（kRateScale 刻度）
  IntColumn get rateScaled => integer().named('rate_scaled')();
  BoolColumn get isManual => boolean().named('is_manual').withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {code};
}
