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

// ================= 报表时间范围（纯函数，独立可测） =================

/// 报表时间维度（custom = 自定义起止日期）
enum ReportRange { day, week, month, year, custom }

extension ReportRangeWindow on ReportRange {
  /// 当前周期窗口（开区间 [start, end)）；custom 需经 [customWindow] 显式传参
  ({DateTime start, DateTime end}) window(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      ReportRange.day => (
          start: today,
          end: today.add(const Duration(days: 1)),
        ),
      ReportRange.week => (
          start: today.subtract(Duration(days: today.weekday - 1)),
          end: today.add(Duration(days: 8 - today.weekday)),
        ),
      ReportRange.month => (
          start: DateTime(now.year, now.month),
          end: DateTime(now.year, now.month + 1),
        ),
      ReportRange.year => (
          start: DateTime(now.year),
          end: DateTime(now.year + 1),
        ),
      ReportRange.custom => throw UnsupportedError('custom window must use customWindow()'),
    };
  }
}

/// 自定义范围窗口：起止均含当日，end 为结束日次日零点（开区间）
({DateTime start, DateTime end}) customWindow(
  DateTime startInclusive,
  DateTime endInclusive,
) =>
    (
      start: DateTime(startInclusive.year, startInclusive.month, startInclusive.day),
      end: DateTime(endInclusive.year, endInclusive.month, endInclusive.day)
          .add(const Duration(days: 1)),
    );

/// 周期对比窗口：当前周期 + 前 5 年同期。
/// 「年」= 当年全年 + 前 5 年全年；「月/周/日」= 当期 + 各年前同月/同周/同日。
List<({String label, DateTime start, DateTime end})> comparisonWindows(
  ReportRange range,
  DateTime anchor,
) {
  final y = anchor.year;
  final years = [for (var i = y - 5; i <= y; i++) i];
  return switch (range) {
    ReportRange.day => [
        for (final year in years)
          (
            label: '$year-${_two(anchor.month)}-${_two(anchor.day)}',
            start: DateTime(year, anchor.month, anchor.day),
            end: DateTime(year, anchor.month, anchor.day + 1),
          ),
      ],
    ReportRange.week => _comparisonWeekWindows(years, anchor),
    ReportRange.month => [
        for (final year in years)
          (
            label: '$year-${_two(anchor.month)}',
            start: DateTime(year, anchor.month),
            end: DateTime(year, anchor.month + 1),
          ),
      ],
    ReportRange.year => [
        for (final year in years)
          (label: '$year', start: DateTime(year), end: DateTime(year + 1)),
      ],
    ReportRange.custom => const [],
  };
}

/// ISO 8601 周号（周一为一周首日，第 1 周含当年首个周四）
int isoWeekNumber(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  return thursday.difference(_firstThursday(thursday.year)).inDays ~/ 7 + 1;
}

/// (year, week) 对应的周一；该年不存在该 ISO 周（52/53 边界）返回 null
DateTime? mondayOfIsoWeek(int year, int week) {
  final monday = _firstThursday(year).add(Duration(days: (week - 1) * 7 - 3));
  if (isoWeekNumber(monday) != week) return null;
  return monday;
}

List<({String label, DateTime start, DateTime end})> _comparisonWeekWindows(
  List<int> years,
  DateTime anchor,
) {
  final week = isoWeekNumber(anchor);
  final result = <({String label, DateTime start, DateTime end})>[];
  for (final year in years) {
    final monday = mondayOfIsoWeek(year, week);
    if (monday == null) continue; // 该年无此 ISO 周（如 53 周）
    result.add((
      label: '$year-W${_two(week)}',
      start: monday,
      end: monday.add(const Duration(days: 7)),
    ));
  }
  return result;
}

DateTime _firstThursday(int year) {
  final jan1 = DateTime(year, 1, 1);
  return jan1.add(Duration(days: (4 - jan1.weekday + 7) % 7));
}

String _two(int v) => v.toString().padLeft(2, '0');

String _localDayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

// ================= 查询层 =================

/// 报表只读查询层（Spec §3.5 / BK-P0-005）：单条 GROUP BY SQL，避免 N+1；
/// 强制按账本过滤（Spec §4.1 / BK-T-010）
class ReportsRepository {
  ReportsRepository(this.db, {required this.bookId});
  final AppDatabase db;
  final String bookId;

