import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../../core/security/backup_cipher.dart';
import '../../data/local/database.dart';

/// 备份/恢复（Spec §4.3 / BK-T-012）：
/// 备份 = 全量 Drift 快照（各表原始列值）+ manifest，AES-256-GCM 加密打包；
/// 恢复 = 解密 → 校验 → 单事务原子切换（失败回滚，不破坏现有数据）。
class BackupService {
  BackupService(this.db, {BackupCipher? cipher}) : _cipher = cipher ?? BackupCipher();

  final AppDatabase db;
  final BackupCipher _cipher;

  static const format = 'bookkeep-backup';
  static const version = 1;

  /// 恢复时排除的 app_meta 键（设备身份/同步游标不得跨设备恢复）
  static const _excludedMetaPrefixes = ['client_id', 'sync_last_seq_'];

  // 父表在前（恢复按序插入；删除取 reversed 子表先删）。
  // 审查 F-4：补齐 currencies / recurring_rules / installment_plans / installment_schedules
  static const _tables = [
    'app_meta',
    'books',
    'accounts',
    'categories',
    'account_snapshots',
    'transactions',
    'budgets',
    'sync_ops',
    'currencies',
    'recurring_rules',
    'installment_plans',
    'installment_schedules',
  ];

  /// 创建加密备份字节
  Future<Uint8List> createBackup(String password) async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _tables) {
      final rows = await db.customSelect('SELECT * FROM $table').get();
      var data = [for (final r in rows) r.data];
      if (table == 'app_meta') {
        data = data.where((r) {
          final key = r['key'] as String? ?? '';
          return !_excludedMetaPrefixes.any(key.startsWith);
        }).toList();
      }
      tables[table] = data;
    }
    final snapshot = jsonEncode({
      'manifest': {
        'format': format,
        'version': version,
        'schema_version': db.schemaVersion,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'app_version': '0.1.0',
      },
      'tables': tables,
    });
    return _cipher.encrypt(utf8.encode(snapshot), password);
  }

  /// 恢复：错误口令/损坏文件抛 [BackupCipherException] 且不触碰现有数据；
  /// 成功后返回恢复的行数。
  Future<int> restore(Uint8List bytes, String password) async {
    final plain = await _cipher.decrypt(bytes, password); // 解密失败 → 无任何写库
    final snapshot = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    _validate(snapshot);
    final tables = snapshot['tables'] as Map<String, dynamic>;

    var restored = 0;
    await db.transaction(() async {
      // 子表先删（FK 顺序）
      for (final table in _tables.reversed) {
        await db.customStatement('DELETE FROM $table');
      }
      for (final table in _tables) {
        final rows = tables[table] as List<dynamic>? ?? const [];
        for (final row in rows) {
          final map = row as Map<String, dynamic>;
          final columns = map.keys.toList();
          final placeholders = List.filled(columns.length, '?').join(', ');
          await db.customStatement(
            'INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders)',
            [for (final c in columns) map[c]],
          );
          restored++;
        }
      }
    });
    return restored;
  }

  void _validate(Map<String, dynamic> snapshot) {
    final manifest = snapshot['manifest'];
    if (manifest is! Map<String, dynamic>) {
      throw const BackupCipherException('备份文件缺少 manifest，已拒绝恢复');
    }
    if (manifest['format'] != format) {
      throw const BackupCipherException('不是 bookkeep 备份文件');
    }
    final schemaVersion = manifest['schema_version'] as int? ?? 0;
    if (schemaVersion > db.schemaVersion) {
      throw BackupCipherException('备份来自更高版本（schema $schemaVersion > 当前 ${db.schemaVersion}），请先升级应用');
    }
  }
}
