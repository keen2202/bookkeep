import 'dart:io';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../../core/security/key_store.dart';
import 'database.dart';

/// SQLCipher 启动序列（审查 B-2 / Spec §1.3 BK-P0-006）：
/// 明文头检测 → sqlcipher_export 迁移（行数校验）→ 加密打开。
/// 密钥经 KeyStore（Keystore/Keychain）托管；hex 编码无引号注入面。

/// SQLite 明文文件头（前 16 字节）；SQLCipher 加密库无此头
const List<int> kPlaintextHeader = [
  0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
  0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
];

/// 库文件是否为明文 SQLite（不存在 / 过小 / 加密 → false）
bool isPlaintextDb(File dbFile) {
  if (!dbFile.existsSync()) return false;
  final raf = dbFile.openSync(mode: FileMode.read);
  try {
    if (raf.lengthSync() < kPlaintextHeader.length) return false;
    final head = raf.readSync(kPlaintextHeader.length);
    if (head.length != kPlaintextHeader.length) return false;
    for (var i = 0; i < kPlaintextHeader.length; i++) {
      if (head[i] != kPlaintextHeader[i]) return false;
    }
    return true;
  } finally {
    raf.closeSync();
  }
}

Map<String, int> _tableCounts(sql.Database db) {
  final tables = db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
  );
  final counts = <String, int>{};
  for (final row in tables) {
    final name = row['name'] as String;
    counts[name] = (db.select('SELECT COUNT(*) AS c FROM "$name"').first['c'] as int?) ?? 0;
  }
  return counts;
}

/// 明文库 → 加密库一次性迁移：源库逐表行数 → sqlcipher_export 到加密临时库 →
/// 加密目标行数校验 → 原子替换原文件。任何失败不动原文件（返回 false）。
/// 密钥必须是 64 字符 hex（见 [isHexKey]），杜绝 PRAGMA key 插值注入。
bool migratePlaintextToEncrypted(File dbFile, String key, {Directory? tempDir}) {
  if (!isHexKey(key)) throw ArgumentError('key must be 64-char hex');
  if (!dbFile.existsSync()) return false;
  final temp = File(
    '${(tempDir ?? Directory.systemTemp).path}/bookkeep_encrypted_${DateTime.now().millisecondsSinceEpoch}.db',
  );
  Map<String, int> expected;
  try {
    final source = sql.sqlite3.open(dbFile.path, mode: sql.OpenMode.readOnly);
    try {
      expected = _tableCounts(source);
      source.execute("ATTACH DATABASE '${temp.path}' AS encrypted KEY '$key'");
      source.execute("SELECT sqlcipher_export('encrypted')");
      source.execute('DETACH DATABASE encrypted');
      // 源库应未被导出动作修改
      if (_tableCounts(source) != expected) return false;
    } finally {
      source.close();
    }

    // 用密钥打开加密目标，逐表行数与源一致才算迁移成功
    final target = sql.sqlite3.open(temp.path);
    try {
      target.execute("PRAGMA key = '$key'");
      if (_tableCounts(target) != expected) return false;
    } finally {
      target.close();
    }

    // 替换原文件（清理 -wal/-shm 残留）
    for (final suffix in ['-wal', '-shm']) {
      final side = File('${dbFile.path}$suffix');
      if (side.existsSync()) side.deleteSync();
    }
    dbFile.deleteSync();
    temp.renameSync(dbFile.path);
    return true;
  } catch (_) {
    if (temp.existsSync()) temp.deleteSync();
    return false;
  }
}

/// 打开加密库（drift NativeDatabase + PRAGMA key）；密钥非 hex 直接抛错
AppDatabase openEncryptedDatabase(String path, String key) {
  if (!isHexKey(key)) throw ArgumentError('key must be 64-char hex');
  return AppDatabase(NativeDatabase(File(path), setup: (db) {
    // SQLCipher 的 PRAGMA key 不支持绑定参数；hex 密钥无引号字符 → 无注入面
    db.execute("PRAGMA key = '$key'");
  }));
}
