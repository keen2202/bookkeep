import 'package:http/http.dart' as http;

import '../../core/network/json_http_client.dart';
import '../../domain/models/remote_op.dart';

export '../../core/network/json_http_client.dart'
    show SyncApiException, SyncNetworkException, JsonHttpClient;

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
      : _http = JsonHttpClient(baseUrl: baseUrl, client: client) {
    assertSecure(_http.baseUrl);
  }

  final JsonHttpClient _http;

  /// Spec R-06：生产/远程端点必须 HTTPS；仅 debug 下允许 localhost/127.0.0.1 的 http
  static void assertSecure(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme.isEmpty) {
      throw ArgumentError('invalid sync base url: $baseUrl');
    }
    if (uri.scheme == 'https') return;
    final isLocalHost =
        uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
    if (uri.scheme == 'http' && isLocalHost && const bool.fromEnvironment('dart.vm.product') == false) {
      return;
    }
    throw ArgumentError('sync endpoint must use HTTPS: $baseUrl');
  }

  @override
  Future<TokenPair> register(String email, String password) async {
    final res = await _http.request('POST', '/auth/register', body: {'email': email, 'password': password});
    return TokenPair.fromJson(_http.json(res, 201, '/auth/register'));
  }

  @override
  Future<TokenPair> login(String email, String password) async {
    final res = await _http.request('POST', '/auth/login', body: {'email': email, 'password': password});
    return TokenPair.fromJson(_http.json(res, 200, '/auth/login'));
  }

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    final res = await _http.request('POST', '/auth/refresh', body: {'refresh_token': refreshToken});
    return TokenPair.fromJson(_http.json(res, 200, '/auth/refresh'));
  }

  @override
  Future<PushResult> push(String bookId, List<Map<String, dynamic>> ops,
      {required String accessToken}) async {
    final res = await _http.request('POST', '/sync/push',
        accessToken: accessToken, body: {'book_id': bookId, 'ops': ops});
    final json = _http.json(res, 200, '/sync/push');
    return PushResult(
      acceptedSeq: json['accepted_seq'] as int,
      accepted: json['accepted'] as int,
    );
  }

  @override
  Future<PullResult> pull(String bookId, int sinceSeq,
      {required String accessToken, int limit = 500}) async {
    final uri = '/sync/pull?book_id=$bookId&since_seq=$sinceSeq&limit=$limit';
    final res = await _http.request('GET', uri, accessToken: accessToken);
    final json = _http.json(res, 200, '/sync/pull');
    final ops = (json['ops'] as List<dynamic>)
        .map((e) => RemoteOp.fromJson(e as Map<String, dynamic>))
        .toList();
    return PullResult(ops: ops, nextSeq: json['next_seq'] as int);
  }
}
