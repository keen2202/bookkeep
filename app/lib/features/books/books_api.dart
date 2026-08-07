import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../sync/sync_api.dart';

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
class BooksApi {
  BooksApi({required String baseUrl, http.Client? client})
      : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Future<http.Response> _request(
    String method,
    String path, {
    Object? body,
    String? accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    try {
      return switch (method) {
        'GET' => await _client.get(uri, headers: headers).timeout(const Duration(seconds: 15)),
        'DELETE' => await _client
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 15)),
        'PATCH' => await _client
            .patch(uri, headers: headers, body: body == null ? null : jsonEncode(body))
            .timeout(const Duration(seconds: 15)),
        _ => await _client
            .post(uri, headers: headers, body: body == null ? null : jsonEncode(body))
            .timeout(const Duration(seconds: 15)),
      };
    } on TimeoutException {
      throw const SyncNetworkException('request timeout');
    } on SocketException catch (e) {
      throw SyncNetworkException('network error: ${e.message}');
    } on http.ClientException catch (e) {
      throw SyncNetworkException('network error: ${e.message}');
    }
  }

  Map<String, dynamic> _json(http.Response res, int expect, String path) {
    if (res.statusCode != expect) {
      // 解析服务端 {error} 字段（BK-R-010）：错误信息可读、可分类
      String message = '$path -> ${res.statusCode}';
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['error'] is String) {
          message = '${body['error']} ($path -> ${res.statusCode})';
        }
      } catch (_) {
        // 非 JSON 响应体：保留状态码信息
      }
      throw SyncApiException(res.statusCode, message);
    }
    if (res.body.isEmpty) return const {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<BookDto>> listBooks({required String accessToken}) async {
    final res = await _request('GET', '/books', accessToken: accessToken);
    final json = _json(res, 200, '/books');
    return [
      for (final b in json['books'] as List<dynamic>)
        BookDto.fromJson(b as Map<String, dynamic>),
    ];
  }

  Future<BookDto> createBook(String name, {String type = 'default', required String accessToken}) async {
    final res = await _request('POST', '/books',
        accessToken: accessToken, body: {'name': name, 'type': type});
    final json = _json(res, 201, '/books');
    return BookDto.fromJson({
      ...json['book'] as Map<String, dynamic>,
      'role': json['role'],
    });
  }

  Future<String> createInvite(String bookId, {String role = 'editor', required String accessToken}) async {
    final res = await _request('POST', '/books/$bookId/invites',
        accessToken: accessToken, body: {'role': role});
    final json = _json(res, 201, '/books/$bookId/invites');
    return json['token'] as String;
  }

  Future<BookDto> acceptInvite(String token, {required String accessToken}) async {
    final res = await _request('POST', '/books/accept-invite',
        accessToken: accessToken, body: {'token': token});
    final json = _json(res, 200, '/books/accept-invite');
    return BookDto.fromJson({
      ...json['book'] as Map<String, dynamic>,
      'role': json['role'],
    });
  }

  Future<List<MemberDto>> listMembers(String bookId, {required String accessToken}) async {
    final res = await _request('GET', '/books/$bookId/members', accessToken: accessToken);
    final json = _json(res, 200, '/books/$bookId/members');
    return [
      for (final m in json['members'] as List<dynamic>)
        MemberDto.fromJson(m as Map<String, dynamic>),
    ];
  }

  Future<void> removeMember(String bookId, String userId, {required String accessToken}) async {
    final res =
        await _request('DELETE', '/books/$bookId/members/$userId', accessToken: accessToken);
    _json(res, 204, '/books/$bookId/members/$userId');
  }

  /// 变更成员角色（仅 owner；服务端 PATCH /books/:id/members/:userId）
  Future<void> updateMemberRole(
    String bookId,
    String userId,
    String role, {
    required String accessToken,
  }) async {
    final res = await _request('PATCH', '/books/$bookId/members/$userId',
        accessToken: accessToken, body: {'role': role});
    _json(res, 200, '/books/$bookId/members/$userId');
  }
}
