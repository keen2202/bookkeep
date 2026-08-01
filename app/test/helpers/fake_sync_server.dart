import 'package:bookkeep_app/domain/models/remote_op.dart';
import 'package:bookkeep_app/features/sync/sync_api.dart';

/// 内存版同步服务端（镜像 OpenAPI sync-api.yaml 语义）：
/// - register/login/refresh 返回 token 对
/// - push：book 不存在自动建账（调用者为 owner）；非成员 403；viewer 不可写；
///   按 (book_id, entity, entity_id, lamport, client_id) 去重后分配递增 seq
/// - pull：游标分页
/// - offline=true 时全部抛 [SyncNetworkException]（模拟断网）
class FakeSyncServer implements SyncApi {
  final _users = <String, String>{}; // email -> password
  final _books = <String, Set<String>>{}; // bookId -> member emails
  final _roles = <String, Map<String, String>>{}; // bookId -> email -> role
  final _ops = <String, List<Map<String, dynamic>>>{}; // bookId -> ops (with seq)
  var _seq = 0;

  bool offline = false;

  void addMember(String bookId, String email, {String role = 'editor'}) {
    _books.putIfAbsent(bookId, () => {}).add(email);
    _roles.putIfAbsent(bookId, () => {})[email] = role;
  }

  int get seq => _seq;

  void _checkOnline() {
    if (offline) throw const SyncNetworkException('offline');
  }

  void _requireUser(String email, String password) {
    if (_users[email] != password) throw const SyncApiException(401, 'invalid_credentials');
  }

  String _memberOf(String bookId, String email) {
    if (!_books.containsKey(bookId)) return 'owner'; // 自动建账
    return _roles[bookId]?[email] ?? '';
  }

  @override
  Future<TokenPair> register(String email, String password) async {
    _checkOnline();
    if (_users.containsKey(email)) throw const SyncApiException(409, 'email_taken');
    _users[email] = password;
    return TokenPair(accessToken: 'access-$email', refreshToken: 'refresh-$email');
  }

  @override
  Future<TokenPair> login(String email, String password) async {
    _checkOnline();
    _requireUser(email, password);
    return TokenPair(accessToken: 'access-$email', refreshToken: 'refresh-$email');
  }

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    _checkOnline();
    return TokenPair(accessToken: '$refreshToken-new-access', refreshToken: '$refreshToken-new');
  }

  @override
  Future<PushResult> push(String bookId, List<Map<String, dynamic>> ops,
      {required String accessToken}) async {
    _checkOnline();
    final email = accessToken.replaceFirst('access-', '');
    final role = _memberOf(bookId, email);
    if (role.isEmpty) throw const SyncApiException(403, 'forbidden');
    if (role == 'viewer') throw const SyncApiException(403, 'viewer_cannot_write');

    final store = _ops.putIfAbsent(bookId, () => []);
    final seen = store.map((o) => _dedupKey(o)).toSet();
    var accepted = 0;
    for (final raw in ops) {
      final key = _dedupKey(raw);
      if (seen.contains(key)) continue;
      seen.add(key);
      _seq++;
      store.add({...raw, 'seq': _seq});
      accepted++;
    }
    final lastSeq = store.isNotEmpty ? store.last['seq'] as int : 0;
    return PushResult(acceptedSeq: lastSeq, accepted: accepted);
  }

  @override
  Future<PullResult> pull(String bookId, int sinceSeq,
      {required String accessToken, int limit = 500}) async {
    _checkOnline();
    final email = accessToken.replaceFirst('access-', '');
    if (!_books.containsKey(bookId) || !_books[bookId]!.contains(email)) {
      // 服务端语义：book 不存在时自动建账（与真实服务端一致）
      _books.putIfAbsent(bookId, () => {}).add(email);
      _roles.putIfAbsent(bookId, () => {})[email] = 'owner';
    }
    final store = _ops[bookId] ?? [];
    final rows = store.where((o) => (o['seq'] as int) > sinceSeq).take(limit).toList();
    final ops = rows
        .map((o) => RemoteOp.fromJson(Map<String, dynamic>.from(o)..remove('seq')))
        .toList();
    final nextSeq = rows.isNotEmpty ? rows.last['seq'] as int : sinceSeq;
    return PullResult(ops: ops, nextSeq: nextSeq);
  }

  String _dedupKey(Map<String, dynamic> op) {
    return '${op['book_id'] ?? ''}:${op['entity']}:${op['entity_id']}:${op['lamport']}:${op['client_id']}';
  }
}
