import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/core/security/backup_cipher.dart';
import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/sync_ops_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/features/backup/backup_service.dart';

void main() {
  Future<AppDatabase> seedDb() async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.books).insert(BooksCompanion.insert(
          id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          name: '家庭账本',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          remoteId: const Value('11111111-1111-4111-8111-111111111111'),
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          initialBalance: const Value(1000),
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          bookId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          remoteId: const Value('22222222-2222-4222-8222-222222222222'),
          accountId: accountId,
          type: TransactionType.expense,
          amountMinor: -2550,
          currency: 'CNY',
          note: const Value('午餐'),
          occurredAt: DateTime.utc(2026, 8, 1, 12),
          updatedAt: DateTime.utc(2026, 8, 1, 12),
        ));
    await db.into(db.syncOps).insert(SyncOpsCompanion.insert(
          bookId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          entity: 'transaction',
          entityId: 1,
          remoteId: const Value('22222222-2222-4222-8222-222222222222'),
          op: SyncOpCode.c,
          payload: '{}',
          lamport: 1,
          clientId: 'client-A',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    // 审查 F-4：补录 4 张表的往返覆盖（币种/周期规则/分期计划/分期排期）
    await db.into(db.currencies).insert(CurrenciesCompanion.insert(
          code: 'USD',
          name: '美元',
          rateScaled: 7200000,
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
    final ruleId = await db.into(db.recurringRules).insert(RecurringRulesCompanion.insert(
          bookId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          frequency: 'month',
          anchorType: 'start',
          amountMinor: -1000,
          type: const Value('expense'),
          accountId: accountId,
          nextDue: DateTime.utc(2026, 9, 1),
          startDate: DateTime.utc(2026, 8, 1),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));
    final planId = await db.into(db.installmentPlans).insert(InstallmentPlansCompanion.insert(
          bookId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          name: '手机分期',
          totalMinor: 12000,
          periods: 3,
          startDate: DateTime.utc(2026, 8, 1),
          linkedAccountId: accountId,
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    await db.into(db.installmentSchedules).insert(InstallmentSchedulesCompanion.insert(
          planId: planId,
          dueDate: DateTime.utc(2026, 8, 1),
          amountMinor: 4000,
        ));
    expect(ruleId, greaterThan(0));
    expect(planId, greaterThan(0));
    return db;
  }

  test('备份→清空→恢复全链路：数据完整一致（Spec §4.3 异机恢复语义）', () async {
    final db = await seedDb();
    final service = BackupService(db);

    final backup = await service.createBackup('备份口令123');
    expect(backup, isNotEmpty);

    // 清空数据库（子表先删；含审查 F-4 补录表）
    await db.transaction(() async {
      for (final table in [
        'installment_schedules', 'installment_plans', 'recurring_rules', 'currencies',
        'sync_ops', 'transactions', 'budgets', 'account_snapshots', 'categories', 'accounts', 'app_meta', 'books',
      ]) {
        await db.customStatement('DELETE FROM $table');
      }
    });
    expect(await db.select(db.accounts).get(), isEmpty);

    final restored = await service.restore(backup, '备份口令123');
    expect(restored, greaterThan(0));

    final accounts = await db.select(db.accounts).get();
    expect(accounts.single.name, '钱包');
    expect(accounts.single.initialBalance, 1000);
    final txs = await db.select(db.transactions).get();
    expect(txs.single.amountMinor, -2550);
    expect(txs.single.note, '午餐');
    final ops = await db.select(db.syncOps).get();
    expect(ops.single.clientId, 'client-A');
    // 审查 F-4：补录 4 表逐行一致（币种/周期规则/分期计划/分期排期）
    final currencies = await db.select(db.currencies).get();
    expect(currencies.single.code, 'USD');
    expect(currencies.single.rateScaled, 7200000);
    final rules = await db.select(db.recurringRules).get();
    expect(rules.single.type, 'expense');
    expect(rules.single.frequency, 'month');
    final plans = await db.select(db.installmentPlans).get();
    expect(plans.single.name, '手机分期');
    expect(plans.single.totalMinor, 12000);
    final schedules = await db.select(db.installmentSchedules).get();
    expect(schedules.single.amountMinor, 4000);
    await db.close();
  });

  test('错误口令恢复：明确报错且不破坏现有数据', () async {
    final db = await seedDb();
    final service = BackupService(db);
    final backup = await service.createBackup('正确口令');
    // 清空部分数据后尝试用错误口令恢复
    await (db.delete(db.transactions)).go();

    await expectLater(
      service.restore(backup, '错误口令'),
      throwsA(isA<BackupCipherException>()),
    );
    // 数据库未被恢复操作修改（流水仍为空）
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.accounts).get(), hasLength(1));
    await db.close();
  });

  test('损坏备份：GCM 认证失败，明确报错', () async {
    final db = await seedDb();
    final service = BackupService(db);
    final backup = await service.createBackup('口令');
    final tampered = Uint8List.fromList(backup);
    tampered[tampered.length ~/ 2] ^= 0xFF; // 篡改中间字节

    await expectLater(
      service.restore(tampered, '口令'),
      throwsA(isA<BackupCipherException>()),
    );
    expect(await db.select(db.transactions).get(), hasLength(1)); // 未受影响
    await db.close();
  });

  test('加解密往返（BackupCipher）', () async {
    final cipher = BackupCipher();
    final plain = Uint8List.fromList(utf8Encoded('你好，bookkeep 备份数据'));
    final encrypted = await cipher.encrypt(plain, '口令');
    final decrypted = await cipher.decrypt(encrypted, '口令');
    expect(String.fromCharCodes(decrypted), String.fromCharCodes(plain));
  });

  test('跨版本兼容：manifest 版本校验（更高 schema 拒绝）', () async {
    final db = await seedDb();
    final service = BackupService(db);
    final backup = await service.createBackup('口令');
    // 篡改明文后重加密以伪造更高版本（直接测试 _validate 的等价路径：
    // 更高 schema 版本应在恢复入口被拒）
    final cipher = BackupCipher();
    final plain = await _decryptWith(cipher, backup, '口令');
    final forged = plain.replaceAll(
      '"schema_version":${db.schemaVersion}',
      '"schema_version":${db.schemaVersion + 1}',
    );
    final forgedBackup = await cipher.encrypt(utf8Encoded(forged), '口令');

    await expectLater(
      service.restore(forgedBackup, '口令'),
      throwsA(isA<BackupCipherException>()),
    );
    await db.close();
  });

  test('FGDS（AC-02）：纯净背景约束下 bg_* 遗留键不入包、恢复后无背景态',
      () async {
    final src = await seedDb();
    // 直接写入历史遗留 bg_* 键（模拟旧版本升级库；现行代码已无写入入口）
    for (final pair in [
      'bg_enabled=true',
      'bg_image_path=background/bg.png',
      'bg_overlay_mode=manual',
      'bg_overlay_alpha=0.42',
      'bg_blur=false',
    ]) {
      final kv = pair.split('=');
      await src.into(src.appMeta).insert(
            AppMetaCompanion.insert(key: kv[0], value: kv[1]),
          );
    }
    final backup = await BackupService(src).createBackup('口令');

    // 快照明文显式断言：bg_* 键未入包
    final plain = await _decryptWith(BackupCipher(), backup, '口令');
    expect(plain, isNot(contains('bg_enabled')));
    expect(plain, isNot(contains('bg_image_path')));

    // 恢复至全新库：无悬空背景态（背景系统已拆除，仅剩纯色底）
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await BackupService(target).restore(backup, '口令');

    // 业务数据仍完整恢复（排除只作用于 app_meta 前缀键）
    final accounts = await target.select(target.accounts).get();
    expect(accounts.single.name, '钱包');
    await src.close();
  });
}

Uint8List utf8Encoded(String s) => Uint8List.fromList(utf8.encode(s));

Future<String> _decryptWith(BackupCipher cipher, Uint8List bytes, String password) async {
  final plain = await cipher.decrypt(bytes, password);
  return String.fromCharCodes(plain);
}
