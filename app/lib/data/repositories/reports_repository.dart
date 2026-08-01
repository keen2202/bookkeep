import 'package:drift/drift.dart';

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

/// 报表只读查询层（Spec §3.5 / BK-P0-005）：单条 GROUP BY SQL，避免 N+1
class ReportsRepository {
  ReportsRepository(this.db);
  final AppDatabase db;

  /// 按日聚合：支出/收入（不含已删除与转账）
  Future<List<DailyTotal>> dailyTotals({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await db.customSelect(
      "SELECT date(occurred_at, 'unixepoch') AS day, "
      'COALESCE(SUM(CASE WHEN type = ? THEN -amount_minor END), 0) AS expense, '
      'COALESCE(SUM(CASE WHEN type = ? THEN amount_minor END), 0) AS income '
      'FROM transactions '
      'WHERE deleted_at IS NULL AND type IN (?, ?) '
      'AND occurred_at >= ? AND occurred_at < ? '
      'GROUP BY day ORDER BY day',
      variables: [
        Variable.withString('expense'),
        Variable.withString('income'),
        Variable.withString('expense'),
        Variable.withString('income'),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();
    return [
      for (final row in rows)
        DailyTotal(
          date: row.read<String>('day'),
          expenseMinor: row.read<int>('expense'),
          incomeMinor: row.read<int>('income'),
        ),
    ];
  }

  /// 分类占比（单条分组 SQL）
  Future<List<CategorySlice>> categoryBreakdown({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await db.customSelect(
      'SELECT t.category_id, c.name AS category_name, '
      'COALESCE(SUM(-t.amount_minor), 0) AS amount '
      'FROM transactions t LEFT JOIN categories c ON c.id = t.category_id '
      'WHERE t.type = ? AND t.deleted_at IS NULL '
      'AND t.occurred_at >= ? AND t.occurred_at < ? '
      'GROUP BY t.category_id ORDER BY amount DESC',
      variables: [
        Variable.withString('expense'),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();
    return [
      for (final row in rows)
        CategorySlice(
          categoryId: row.read<int?>('category_id') ?? 0,
          categoryName: row.read<String?>('category_name') ?? '未分类',
          amountMinor: row.read<int>('amount'),
        ),
    ];
  }

  /// 周期分桶（周/月）对比
  Future<List<PeriodBucket>> periodBuckets({
    required DateTime start,
    required DateTime end,
    required BucketGranularity granularity,
  }) async {
    final format = granularity == BucketGranularity.week
        ? "%Y-W%W" // 周
        : '%Y-%m'; // 月
    final rows = await db.customSelect(
      "SELECT strftime(?, occurred_at, 'unixepoch') AS bucket, "
      'COALESCE(SUM(-amount_minor), 0) AS amount '
      'FROM transactions '
      'WHERE type = ? AND deleted_at IS NULL '
      'AND occurred_at >= ? AND occurred_at < ? '
      'GROUP BY bucket ORDER BY bucket',
      variables: [
        Variable.withString(format),
        Variable.withString('expense'),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
    ).get();
    final results = <PeriodBucket>[];
    for (final row in rows) {
      final bucket = row.read<String>('bucket');
      final amount = row.read<int>('amount');
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

  String _two(int v) => v.toString().padLeft(2, '0');

  DateTime _mondayOfWeek(int year, int week) {
    // ISO 8601：周一的日期（year 为 strftime %Y 的年份）
    final jan1 = DateTime.utc(year, 1, 1);
    final firstMonday = jan1.add(Duration(days: (8 - jan1.weekday) % 7));
    return firstMonday.add(Duration(days: (week - 1) * 7));
  }
}
