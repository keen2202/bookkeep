import '../../data/local/database.dart';
import '../../data/local/tables/transactions_table.dart';

/// 单日账单（含当天收支合计；转账两条腿不计入收支）
class BillDay {
  const BillDay({
    required this.day,
    required this.expenseMinor,
    required this.incomeMinor,
    required this.items,
  });

  final DateTime day;
  final int expenseMinor;
  final int incomeMinor;
  final List<Transaction> items;
}

/// 按天分组（本地日历日；天降序，天内保持输入顺序即 occurredAt 倒序）
List<BillDay> groupBillsByDay(List<Transaction> transactions) {
  final byDay = <DateTime, List<Transaction>>{};
  for (final t in transactions) {
    final day = DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
    byDay.putIfAbsent(day, () => []).add(t);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      BillDay(
        day: day,
        expenseMinor: byDay[day]!
            .where((t) => t.type == TransactionType.expense)
            .fold(0, (sum, t) => sum + t.amountMinor.abs()),
        incomeMinor: byDay[day]!
            .where((t) => t.type == TransactionType.income)
            .fold(0, (sum, t) => sum + t.amountMinor.abs()),
        items: byDay[day]!,
      ),
  ];
}
