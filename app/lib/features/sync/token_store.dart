import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sync_api.dart';

/// 同步 token 存取抽象：生产用 [SecureTokenStore]（Keychain/Keystore），测试用内存实现。
abstract class TokenStore {
  Future<TokenPair?> read();
  Future<void> write(TokenPair tokens);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'sync_access_token';
  static const _refreshKey = 'sync_refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<TokenPair?> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    return TokenPair(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> write(TokenPair tokens) async {
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._pair]);

  TokenPair? _pair;

  @override
  Future<TokenPair?> read() async => _pair;

  @override
  Future<void> write(TokenPair tokens) async => _pair = tokens;

  @override
  Future<void> clear() async => _pair = null;
}
