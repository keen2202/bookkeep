import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bookkeep_app/features/books/books_api.dart';
import 'package:bookkeep_app/features/sync/sync_api.dart';

void main() {
  const token = 'jwt-access';

  BooksApi apiWith(Future<http.Response> Function(http.Request) handler) {
    return BooksApi(baseUrl: 'https://api.test/v1', client: MockClient(handler));
  }

  test('updateMemberRole sends PATCH with role body (BK-R-010)', () async {
    final api = apiWith((req) async {
      expect(req.method, 'PATCH');
      expect(req.url.path, '/v1/books/book-1/members/u1');
      expect(req.headers['Authorization'], 'Bearer $token');
      expect(jsonDecode(req.body), {'role': 'viewer'});
      return http.Response(jsonEncode({'user_id': 'u1', 'role': 'viewer'}), 200);
    });
    await api.updateMemberRole('book-1', 'u1', 'viewer', accessToken: token);
  });

  test('removeMember sends DELETE and accepts 204 (BK-R-010)', () async {
    final api = apiWith((req) async {
      expect(req.method, 'DELETE');
      expect(req.url.path, '/v1/books/book-1/members/u1');
      return http.Response('', 204);
    });
    await api.removeMember('book-1', 'u1', accessToken: token);
  });

  test('server {error} body surfaces in exception message (BK-R-010)', () async {
    final api = apiWith((_) async => http.Response(jsonEncode({'error': 'owner_only'}), 403));
    await expectLater(
      api.updateMemberRole('book-1', 'u1', 'editor', accessToken: token),
      throwsA(isA<SyncApiException>()
          .having((e) => e.statusCode, 'statusCode', 403)
          .having((e) => e.message, 'message', contains('owner_only'))),
    );
  });
}
