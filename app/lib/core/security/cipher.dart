import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// PBKDF2 迭代次数：PIN/口令哈希 ≥ 100k（Spec §3.6 / BK-P0-006）
const backupKeyIterations = 100000;

/// 派生密钥：PBKDF2-HMAC-SHA256，输出 32 字节（AES-256 密钥）
Future<List<int>> deriveBackupKey(
  String password,
  String salt, {
  int iterations = backupKeyIterations,
}) async {
  final algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  final secretKey = await algorithm.deriveKeyFromPassword(
    password: password,
    nonce: utf8.encode(salt),
  );
  return secretKey.extractBytes();
}
