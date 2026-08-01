import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/models/remote_op.dart';

class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  factory TokenPair.fromJson(Map<String, dynamic> json) => TokenPair(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
      );

  final String accessToken;
  final String refreshToken;
}

class PushResult {
  const PushResult({required this.acceptedSeq, required this.accepted});

  final int acceptedSeq;
  final int accepted;
}

class PullResult {
  const PullResult({required this.ops, required this.nextSeq});

  final List<RemoteOp> ops;
  final int nextSeq;
}

/// 网络层失败（离线/超时）→ 队列保持未推送，等待重试
class SyncNetworkException implements Exception {
  const SyncNetworkException(this.message);
  final String message;

  @override
  String toString() => 'SyncNetworkException: $message';
}

/// 服务端业务拒绝（401/403/409/422）
class SyncApiException implements Exception {
  const SyncApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'SyncApiException($statusCode): $message';
}

/// 同步 API 契约（OpenAPI sync-api.yaml）
abstract class SyncApi {
  Future<TokenPair> register(String email, String password);
  Future<TokenPair> login(String email, String password);
  Future<TokenPair> refresh(String refreshToken);
  Future<PushResult> push(String bookId, List<Map<String, dynamic>> ops,
      {required String accessToken});
  Future<PullResult> pull(String bookId, int sinceSeq,
      {required String accessToken, int limit = 500});
}

class HttpSyncApi implements SyncApi {
  HttpSyncApi({required String baseUrl, http.Client? client})
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
      throw SyncApiException(res.statusCode, '$path -> ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  @override
  Future<TokenPair> register(String email, String password) async {
    final res = await _request('POST', '/auth/register', body: {'email': email, 'password': password});
    return TokenPair.fromJson(_json(res, 201, '/auth/register'));
  }

  @override
  Future<TokenPair> login(String email, String password) async {
    final res = await _request('POST', '/auth/login', body: {'email': email, 'password': password});
    return TokenPair.fromJson(_json(res, 200, '/auth/login'));
  }

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    final res = await _request('POST', '/auth/refresh', body: {'refresh_token': refreshToken});
    return TokenPair.fromJson(_json(res, 200, '/auth/refresh'));
  }

  @override
  Future<PushResult> push(String bookId, List<Map<String, dynamic>> ops,
      {required String accessToken}) async {
    final res = await _request('POST', '/sync/push',
        accessToken: accessToken, body: {'book_id': bookId, 'ops': ops});
    final json = _json(res, 200, '/sync/push');
    return PushResult(
      acceptedSeq: json['accepted_seq'] as int,
      accepted: json['accepted'] as int,
    );
  }

  @override
  Future<PullResult> pull(String bookId, int sinceSeq,
      {required String accessToken, int limit = 500}) async {
    final uri = '/sync/pull?book_id=$bookId&since_seq=$sinceSeq&limit=$limit';
    final res = await _request('GET', uri, accessToken: accessToken);
    final json = _json(res, 200, '/sync/pull');
    final ops = (json['ops'] as List<dynamic>)
        .map((e) => RemoteOp.fromJson(e as Map<String, dynamic>))
        .toList();
    return PullResult(ops: ops, nextSeq: json['next_seq'] as int);
  }
}
