import 'package:drift/drift.dart';

import '../../core/utils/csv.dart';
import '../../core/utils/money_format.dart';
import '../../data/local/database.dart';
import '../../data/local/tables/transactions_table.dart';

/// CSV 导出（Spec §4.3 / BK-T-012）：区间/账本/类型筛选，中文/逗号/换行转义正确。
class ExportService {
  ExportService(this.db);
  final AppDatabase db;

  Future<String> exportCsv({
    required String bookId,
    DateTime? start,
    DateTime? end,
    TransactionType? type,
  }) async {
    final q = db.select(db.transactions)
      ..where((t) => t.bookId.equals(bookId) & t.deletedAt.isNull());
    if (start != null) q.where((t) => t.occurredAt.isBiggerOrEqualValue(start));
    if (end != null) q.where((t) => t.occurredAt.isSmallerThanValue(end));
    if (type != null) q.where((t) => t.type.equals(type.name));
    q.orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);

    final rows = await q.get();
    final buffer = StringBuffer();
    buffer.writeln(['日期', '类型', '金额', '分类', '账户', '备注']
        .map(escapeCsvField)
        .join(','));

    for (final t in rows) {
      final date = t.occurredAt.toLocal().toIso8601String();
      final kind = switch (t.type) {
        TransactionType.expense => '支出',
        TransactionType.income => '收入',
        TransactionType.transfer => '转账',
      };
      final amount = formatMoney(t.amountMinor);
      buffer.writeln([
        date,
        kind,
        amount,
        t.categoryId?.toString() ?? '',
        t.accountId.toString(),
        t.note ?? '',
      ].map(escapeCsvField).join(','));
    }
    return buffer.toString();
  }
}
