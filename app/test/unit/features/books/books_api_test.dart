import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bookkeep_app/features/books/books_api.dart';
import 'package:bookkeep_app/features/sync/sync_api.dart';

void main() {
  const token = 'jwt-access';

  BooksApi apiWith(Future<http.Response> Function(http.Request) handler) {
    return BooksApi(baseUrl: 'http://test', client: MockClient(handler));
  }

  group('listBooks', () {
    test('GET /books 携带 Bearer token 并解析账本列表', () async {
      final api = apiWith((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, '/books');
        expect(req.headers['Authorization'], 'Bearer $token');
        return http.Response(
          jsonEncode({
            'books': [
              {'id': 'b1', 'name': '家庭账本', 'type': 'family', 'role': 'owner'},
              {'id': 'b2', 'name': '旅行账本', 'type': 'travel', 'role': 'editor'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final books = await api.listBooks(accessToken: token);
      expect(books, hasLength(2));
      expect(books[0].id, 'b1');
      expect(books[0].name, '家庭账本');
      expect(books[0].role, 'owner');
      expect(books[1].type, 'travel');
    });

    test('状态码非 200 抛 SyncApiException', () async {
      final api = apiWith((_) async => http.Response(jsonEncode({'error': 'x'}), 401));
      await expectLater(
        api.listBooks(accessToken: token),
        throwsA(isA<SyncApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  group('createBook', () {
    test('POST /books 201 解析 book 与 role', () async {
      final api = apiWith((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/books');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['name'], '新账本');
        expect(body['type'], 'life');
        return http.Response(
          jsonEncode({
            'book': {'id': 'b3', 'name': '新账本', 'type': 'life'},
            'role': 'owner',
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final book = await api.createBook('新账本', type: 'life', accessToken: token);
      expect(book.id, 'b3');
      expect(book.name, '新账本');
      expect(book.role, 'owner');
    });

    test('422 抛 SyncApiException(422)', () async {
      final api = apiWith((_) async => http.Response(jsonEncode({'error': 'name invalid'}), 422));
      await expectLater(
        api.createBook('  ', accessToken: token),
        throwsA(isA<SyncApiException>().having((e) => e.statusCode, 'statusCode', 422)),
      );
    });
  });

  group('createInvite', () {
    test('POST /books/{id}/invites 201 返回 token', () async {
      final api = apiWith((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/books/b1/invites');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['role'], 'editor');
        return http.Response(
          jsonEncode({'token': 'a' * 64, 'expires_at': '2099-01-01T00:00:00Z'}),
          201,
        );
      });

      final created = await api.createInvite('b1', accessToken: token);
      expect(created, 'a' * 64);
    });

    test('403 抛 SyncApiException(403)', () async {
      final api = apiWith((_) async => http.Response(jsonEncode({'error': 'forbidden'}), 403));
      await expectLater(
        api.createInvite('b1', accessToken: token),
        throwsA(isA<SyncApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });
  });

  group('acceptInvite', () {
    test('POST /books/accept-invite 200 解析 book/role', () async {
      final api = apiWith((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/books/accept-invite');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['token'], 'inv-token');
        return http.Response(
          jsonEncode({
            'book': {'id': 'b1', 'name': '家庭账本', 'type': 'family'},
            'role': 'editor',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final book = await api.acceptInvite('inv-token', accessToken: token);
      expect(book.id, 'b1');
      expect(book.role, 'editor');
    });

    test('404/410 抛对应 SyncApiException', () async {
      final api404 =
          apiWith((_) async => http.Response(jsonEncode({'error': 'not found'}), 404));
      await expectLater(
        api404.acceptInvite('bad', accessToken: token),
        throwsA(isA<SyncApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );

      final api410 =
          apiWith((_) async => http.Response(jsonEncode({'error': 'expired'}), 410));
      await expectLater(
        api410.acceptInvite('expired', accessToken: token),
        throwsA(isA<SyncApiException>().having((e) => e.statusCode, 'statusCode', 410)),
      );
    });
  });

  group('listMembers', () {
    test('GET members 解析成员列表', () async {
      final api = apiWith((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, '/books/b1/members');
        return http.Response(
          jsonEncode({
            'members': [
              {'user_id': 'u1', 'email': 'a@x.com', 'role': 'owner'},
              {'user_id': 'u2', 'email': 'b@x.com', 'role': 'editor'},
            ],
          }),
          200,
        );
      });

      final members = await api.listMembers('b1', accessToken: token);
      expect(members, hasLength(2));
      expect(members[0].userId, 'u1');
      expect(members[0].email, 'a@x.com');
      expect(members[1].role, 'editor');
    });
  });

  group('removeMember', () {
    test('DELETE 204 成功', () async {
      final api = apiWith((req) async {
        expect(req.method, 'DELETE');
        expect(req.url.path, '/books/b1/members/u2');
        expect(req.headers['Authorization'], 'Bearer $token');
        return http.Response('', 204);
      });

      await api.removeMember('b1', 'u2', accessToken: token);
    });

    test('非 204 抛 SyncApiException', () async {
      final api = apiWith((_) async => http.Response(jsonEncode({'error': 'forbidden'}), 403));
      await expectLater(
        api.removeMember('b1', 'u2', accessToken: token),
        throwsA(isA<SyncApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });
  });

  group('网络错误', () {
    test('ClientException → SyncNetworkException', () async {
      final api = apiWith((_) async => throw http.ClientException('connection refused'));
      await expectLater(
        api.listBooks(accessToken: token),
        throwsA(isA<SyncNetworkException>()),
      );
    });

    test('TimeoutException → SyncNetworkException', () async {
      final api = apiWith((_) async => throw TimeoutException('timed out'));
      await expectLater(
        api.listBooks(accessToken: token),
        throwsA(isA<SyncNetworkException>()),
      );
    });
  });
}
