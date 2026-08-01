import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/core/security/cipher.dart';

void main() {
  group('deriveBackupKey (PBKDF2-HMAC-SHA256)', () {
    test('derives a deterministic 32-byte key for identical inputs', () async {
      final k1 = await deriveBackupKey('correct horse', 'salt');
      final k2 = await deriveBackupKey('correct horse', 'salt');

      expect(k1, hasLength(32));
      expect(k1, k2);
    });

    test('derives a different key for a different password', () async {
      final k1 = await deriveBackupKey('password-a', 'salt');
      final k2 = await deriveBackupKey('password-b', 'salt');

      expect(k1, isNot(k2));
    });

    test('derives a different key for a different salt', () async {
      final k1 = await deriveBackupKey('password', 'salt-a');
      final k2 = await deriveBackupKey('password', 'salt-b');

      expect(k1, isNot(k2));
    });

    test('uses at least 100k PBKDF2 iterations (Spec §3.6 PIN storage)', () {
      expect(backupKeyIterations, greaterThanOrEqualTo(100000));
    });

    test('produces the RFC 7914 PBKDF2-HMAC-SHA256 known vector', () async {
      // PBKDF2-HMAC-SHA256("password", "salt", 1, 32) = 120fb6cf...be17b
      final key = await deriveBackupKey('password', 'salt', iterations: 1);
      expect(key, [
        0x12, 0x0f, 0xb6, 0xcf, 0xfc, 0xf8, 0xb3, 0x2c, //
        0x43, 0xe7, 0x22, 0x52, 0x56, 0xc4, 0xf8, 0x37, //
        0xa8, 0x65, 0x48, 0xc9, 0x2c, 0xcc, 0x35, 0x48, //
        0x08, 0x05, 0x98, 0x7c, 0xb7, 0x0b, 0xe1, 0x7b,
      ]);
    });
  });
}
