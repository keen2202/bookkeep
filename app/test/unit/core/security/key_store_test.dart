import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/core/security/key_store.dart';

void main() {
  test('in-memory key store roundtrips and clears the key', () async {
    final store = InMemoryKeyStore();

    expect(await store.readKey(), isNull);

    await store.writeKey('a-secret-key');
    expect(await store.readKey(), 'a-secret-key');

    await store.delete();
    expect(await store.readKey(), isNull);
  });

  test('secure storage key store writes and reads through the platform backend', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureStorageKeyStore();
    await store.writeKey('keystore-key');
    expect(await store.readKey(), 'keystore-key');
    await store.delete();
    expect(await store.readKey(), isNull);
  });
}
