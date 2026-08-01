import 'package:flutter/foundation.dart';

import '../../data/local/tables/transactions_table.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/usecases/create_transaction.dart';
import 'amount_parser.dart';

enum QuickEntryError { none, invalidAmount, missingSelection }

/// 极速记账控制器（Spec §3.1 / BK-P0-001）：
/// 数字键盘输入状态机 + 乐观保存（本地落库 + sync_ops 入队）
class QuickEntryController extends ChangeNotifier {
  QuickEntryController({
    required this.createTransaction,
    required this.transactionRepository,
    required this.accountRepository,
  });

  final CreateTransaction createTransaction;
  final TransactionRepository transactionRepository;
  final AccountRepository accountRepository;

  static const _maxInputLength = 15;

  TransactionType type = TransactionType.expense;
  String input = '';
  int? categoryId;
  int? accountId;
  int? toAccountId;
  QuickEntryError error = QuickEntryError.none;
  bool saving = false;

  void setType(TransactionType value) {
    type = value;
    error = QuickEntryError.none;
    notifyListeners();
  }

  /// 数字键盘按键（'0'-'9'、'.'、'+'、'-'）
  void pressKey(String key) {
    if (key == '.') return _pressDot();
    if (key == '+' || key == '-') return _pressOperator(key);
    if (key.length != 1 || !RegExp(r'[0-9]').hasMatch(key)) return;

    if (input.length >= _maxInputLength) return;
    if (_currentTermIsZero()) return; // 整数部分 0 开头不追加
    input += key;
    _notify();
  }

  void backspace() {
    if (input.isNotEmpty) input = input.substring(0, input.length - 1);
    error = QuickEntryError.none;
    _notify();
  }

  void clear() {
    input = '';
    error = QuickEntryError.none;
    _notify();
  }

  void _pressDot() {
    final current = _currentTerm();
    if (current == null) {
      input += '0.';
    } else if (!current.contains('.')) {
      input += '.';
    }
    _notify();
  }

  void _pressOperator(String op) {
    // 简易运算限二元（a+b / a-b），已有运算符则忽略后续运算符
    if (input.isNotEmpty &&
        !input.contains(RegExp(r'[+-]')) &&
        (_currentTerm()?.isNotEmpty ?? false)) {
      input += op;
    }
    _notify();
  }

  String? _currentTerm() {
    final parts = input.split(RegExp(r'[+-]'));
    return parts.isEmpty ? null : parts.last;
  }

  bool _currentTermIsZero() {
    final current = _currentTerm();
    return current == '0';
  }

  /// 保存：解析金额 → 校验 → 本地落库 + op 入队 + 记住默认选择
  Future<bool> save() async {
    if (saving) return false;
    final amount = AmountParser.parse(input);
    if (amount == null) {
      error = QuickEntryError.invalidAmount;
      _notify();
      return false;
    }
    if (type == TransactionType.transfer) {
      if (accountId == null || toAccountId == null) {
        error = QuickEntryError.missingSelection;
        _notify();
        return false;
      }
      saving = true;
      _notify();
      await transactionRepository.createTransfer(
        fromAccountId: accountId!,
        toAccountId: toAccountId!,
        amountMinor: amount,
        occurredAt: DateTime.now(),
      );
      saving = false;
      _reset();
      return true;
    }

    if (accountId == null || categoryId == null) {
      error = QuickEntryError.missingSelection;
      _notify();
      return false;
    }
    saving = true;
    _notify();
    final signed = type == TransactionType.expense ? -amount : amount;
    await createTransaction(
      accountId: accountId!,
      categoryId: categoryId!,
      type: type,
      amountMinor: signed,
    );
    await transactionRepository.rememberDefaults(
      type: type,
      categoryId: categoryId,
      accountId: accountId,
    );
    saving = false;
    _reset();
    return true;
  }

  void _reset() {
    input = '';
    error = QuickEntryError.none;
    _notify();
  }

  void _notify() => notifyListeners();
}
