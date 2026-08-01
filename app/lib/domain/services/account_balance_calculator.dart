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

  /// 净资产 = Σ资产账户余额 − Σ负债账户余额（信用卡/负债账户为负债）。
  /// 多币种：经 [converter] 把各账户余额折算到主币种后求和（Spec §4.5）。
  int netWorth({
    required Map<int, AccountType> types,
    required Map<int, int> balances,
    Map<int, String>? currencies,
    CurrencyConverter? converter,
  }) {
    var worth = 0;
    balances.forEach((id, balance) {
      final type = types[id];
      var amount = balance;
      if (converter != null && currencies != null) {
        amount = converter(currencies[id] ?? 'CNY', balance);
      }
      if (type == AccountType.credit || type == AccountType.liability) {
        worth -= amount;
      } else {
        worth += amount;
      }
    });
    return worth;
  }
}

/// 币种换算器：currency + 原币金额（分）→ 主币种金额（分）（Spec §4.5）
typedef CurrencyConverter = int Function(String currency, int amountMinor);
