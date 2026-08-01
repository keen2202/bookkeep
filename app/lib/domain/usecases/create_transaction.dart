import '../../core/constants/constants.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../data/repositories/transaction_repository.dart';

/// 记账用例（Spec §3.1 / BK-P0-001）：校验 → 乐观本地写 + sync_ops 入队
class CreateTransaction {
  CreateTransaction(this._repo);

  final TransactionRepository _repo;

  Future<int> call({
    required int accountId,
    int? categoryId,
    required TransactionType type,
    required int amountMinor,
    DateTime? occurredAt,
    String? note,
  }) async {
    if (amountMinor == 0 || amountMinor.abs() > kMaxAmountMinor) {
      throw ArgumentError('金额超出允许范围');
    }
    return _repo.createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      type: type,
      amountMinor: amountMinor,
      occurredAt: occurredAt ?? DateTime.now(),
      note: note,
    );
  }
}
