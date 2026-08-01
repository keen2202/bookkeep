import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/core/security/pin_hash.dart';

void main() {
  group('hashPin', () {
    test('不存储明文 PIN，且随机盐使相同 PIN 的哈希不同', () async {
      final rng = Random(42);
      final a = await hashPin('123456', random: rng);
      final b = await hashPin('123456', random: Random(43));
      expect(a, isNot(contains('123456')));
      expect(a, isNot(equals(b)));
      expect(a.split(r'$'), hasLength(2));
    });

    test('迭代次数 ≥ 100k（Spec §3.6）', () {
      expect(pinHashIterations, greaterThanOrEqualTo(100000));
    });
  });

  group('verifyPinHash', () {
    test('正确 PIN 校验通过，错误 PIN 拒绝', () async {
      final stored = await hashPin('246810', random: Random(1));
      expect(await verifyPinHash('246810', stored), isTrue);
      expect(await verifyPinHash('246811', stored), isFalse);
      expect(await verifyPinHash('', stored), isFalse);
    });

    test('损坏/篡改存储值安全返回 false', () async {
      final stored = await hashPin('123456', random: Random(2));
      expect(await verifyPinHash('123456', 'malformed'), isFalse);
      expect(await verifyPinHash('123456', 'onlysalt'), isFalse);
      expect(await verifyPinHash('123456', '!!notbase64!!\$abc'), isFalse);
      expect(await verifyPinHash('123456', '$stored-tampered'), isFalse);
    });

    test('未配置（null）不通过校验', () async {
      expect(await verifyPinHash('123456', ''), isFalse);
    });
  });
}
