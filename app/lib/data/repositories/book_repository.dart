import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/database.dart';

/// 账本仓库（Spec §4.1 / BK-T-010）：本地 books 缓存 + 当前账本切换；
/// 服务端为成员/权限权威，共享成员经邀请接口同步到服务端。
class BookRepository {
  BookRepository(this.db);
  final AppDatabase db;

  Future<Book?> currentBook() async {
    final id = await db.currentBookId();
    return (db.select(db.books)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<String> currentBookId() => db.currentBookId();

  Future<void> switchBook(String bookId) async {
    await db.setCurrentBookId(bookId);
  }

  Future<List<Book>> listBooks() async {
    final q = db.select(db.books)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.get();
  }

  /// 新建本地账本（服务端账本经 POST /books 创建后调用本方法缓存）
  Future<void> createLocalBook({
    required String id,
    required String name,
    String type = 'default',
  }) async {
    await db.into(db.books).insert(
          BooksCompanion.insert(
            id: id,
            name: name,
            type: Value(type),
            createdAt: DateTime.now().toUtc(),
          ),
          onConflict: DoNothing(),
        );
  }

  /// 当前用户在该账本的角色（Spec §4.1 权限矩阵）；服务端为权威，
  /// 此处为本地缓存（离线时保持最近一次同步值），未知默认 owner。
  Future<String> roleOf(String bookId) async {
    final rows = await (db.select(db.appMeta)
          ..where((t) => t.key.equals('book_role_$bookId')))
        .get();
    return rows.isEmpty ? 'owner' : rows.single.value;
  }

  Future<void> setRole(String bookId, String role) async {
    await db.into(db.appMeta).insert(
          AppMetaCompanion.insert(key: 'book_role_$bookId', value: role),
          onConflict: DoUpdate((_) => AppMetaCompanion(value: Value(role))),
        );
  }

  /// 确保默认账本在 books 表中存在（v4 迁移后必存在，防御性回填）
  Future<String> ensureDefaultBook() async {
    var id = await db.currentBookId();
    final row = await (db.select(db.books)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      id = const Uuid().v4();
      await db.setCurrentBookId(id);
      await createLocalBook(id: id, name: '默认账本');
    }
    return id;
  }
}
