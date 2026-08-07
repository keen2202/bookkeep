import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/core/security/key_store.dart';
import 'package:bookkeep_app/data/local/database_encryption.dart';

void main() {
  group('KeyStore 密钥生成（审查 B-2）', () {
    test('readOrCreateKey 生成 32 字节 hex 密钥并持久化', () async {
      final store = InMemoryKeyStore();
      final key = await store.readOrCreateKey();
      expect(key.length, 64);
      expect(isHexKey(key), isTrue);
      // 二次读取复用已存密钥
      expect(await store.readOrCreateKey(), key);
    });

    test('已存非法密钥被替换为合法 hex', () async {
      final store = InMemoryKeyStore();
      await store.writeKey("o'Reilly");
      final key = await store.readOrCreateKey();
      expect(isHexKey(key), isTrue);
    });
  });

  group('明文库检测（SQLCipher 启动序列）', () {
    test('真实明文 SQLite 文件识别为明文', () {
      final dir = Directory.systemTemp.createTempSync('bk_plain_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/plain.sqlite');
      // 最小合法明文库：16 字节标准头 + 页数据
      file.writeAsBytesSync([
        ...kPlaintextHeader,
        ...List.filled(100, 0),
      ]);
      expect(isPlaintextDb(file), isTrue);
    });

    test('无文件 / 过小文件 / 非标准头 → false', () {
      final dir = Directory.systemTemp.createTempSync('bk_detect_');
      addTearDown(() => dir.deleteSync(recursive: true));
      expect(isPlaintextDb(File('${dir.path}/missing.sqlite')), isFalse);
      final tiny = File('${dir.path}/tiny.sqlite')..writeAsBytesSync([0, 1, 2]);
      expect(isPlaintextDb(tiny), isFalse);
      // 加密库头（随机字节）不被误判为明文
      final encrypted = File('${dir.path}/enc.sqlite')
        ..writeAsBytesSync(List.generate(16, (i) => i * 7 + 3));
      expect(isPlaintextDb(encrypted), isFalse);
    });
  });

  group('openEncryptedDatabase 密钥校验', () {
    test('非 hex 密钥直接抛 ArgumentError（PRAGMA 注入防护）', () {
      expect(
        () => openEncryptedDatabase('/tmp/whatever.db', "'; DROP TABLE users; --"),
        throwsArgumentError,
      );
    });
  });
}
