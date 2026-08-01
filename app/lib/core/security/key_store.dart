import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 密钥托管抽象：设备端由 Keystore/Keychain 实现（Spec §1.3 / BK-P0-006）
abstract class KeyStore {
  Future<String?> readKey();
  Future<void> writeKey(String key);
  Future<void> delete();
}

class SecureStorageKeyStore implements KeyStore {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'bookkeep_db_key';

  @override
  Future<String?> readKey() => _storage.read(key: _keyName);

  @override
  Future<void> writeKey(String key) => _storage.write(key: _keyName, value: key);

  @override
  Future<void> delete() => _storage.delete(key: _keyName);
}

class InMemoryKeyStore implements KeyStore {
  String? _key;

  @override
  Future<String?> readKey() async => _key;

  @override
  Future<void> writeKey(String key) async => _key = key;

  @override
  Future<void> delete() async => _key = null;
}
