import 'package:http/http.dart' as http;

import '../../core/network/json_http_client.dart';

class BookDto {
  const BookDto({required this.id, required this.name, required this.type, required this.role});
  final String id;
  final String name;
  final String type;
  final String role;

  factory BookDto.fromJson(Map<String, dynamic> json) => BookDto(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        role: json['role'] as String,
      );
}

class MemberDto {
  const MemberDto({required this.userId, required this.email, required this.role});
  final String userId;
  final String email;
  final String role;

  factory MemberDto.fromJson(Map<String, dynamic> json) => MemberDto(
        userId: json['user_id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
      );
}

/// 账本/邀请/成员 API（Spec §4.1 / BK-T-010）；未登录或不可达时抛 SyncNetworkException
/// Spec R-29：HTTP 层复用 [JsonHttpClient]
class BooksApi {
  BooksApi({required String baseUrl, http.Client? client})
      : _http = JsonHttpClient(baseUrl: baseUrl, client: client);

  final JsonHttpClient _http;

  Future<List<BookDto>> listBooks({required String accessToken}) async {
    final res = await _http.request('GET', '/books', accessToken: accessToken);
    final json = _http.json(res, 200, '/books');
    return [
      for (final b in json['books'] as List<dynamic>)
        BookDto.fromJson(b as Map<String, dynamic>),
    ];
  }

  Future<BookDto> createBook(String name, {String type = 'default', required String accessToken}) async {
    final res = await _http.request('POST', '/books',
        accessToken: accessToken, body: {'name': name, 'type': type});
    final json = _http.json(res, 201, '/books');
    return BookDto.fromJson({
      ...json['book'] as Map<String, dynamic>,
      'role': json['role'],
    });
  }

  Future<String> createInvite(String bookId, {String role = 'editor', required String accessToken}) async {
    final res = await _http.request('POST', '/books/$bookId/invites',
        accessToken: accessToken, body: {'role': role});
    final json = _http.json(res, 201, '/books/$bookId/invites');
    return json['token'] as String;
  }

  Future<BookDto> acceptInvite(String token, {required String accessToken}) async {
    final res = await _http.request('POST', '/books/accept-invite',
        accessToken: accessToken, body: {'token': token});
    final json = _http.json(res, 200, '/books/accept-invite');
    return BookDto.fromJson({
      ...json['book'] as Map<String, dynamic>,
      'role': json['role'],
    });
  }

  Future<List<MemberDto>> listMembers(String bookId, {required String accessToken}) async {
    final res = await _http.request('GET', '/books/$bookId/members', accessToken: accessToken);
    final json = _http.json(res, 200, '/books/$bookId/members');
    return [
      for (final m in json['members'] as List<dynamic>)
        MemberDto.fromJson(m as Map<String, dynamic>),
    ];
  }

  Future<void> removeMember(String bookId, String userId, {required String accessToken}) async {
    final res =
        await _http.request('DELETE', '/books/$bookId/members/$userId', accessToken: accessToken);
    _http.json(res, 204, '/books/$bookId/members/$userId');
  }

  /// 变更成员角色（仅 owner；服务端 PATCH /books/:id/members/:userId）
  Future<void> updateMemberRole(
    String bookId,
    String userId,
    String role, {
    required String accessToken,
  }) async {
    final res = await _http.request('PATCH', '/books/$bookId/members/$userId',
        accessToken: accessToken, body: {'role': role});
    _http.json(res, 200, '/books/$bookId/members/$userId');
  }
}
