import 'package:flutter/foundation.dart';

import '../../data/local/database.dart';
import '../../data/local/tables/transactions_table.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/usecases/create_transaction.dart';
import 'amount_parser.dart';

enum QuickEntryError { none, invalidAmount, missingSelection, saveFailed }

/// 编辑目标（账单页「修改」入口）：[tx] 为被编辑行；转账时 [pair] 为对侧行
/// （预填转入账户用）。收支行 pair 为 null。
class EditTarget {
  const EditTarget({required this.tx, this.pair});

  final Transaction tx;
  final Transaction? pair;
}

/// 极速记账控制器（Spec §3.1 / BK-P0-001）：
/// 数字键盘输入状态机 + 乐观保存（本地落库 + sync_ops 入队）
///
/// 传入 [editTarget] 时进入编辑模式：预填既有记账数据，保存走更新路径
/// （updateTransaction / updateTransfer，u op 入队），不覆盖 lastDefaults。
class QuickEntryController extends ChangeNotifier {
  QuickEntryController({
    required this.createTransaction,
    required this.transactionRepository,
    required this.accountRepository,
    this.editTarget,
    DateTime? initialOccurredAt,
  })  : occurredAt =
            initialOccurredAt ?? editTarget?.tx.occurredAt.toLocal() ?? DateTime.now() {
    final tx = editTarget?.tx;
    if (tx != null) {
      type = tx.type;
      input = _minorToInput(tx.amountMinor.abs());
      categoryId = tx.categoryId;
      accountId = tx.accountId;
      toAccountId = editTarget!.pair?.accountId;
      note = tx.note ?? '';
    }
  }

  final CreateTransaction createTransaction;
  final TransactionRepository transactionRepository;
  final AccountRepository accountRepository;
  final EditTarget? editTarget;

  bool get editing => editTarget != null;

  static const _maxInputLength = 15;

  TransactionType type = TransactionType.expense;
  String input = '';
  int? categoryId;
  int? accountId;
  int? toAccountId;
  String note = '';
  QuickEntryError error = QuickEntryError.none;
  bool saving = false;
  DateTime occurredAt;

  /// 编辑转账时锁定交易类型：转账为双边流水，单行改类型会破坏配对结构，
  /// 需删除重记；编辑收支时仍可在支出/收入间切换
  bool get typeLocked => editing && editTarget!.tx.type == TransactionType.transfer;

  /// 编辑模式下转账选项禁用（单行流水不可转为双边转账）
  bool get transferOptionEnabled => !editing;

  void setNote(String value) {
    note = value;
    notifyListeners();
  }

  void setType(TransactionType value) {
    type = value;
    error = QuickEntryError.none;
    notifyListeners();
  }

  void selectCategory(int? id) {
    categoryId = id;
    error = QuickEntryError.none;
    notifyListeners();
  }

  void selectAccount(int? id) {
    accountId = id;
    error = QuickEntryError.none;
    notifyListeners();
  }

  void selectToAccount(int? id) {
    toAccountId = id;
    error = QuickEntryError.none;
    notifyListeners();
  }

  /// 手动选择记账时间（默认当前时刻；时分秒全精度入库）
  void setOccurredAt(DateTime value) {
    occurredAt = value;
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

  /// 保存：解析金额 → 校验 → 本地落库 + op 入队；
  /// 编辑模式走更新路径（u op），不覆盖 lastDefaults
  Future<bool> save() async {
    if (saving) return false;
    final amount = AmountParser.parse(input);
    if (amount == null) {
      error = QuickEntryError.invalidAmount;
      _notify();
      return false;
    }
    final trimmedNote = note.trim();
    if (editing) {
      saving = true;
      _notify();
      try {
        if (type == TransactionType.transfer) {
          if (accountId == null || toAccountId == null) {
            error = QuickEntryError.missingSelection;
            _notify();
            return false;
          }
          await transactionRepository.updateTransfer(
            anySideId: editTarget!.tx.id,
            fromAccountId: accountId!,
            toAccountId: toAccountId!,
            amountMinor: amount,
            occurredAt: occurredAt,
            note: trimmedNote.isEmpty ? null : trimmedNote,
          );
        } else {
          if (accountId == null || categoryId == null) {
            error = QuickEntryError.missingSelection;
            _notify();
            return false;
          }
          await transactionRepository.updateTransaction(
            id: editTarget!.tx.id,
            accountId: accountId!,
            categoryId: categoryId,
            type: type,
            amountMinor: type == TransactionType.expense ? -amount : amount,
            occurredAt: occurredAt,
            note: trimmedNote.isEmpty ? null : trimmedNote,
          );
        }
      } catch (_) {
        error = QuickEntryError.saveFailed;
        return false;
      } finally {
        saving = false;
        _notify();
      }
      return true;
    }
    if (type == TransactionType.transfer) {
      if (accountId == null || toAccountId == null) {
        error = QuickEntryError.missingSelection;
        _notify();
        return false;
      }
      saving = true;
      _notify();
      try {
        await transactionRepository.createTransfer(
          fromAccountId: accountId!,
          toAccountId: toAccountId!,
          amountMinor: amount,
          occurredAt: occurredAt,
        );
      } catch (_) {
        error = QuickEntryError.saveFailed;
        return false;
      } finally {
        saving = false;
        _notify();
      }
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
    try {
      final signed = type == TransactionType.expense ? -amount : amount;
      await createTransaction(
        accountId: accountId!,
        categoryId: categoryId!,
        type: type,
        amountMinor: signed,
        occurredAt: occurredAt,
      );
      await transactionRepository.rememberDefaults(
        type: type,
        categoryId: categoryId,
        accountId: accountId,
      );
    } catch (_) {
      error = QuickEntryError.saveFailed;
      return false;
    } finally {
      saving = false;
      _notify();
    }
    _reset();
    return true;
  }

  void _reset() {
    input = '';
    error = QuickEntryError.none;
    _notify();
  }

  /// 金额（分）→ 键盘输入串：去多余尾零（2550→'25.5'、2500→'25'、2505→'25.05'）
  static String _minorToInput(int absMinor) {
    final yuan = absMinor ~/ 100;
    final cents = (absMinor % 100).toString().padLeft(2, '0');
    final frac = cents.replaceAll(RegExp(r'0+$'), '');
    return frac.isEmpty ? '$yuan' : '$yuan.$frac';
  }

  void _notify() => notifyListeners();
}
