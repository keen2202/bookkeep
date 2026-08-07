import 'package:drift/drift.dart';

import '../../../core/constants/constants.dart';

/// 周期记账规则（Spec §4.4 / BK-T-013）：
/// frequency + interval + anchor_type + anchor_day + time_of_day 持久化，
/// 由 AnchorResolver 统一解析为具体日期（锚点语义集中）。
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text().named('book_id').withDefault(const Constant(kDefaultBookId))();
  TextColumn get frequency => text()(); // day/week/month/quarter/year
  IntColumn get interval => integer().withDefault(const Constant(1))();
  TextColumn get anchorType => text().named('anchor_type')(); // start/middle/end/custom
  IntColumn get anchorDay => integer().named('anchor_day').withDefault(const Constant(1))();
  /// 入账时刻：自 0 点起的分钟数（默认 09:00）
  IntColumn get timeOfDay => integer().named('time_of_day').withDefault(const Constant(9 * 60))();
  IntColumn get amountMinor => integer().named('amount_minor')();
  /// 收支类型：expense / income（审查 F-7：周期收入可建模）
  TextColumn get type => text().withDefault(const Constant('expense'))();
  IntColumn get accountId => integer().named('account_id')();
  IntColumn get categoryId => integer().named('category_id').nullable()();
  /// 下次待生成日期（补跑游标；幂等：生成后前移）
  DateTimeColumn get nextDue => dateTime().named('next_due')();
  DateTimeColumn get startDate => dateTime().named('start_date')();
  DateTimeColumn get endDate => dateTime().named('end_date').nullable()();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
}

/// 分期计划（Spec §4.4）：等额，末笔补差；关联信用卡账户
class InstallmentPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text().named('book_id').withDefault(const Constant(kDefaultBookId))();
  TextColumn get name => text()();
  IntColumn get totalMinor => integer().named('total_minor')();
  IntColumn get periods => integer()();
  DateTimeColumn get startDate => dateTime().named('start_date')();
  /// 关联账户（信用卡）；每期自动生成支出流水
  IntColumn get linkedAccountId => integer().named('linked_account_id')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
}

class InstallmentSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().named('plan_id')();
  DateTimeColumn get dueDate => dateTime().named('due_date')();
  IntColumn get amountMinor => integer().named('amount_minor')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {planId, dueDate},
      ];
}
