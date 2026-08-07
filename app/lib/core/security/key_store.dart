import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 密钥托管抽象：设备端由 Keystore/Keychain 实现（Spec §1.3 / BK-P0-006）
abstract class KeyStore {
  Future<String?> readKey();
  Future<void> writeKey(String key);
  Future<void> delete();

  /// 读取或生成 32 字节 SQLCipher 密钥（hex 编码 64 字符）。
  /// hex 字符集不含引号 → PRAGMA key 插值无注入面（审查 B-2 / L-9）。
  Future<String> readOrCreateKey() async {
    final existing = await readKey();
    if (existing != null && isHexKey(existing)) return existing;
    final key = _generateHexKey();
    await writeKey(key);
    return key;
  }
}

bool isHexKey(String key) => key.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(key);

String _generateHexKey() {
  final rng = Random.secure();
  return List.generate(32, (_) => rng.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

class SecureStorageKeyStore extends KeyStore {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'bookkeep_db_key';

  @override
  Future<String?> readKey() => _storage.read(key: _keyName);

  @override
  Future<void> writeKey(String key) => _storage.write(key: _keyName, value: key);

  @override
  Future<void> delete() => _storage.delete(key: _keyName);
}

class InMemoryKeyStore extends KeyStore {
  String? _key;

  @override
  Future<String?> readKey() async => _key;

  @override
  Future<void> writeKey(String key) async => _key = key;

  @override
  Future<void> delete() async => _key = null;
}
