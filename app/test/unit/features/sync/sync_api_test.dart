import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bookkeep_app/features/sync/sync_api.dart';

void main() {
  const token = 'jwt-access';

  HttpSyncApi apiWith(Future<http.Response> Function(http.Request) handler) {
    return HttpSyncApi(baseUrl: 'https://api.test/v1', client: MockClient(handler));
  }

  test('register POSTs credentials and parses the token pair', () async {
    final api = apiWith((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/v1/auth/register');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['email'], 'a@b.c');
      return http.Response(
        jsonEncode({'access_token': 'at', 'refresh_token': 'rt'}),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final pair = await api.register('a@b.c', 'password-123');
    expect(pair.accessToken, 'at');
    expect(pair.refreshToken, 'rt');
  });

  test('login throws SyncApiException(401) on bad credentials', () async {
    final api = apiWith((_) async => http.Response(jsonEncode({'error': 'invalid'}), 401));
    await expectLater(
      api.login('a@b.c', 'wrong'),
      throwsA(isA<SyncApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('push sends the bearer token and op batch to /sync/push', () async {
    final api = apiWith((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/v1/sync/push');
      expect(req.headers['Authorization'], 'Bearer $token');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['book_id'], 'book-1');
      expect((body['ops'] as List).length, 1);
      return http.Response(
        jsonEncode({'accepted_seq': 7, 'accepted': 1}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result = await api.push('book-1', [
      {'entity': 'transaction', 'entity_id': 'x', 'op': 'c', 'payload': null, 'lamport': 1, 'client_id': 'y'},
    ], accessToken: token);
    expect(result.acceptedSeq, 7);
    expect(result.accepted, 1);
  });

  test('pull requests the cursor query params and parses ops', () async {
    final api = apiWith((req) async {
      expect(req.url.path, '/v1/sync/pull');
      expect(req.url.queryParameters['book_id'], 'book-1');
      expect(req.url.queryParameters['since_seq'], '12');
      expect(req.url.queryParameters['limit'], '500');
      return http.Response(
        jsonEncode({
          'ops': [
            {
              'entity': 'transaction',
              'entity_id': '99999999-9999-4999-8999-999999999999',
              'op': 'c',
              'payload': {'amount_minor': -100},
              'lamport': 3,
              'client_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            }
          ],
          'next_seq': 13,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final pull = await api.pull('book-1', 12, accessToken: token);
    expect(pull.nextSeq, 13);
    expect(pull.ops.single.entity, 'transaction');
    expect(pull.ops.single.payload, {'amount_minor': -100});
  });

  test('push throws SyncApiException(403) on forbidden access', () async {
    final api = apiWith((_) async => http.Response(jsonEncode({'error': 'forbidden'}), 403));
    await expectLater(
      api.push('book-1', const [], accessToken: token),
      throwsA(isA<SyncApiException>().having((e) => e.statusCode, 'statusCode', 403)),
    );
  });

  test('network failure surfaces as SyncNetworkException', () async {
    final api = apiWith((_) async => throw http.ClientException('connection refused'));
    await expectLater(
      api.pull('book-1', 0, accessToken: token),
      throwsA(isA<SyncNetworkException>()),
    );
  });

  test('server {error} body surfaces in SyncApiException message (BK-R-010)', () async {
    final api = apiWith((_) async => http.Response(jsonEncode({'error': 'viewer_cannot_write'}), 403));
    await expectLater(
      api.push('book-1', const [], accessToken: token),
      throwsA(isA<SyncApiException>()
          .having((e) => e.statusCode, 'statusCode', 403)
          .having((e) => e.message, 'message', contains('viewer_cannot_write'))),
    );
  });

  test('non-JSON error body still yields status-classified exception', () async {
    final api = apiWith((_) async => http.Response('<html>oops</html>', 500));
    await expectLater(
      api.push('book-1', const [], accessToken: token),
      throwsA(isA<SyncApiException>().having((e) => e.statusCode, 'statusCode', 500)),
    );
  });
}
