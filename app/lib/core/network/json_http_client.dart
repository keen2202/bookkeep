import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// 网络层失败（离线/超时）→ 调用方可保持队列等待重试
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

/// Spec R-29：HTTP 请求/JSON 解析公共实现，避免 sync_api 与 books_api 逐字重复。
class JsonHttpClient {
  JsonHttpClient({required String baseUrl, http.Client? client})
      : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        client = client ?? http.Client();

  final String baseUrl;
  final http.Client client;

  Future<http.Response> request(
    String method,
    String path, {
    Object? body,
    String? accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    try {
      return switch (method) {
        'GET' => await client.get(uri, headers: headers).timeout(const Duration(seconds: 15)),
        'DELETE' => await client.delete(uri, headers: headers).timeout(const Duration(seconds: 15)),
        'PATCH' => await client
            .patch(uri, headers: headers, body: body == null ? null : jsonEncode(body))
            .timeout(const Duration(seconds: 15)),
        _ => await client
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

  Map<String, dynamic> json(http.Response res, int expect, String path) {
    if (res.statusCode != expect) {
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
}
