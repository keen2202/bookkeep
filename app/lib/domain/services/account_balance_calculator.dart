import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';

/// 余额聚合领域服务（Spec §3.2 / BK-P0-002）：
/// 余额 = initial_balance + Σ流水（不含已删除），转账双流水自然一正一负抵消。
/// 纯函数，无 I/O，便于单元测试。
class AccountBalanceCalculator {
  const AccountBalanceCalculator();

  Map<int, int> balancesByAccount({
    required Iterable<Account> accounts,
    required Iterable<Transaction> transactions,
  }) {
    final balances = {
      for (final a in accounts) a.id: a.initialBalance,
    };
    for (final t in transactions) {
      if (t.deletedAt != null) continue;
      balances.update(t.accountId, (v) => v + t.amountMinor);
    }
    return balances;
  }

  /// 净资产 = Σ资产账户余额 − Σ负债账户余额（信用卡/负债账户为负债）
  int netWorth({
    required Map<int, AccountType> types,
    required Map<int, int> balances,
  }) {
    var worth = 0;
    balances.forEach((id, balance) {
      final type = types[id];
      if (type == AccountType.credit || type == AccountType.liability) {
        worth -= balance;
      } else {
        worth += balance;
      }
    });
    return worth;
  }
}