  /// 按日聚合：支出/收入（不含已删除与转账）。
  /// 时区修正：`date(..., 'localtime')` 按设备本地日历日分组，
  /// 与窗口边界（本地 DateTime）同口径——此前按 UTC 日分组，
  /// 东八区 00:00-08:00 的流水会被错记到前一天。
  /// 多币种：按 (币种, 记账时汇率快照) 分组，以快照折算主币种（审查 F-8）。
  Future<List<DailyTotal>> dailyTotals({
    required DateTime start,
    required DateTime end,
    Map<String, int> rates = const {},
  }) async {
    final currentBookId = bookId;
    final rows = await db.customSelect(
      "SELECT date(occurred_at, 'unixepoch', 'localtime') AS day, currency, rate_snapshot, "
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

  /// 单窗口周期分桶（自定义时间范围用）：周/月粒度。
  /// 周桶按 ISO 周（%G-W%V，与 [mondayOfIsoWeek] 同源，修复跨年周归属错位）；
  /// 本地时区口径与 [dailyTotals] 一致。
  Future<List<PeriodBucket>> periodBuckets({
    required DateTime start,
    required DateTime end,
    required BucketGranularity granularity,
    Map<String, int> rates = const {},
  }) async {
    final currentBookId = bookId;
    final format = granularity == BucketGranularity.week
        ? "%G-W%V" // ISO 周：%V 须与 %G（ISO 年）配套，%Y/%W 会错标跨年周
        : '%Y-%m';
    final rows = await db.customSelect(
      "SELECT strftime(?, occurred_at, 'unixepoch', 'localtime') AS bucket, "
      'currency, rate_snapshot, '
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
        final monday = mondayOfIsoWeek(year, week);
        results.add(PeriodBucket(
          label: monday == null
              ? bucket
              : '${_two(monday.month)}-${_two(monday.day)} 周',
          amountMinor: amount,
        ));
      } else {
        results.add(PeriodBucket(label: bucket, amountMinor: amount));
      }
    }
    return results;
  }

  /// 周期对比跨年聚合：给定带标签窗口（见 [comparisonWindows]），
  /// 全跨度一次按日查询（避免 N+1），Dart 侧按窗口切片。
  Future<List<PeriodBucket>> comparisonBuckets({
    required List<({String label, DateTime start, DateTime end})> windows,
    Map<String, int> rates = const {},
  }) async {
    if (windows.isEmpty) return const [];
    final currentBookId = bookId;
    final rows = await db.customSelect(
      "SELECT date(occurred_at, 'unixepoch', 'localtime') AS day, currency, rate_snapshot, "
      'COALESCE(SUM(-amount_minor), 0) AS amount '
      'FROM transactions '
      'WHERE type = ? AND deleted_at IS NULL AND book_id = ? '
      'AND occurred_at >= ? AND occurred_at < ? '
      'GROUP BY day, currency, rate_snapshot',
      variables: [
        Variable.withString('expense'),
        Variable.withString(currentBookId),
        Variable.withDateTime(windows.first.start),
        Variable.withDateTime(windows.last.end),
      ],
    ).get();
    final byDay = <String, int>{};
    for (final row in rows) {
      final day = row.read<String>('day');
      final currency = row.read<String>('currency');
      final snapshot = row.read<int?>('rate_snapshot');
      final amount = _convertWith(row.read<int>('amount'), currency, snapshot, rates);
      byDay.update(day, (v) => v + amount, ifAbsent: () => amount);
    }
    return [
      for (final w in windows)
        PeriodBucket(label: w.label, amountMinor: _sumDays(byDay, w.start, w.end)),
    ];
  }

  int _sumDays(Map<String, int> byDay, DateTime start, DateTime end) {
    final startKey = _localDayKey(start);
    final endKey = _localDayKey(end);
    var total = 0;
    for (final entry in byDay.entries) {
      if (entry.key.compareTo(startKey) >= 0 && entry.key.compareTo(endKey) < 0) {
        total += entry.value;
      }
    }
    return total;
  }

  /// 按记账时汇率快照折算主币种（审查 F-8）：快照优先；
  /// 无快照的旧行回退 [rates]（缺失按 1:1）
  int _convertWith(int amountMinor, String currency, int? snapshot, Map<String, int> rates) {
    if (amountMinor == 0 || currency == 'CNY') return amountMinor;
    final rate = (snapshot ?? 0) > 0 ? snapshot! : (rates[currency] ?? kRateScale);
    return Money.convert(amountMinor: amountMinor, rateScaled: rate);
  }
}
