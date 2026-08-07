import 'package:drift/drift.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/money.dart';
import '../local/database.dart';

class DailyTotal {
  const DailyTotal({
    required this.date,
    required this.expenseMinor,
    required this.incomeMinor,
  });
  final String date;
  final int expenseMinor;
  final int incomeMinor;
}

class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.categoryName,
    required this.amountMinor,
  });
  final int categoryId;
  final String categoryName;
  final int amountMinor;
}

enum BucketGranularity { week, month }

class PeriodBucket {
  const PeriodBucket({required this.label, required this.amountMinor});
  final String label;
  final int amountMinor;
}

/// 报表只读查询层（Spec §3.5 / BK-P0-005）：单条 GROUP BY SQL，避免 N+1；
/// 强制按账本过滤（Spec §4.1 / BK-T-010）
class ReportsRepository {
  ReportsRepository(this.db, {required this.bookId});
  final AppDatabase db;
  final String bookId;

  /// 按日聚合：支出/收入（不含已删除与转账）。
  /// 多币种：按 (币种, 记账时汇率快照) 分组，以快照折算主币种（审查 F-8：
  /// 历史报表不随当前汇率波动）；无快照的旧行回退 [rates]。
  Future<List<DailyTotal>> dailyTotals({
    required DateTime start,
    required DateTime end,
    Map<String, int> rates = const {},
  }) async {
    final currentBookId = bookId;
    final rows = await db.customSelect(
      "SELECT date(occurred_at, 'unixepoch') AS day, currency, rate_snapshot, "
      'COALESCE(SUM(CASE WHEN type = ? THEN -amount_minor END), 0) AS expense, '
      'COALESCE(SUM(CASE WHEN type = ? THEN amount_minor END), 0) AS income '
      'FROM transactions '
      'WHERE deleted_at IS NULL AND type IN (?, ?) AND book_id = ? '
      'AND occurred_at >= ? AND occurred_at < ? '
      'GROUP BY day, currency, rate_snapshot ORDER BY day',
      variables: [
        Variable.withString('expense'),
        Variable.withString('income'),
        Variable.withString('expense'),
        Variable.withString('income'),
        Variable.withString(currentBookId),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();
    final byDay = <String, DailyTotal>{};
    for (final row in rows) {
      final day = row.read<String>('day');
      final currency = row.read<String>('currency');
      final snapshot = row.read<int?>('rate_snapshot');
      final expense = _convertWith(row.read<int>('expense'), currency, snapshot, rates);
      final income = _convertWith(row.read<int>('income'), currency, snapshot, rates);
      byDay.update(
        day,
        (t) => DailyTotal(
          date: day,
          expenseMinor: t.expenseMinor + expense,
          incomeMinor: t.incomeMinor + income,
        ),
        ifAbsent: () => DailyTotal(date: day, expenseMinor: expense, incomeMinor: income),
      );
    }
    final days = byDay.keys.toList()..sort();
    return [for (final d in days) byDay[d]!];
  }

  /// 分类占比（单条分组 SQL；按 (币种, 汇率快照) 折算主币种，审查 F-8）
  Future<List<CategorySlice>> categoryBreakdown({
    required DateTime start,
    required DateTime end,
    Map<String, int> rates = const {},
  }) async {
    final currentBookId = bookId;
    final rows = await db.customSelect(
      'SELECT t.category_id, c.name AS category_name, t.currency, t.rate_snapshot, '
      'COALESCE(SUM(-t.amount_minor), 0) AS amount '
      'FROM transactions t LEFT JOIN categories c ON c.id = t.category_id '
      'WHERE t.type = ? AND t.deleted_at IS NULL AND t.book_id = ? '
      'AND t.occurred_at >= ? AND t.occurred_at < ? '
      'GROUP BY t.category_id, t.currency, t.rate_snapshot',
      variables: [
        Variable.withString('expense'),
        Variable.withString(currentBookId),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();
    final byCategory = <int, CategorySlice>{};
    for (final row in rows) {
      final id = row.read<int?>('category_id') ?? 0;
      final name = row.read<String?>('category_name') ?? '未分类';
      final currency = row.read<String>('currency');
      final snapshot = row.read<int?>('rate_snapshot');
      final amount = _convertWith(row.read<int>('amount'), currency, snapshot, rates);
      byCategory.update(
        id,
        (s) => CategorySlice(
          categoryId: id,
          categoryName: name,
          amountMinor: s.amountMinor + amount,
        ),
        ifAbsent: () =>
            CategorySlice(categoryId: id, categoryName: name, amountMinor: amount),
      );
    }
    final slices = byCategory.values.toList()
      ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return slices;
  }

  /// 周期分桶（周/月）对比
  Future<List<PeriodBucket>> periodBuckets({
    required DateTime start,
    required DateTime end,
    required BucketGranularity granularity,
    Map<String, int> rates = const {},
  }) async {
    final currentBookId = bookId;
    final format = granularity == BucketGranularity.week
        ? "%Y-W%W" // 周
        : '%Y-%m'; // 月
    final rows = await db.customSelect(
      "SELECT strftime(?, occurred_at, 'unixepoch') AS bucket, currency, rate_snapshot, "
      'COALESCE(SUM(-amount_minor), 0) AS amount '
      'FROM transactions '
      'WHERE type = ? AND deleted_at IS NULL AND book_id = ? '
      'AND occurred_at >= ? AND occurred_at < ? '
      'GROUP BY bucket, currency, rate_snapshot',
      variables: [
        Variable.withString(format),
        Variable.withString('expense'),
        Variable.withString(currentBookId),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();
    final byBucket = <String, int>{};
    for (final row in rows) {
      final bucket = row.read<String>('bucket');
      final currency = row.read<String>('currency');
      final snapshot = row.read<int?>('rate_snapshot');
      final amount = _convertWith(row.read<int>('amount'), currency, snapshot, rates);
      byBucket.update(bucket, (v) => v + amount, ifAbsent: () => amount);
    }
    final buckets = byBucket.keys.toList()..sort();
    final results = <PeriodBucket>[];
    for (final bucket in buckets) {
      final amount = byBucket[bucket]!;
      if (granularity == BucketGranularity.week) {
        final parts = bucket.split('-W');
        final year = int.parse(parts[0]);
        final week = int.parse(parts[1]);
        final monday = _mondayOfWeek(year, week);
        results.add(PeriodBucket(
          label: '${_two(monday.month)}-${_two(monday.day)} 周',
          amountMinor: amount,
        ));
      } else {
        results.add(PeriodBucket(label: bucket, amountMinor: amount));
      }
    }
    return results;
  }

  /// 按记账时汇率快照折算主币种（审查 F-8）：快照优先；
  /// 无快照的旧行回退 [rates]（缺失按 1:1）
  int _convertWith(int amountMinor, String currency, int? snapshot, Map<String, int> rates) {
    if (amountMinor == 0 || currency == 'CNY') return amountMinor;
    final rate = (snapshot ?? 0) > 0 ? snapshot! : (rates[currency] ?? kRateScale);
    return Money.convert(amountMinor: amountMinor, rateScaled: rate);
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  DateTime _mondayOfWeek(int year, int week) {
    // ISO 8601：周一的日期（year 为 strftime %Y 的年份）
    final jan1 = DateTime.utc(year, 1, 1);
    final firstMonday = jan1.add(Duration(days: (8 - jan1.weekday) % 7));
    return firstMonday.add(Duration(days: (week - 1) * 7));
  }
}
