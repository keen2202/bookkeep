import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/data/repositories/budget_repository.dart';
import 'package:bookkeep_app/features/budgets/budget_alert_service.dart';

/// 通知端口假实现：记录调用 + 可注入失败
class _FakeNotifier implements BudgetNotifier {
  final List<String> calls = [];
  bool fail = false;

  @override
  Future<void> showBudgetAlert({required String title, required String body}) async {
    if (fail) throw Exception('notification denied');
    calls.add('$title|$body');
  }
}

void main() {
  late AppDatabase db;
  late BudgetRepository repo;
  late _FakeNotifier notifier;
  late BudgetAlertService service;
  const bookId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  Future<int> addBudget({int? categoryId, int amountMinor = 100000, int threshold = 80}) {
    return repo.createBudget(
      categoryId: categoryId,
      period: '2026-08-01',
      amountMinor: amountMinor,
      threshold: threshold,
    );
  }

  Future<void> spend(int minor) async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: bookId,
          remoteId: const Value('22222222-2222-4222-8222-222222222222'),
          accountId: 1,
          type: TransactionType.expense,
          amountMinor: -minor,
          currency: 'CNY',
          occurredAt: DateTime.utc(2026, 8, 15),
          updatedAt: DateTime.utc(2026, 8, 15),
        ));
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: bookId,
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    repo = BudgetRepository(db, bookId: bookId);
    notifier = _FakeNotifier();
    service = BudgetAlertService(repo: repo, notifier: notifier);
  });

  tearDown(() => db.close());

  test('审查 F-5：threshold=50 时花费 50% 触发一次阈值通知', () async {
    await addBudget(threshold: 50);
    await spend(50000); // 50%

    final notified = await service.evaluate(now: DateTime.utc(2026, 8, 15));
    expect(notified, 1);
    expect(notifier.calls.single, contains('50%'));
  });

  test('审查 F-5：未达阈值不通知', () async {
    await addBudget(threshold: 80);
    await spend(50000); // 50% < 80%

    final notified = await service.evaluate(now: DateTime.utc(2026, 8, 15));
    expect(notified, 0);
    expect(notifier.calls, isEmpty);
  });

  test('审查 F-5：超支触发超支通知（exceeded 优先于 threshold）', () async {
    await addBudget(threshold: 50);
    await spend(150000); // 150%

    final notified = await service.evaluate(now: DateTime.utc(2026, 8, 15));
    expect(notified, 1);
    expect(notifier.calls.single, contains('已超支'));
  });

  test('审查 F-5：每周期每预算仅通知一次（重复评估不重复通知）', () async {
    await addBudget(threshold: 50);
    await spend(50000);

    expect(await service.evaluate(now: DateTime.utc(2026, 8, 15)), 1);
    expect(await service.evaluate(now: DateTime.utc(2026, 8, 16)), 0);
    expect(await service.evaluate(now: DateTime.utc(2026, 8, 17)), 0);
    expect(notifier.calls, hasLength(1));
  });

  test('审查 F-5：通知失败优雅降级（不抛错、不阻断，且不标记已通知）', () async {
    await addBudget(threshold: 50);
    await spend(50000);
    notifier.fail = true;

    // 通知失败被吞掉，evaluate 正常返回 0
    final notified = await service.evaluate(now: DateTime.utc(2026, 8, 15));
    expect(notified, 0);
    // 恢复后同一周期可再次尝试通知
    notifier.fail = false;
    expect(await service.evaluate(now: DateTime.utc(2026, 8, 16)), 1);
    expect(notifier.calls, hasLength(1));
  });
}
