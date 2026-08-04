import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// WebDAV 上传/下载（Spec §4.3 / BK-T-012）：仅允许 HTTPS 端点；
/// 备份文件已加密，传输层另有 TLS 保护。
class WebDavClient {
  WebDavClient({
    required String endpoint,
    this._username,
    this._password,
    http.Client? client,
  })  : _endpoint = endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint,
        _client = client ?? http.Client();

  final String _endpoint;
  final String? _username;
  final String? _password;
  final http.Client _client;

  /// 仅 HTTPS（WebDav 明文端点拒绝）
  void assertSecure() {
    final uri = Uri.parse(_endpoint);
    if (uri.scheme != 'https') {
      throw const WebDavException('WebDAV 仅支持 HTTPS 端点');
    }
  }

  Map<String, String> get _headers => {
        if (_username != null)
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$_username:$_password'))}',
      };

  Future<void> upload(String path, Uint8List bytes) async {
    assertSecure();
    try {
      final res = await _client
          .put(Uri.parse('$_endpoint/$path'),
              headers: {..._headers, 'Content-Type': 'application/octet-stream'},
              body: bytes)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode >= 400) {
        throw WebDavException('上传失败（HTTP ${res.statusCode}）');
      }
    } on TimeoutException {
      throw const WebDavException('上传超时');
    } on SocketException catch (e) {
      throw WebDavException('网络错误：${e.message}');
    }
  }

  Future<Uint8List> download(String path) async {
    assertSecure();
    try {
      final res = await _client
          .get(Uri.parse('$_endpoint/$path'), headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 404) {
        throw const WebDavException('备份文件不存在');
      }
      if (res.statusCode >= 400) {
        throw WebDavException('下载失败（HTTP ${res.statusCode}）');
      }
      return res.bodyBytes;
    } on TimeoutException {
      throw const WebDavException('下载超时');
    } on SocketException catch (e) {
      throw WebDavException('网络错误：${e.message}');
    }
  }
}

class WebDavException implements Exception {
  const WebDavException(this.message);
  final String message;

  @override
  String toString() => 'WebDavException: $message';
}
