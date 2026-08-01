import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// PIN 哈希迭代次数：≥ 100k（Spec §3.6 / BK-P0-006 / BK-T-008）
const pinHashIterations = 100000;

/// PIN → 存储格式 `saltBase64$hashBase64`（PBKDF2-HMAC-SHA256 + 随机盐；
/// 禁止明文/可逆存储，Spec §3.6 安全清单第 3 项）
Future<String> hashPin(String pin, {Random? random}) async {
  final rng = random ?? Random.secure();
  final salt = List<int>.generate(16, (_) => rng.nextInt(256));
  final hash = await _pbkdf2(pin, salt);
  return '${base64Encode(salt)}\$${base64Encode(hash)}';
}

/// 校验 PIN 与存储哈希（常量时间比较，防时序侧信道）
Future<bool> verifyPinHash(String pin, String stored) async {
  final parts = stored.split(r'$');
  if (parts.length != 2) return false;
  late final List<int> salt;
  late final List<int> expected;
  try {
    salt = base64Decode(parts[0]);
    expected = base64Decode(parts[1]);
  } on FormatException {
    return false;
  }
  final actual = await _pbkdf2(pin, salt);
  if (actual.length != expected.length) return false;
  var diff = 0;
  for (var i = 0; i < actual.length; i++) {
    diff |= actual[i] ^ expected[i];
  }
  return diff == 0;
}

Future<List<int>> _pbkdf2(String pin, List<int> salt) async {
  final algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: pinHashIterations,
    bits: 256,
  );
  final secretKey = await algorithm.deriveKeyFromPassword(
    password: pin,
    nonce: salt,
  );
  return secretKey.extractBytes();
}
