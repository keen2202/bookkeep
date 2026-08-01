import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'cipher.dart';

/// 备份加密（Spec §4.3 / BK-T-012）：AES-256-GCM，密钥由用户备份口令经
/// PBKDF2 派生（口令不落盘）；GCM 认证标签保证完整性（错误口令/损坏文件必失败）。
///
/// 文件格式：salt(16) + nonce(12) + ciphertext(含 16 字节 GCM tag)
class BackupCipher {
  BackupCipher({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  static const _saltLength = 16;
  static const _nonceLength = 12;

  static final _aes = AesGcm.with256bits();

  Future<Uint8List> encrypt(Uint8List plaintext, String password) async {
    final salt = Uint8List.fromList(List<int>.generate(_saltLength, (_) => _random.nextInt(256)));
    final nonce = Uint8List.fromList(List<int>.generate(_nonceLength, (_) => _random.nextInt(256)));
    final key = await deriveBackupKey(password, base64Encode(salt));
    final box = await _aes.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final result = Uint8List(salt.length + nonce.length + box.cipherText.length + box.mac.bytes.length);
    result.setRange(0, salt.length, salt);
    result.setRange(salt.length, salt.length + nonce.length, nonce);
    result.setRange(
      salt.length + nonce.length,
      salt.length + nonce.length + box.cipherText.length,
      box.cipherText,
    );
    result.setRange(result.length - box.mac.bytes.length, result.length, box.mac.bytes);
    return result;
  }

  /// 解密：口令错误/数据损坏时 GCM 认证失败，抛出 [BackupCipherException]
  Future<Uint8List> decrypt(Uint8List data, String password) async {
    if (data.length < _saltLength + _nonceLength + 16 + 1) {
      throw const BackupCipherException('备份文件不完整或已损坏');
    }
    final salt = Uint8List.sublistView(data, 0, _saltLength);
    final nonce = Uint8List.sublistView(data, _saltLength, _saltLength + _nonceLength);
    const macLength = 16;
    final cipherText = Uint8List.sublistView(
      data,
      _saltLength + _nonceLength,
      data.length - macLength,
    );
    final mac = Uint8List.sublistView(data, data.length - macLength);
    final key = await deriveBackupKey(password, base64Encode(salt));
    try {
      final clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(key),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const BackupCipherException('口令错误或备份文件已损坏');
    }
  }
}

class BackupCipherException implements Exception {
  const BackupCipherException(this.message);
  final String message;

  @override
  String toString() => 'BackupCipherException: $message';
}
