import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/tables/accounts_table.dart';
import 'package:bookkeep_app/data/local/tables/transactions_table.dart';
import 'package:bookkeep_app/features/backup/export_service.dart';
import 'package:bookkeep_app/features/backup/webdav_client_wrapper.dart';

import '../../../helpers/sqlite.dart';

const bookId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const otherBook = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

void main() {
  ensureSqliteLoaded();

  Future<AppDatabase> seedDb() async {
    final db = AppDatabase(NativeDatabase.memory());
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(
          bookId: const Value(bookId),
          accountType: AccountType.cash,
          name: '钱包',
          currency: 'CNY',
          createdAt: DateTime.utc(2026, 8, 1),
        ));
    Future<void> addTx({
      required DateTime at,
      required int amount,
      String? note,
      String book = bookId,
      TransactionType type = TransactionType.expense,
    }) {
      return db.into(db.transactions).insert(TransactionsCompanion.insert(
            bookId: Value(book),
            accountId: accountId,
            type: type,
            amountMinor: amount,
            currency: 'CNY',
            note: Value(note),
            occurredAt: at,
            updatedAt: at,
          ));
    }

    await addTx(at: DateTime.utc(2026, 7, 1, 12), amount: -1000, note: '含,逗号"引号"');
    await addTx(at: DateTime.utc(2026, 7, 15, 12), amount: -2500, note: '中文备注');
    await addTx(at: DateTime.utc(2026, 8, 1, 12), amount: -3000, note: '八月');
    await addTx(at: DateTime.utc(2026, 8, 2, 12), amount: 5000, type: TransactionType.income);
    await addTx(book: otherBook, at: DateTime.utc(2026, 8, 3, 12), amount: -999, note: '其他账本');
    return db;
  }

  test('CSV 导出：区间/账本筛选 + 中文与逗号引号转义正确', () async {
    final db = await seedDb();
    final csv = await ExportService(db).exportCsv(
      bookId: bookId,
      start: DateTime.utc(2026, 7, 1),
      end: DateTime.utc(2026, 8, 1),
    );
    final lines = csv.trim().split('\n');
    expect(lines, hasLength(3)); // 表头 + 7月2笔（8月的被区间排除，其他账本被隔离）
    expect(lines[1], contains('"含,逗号""引号"""')); // 引号转义
    expect(lines[1], contains('-¥10.00'));
    expect(lines[2], contains('中文备注'));
    // 账本隔离：不含其他账本的 999
    expect(csv, isNot(contains('999')));
    await db.close();
  });

  test('CSV 导出：类型筛选（仅收入）', () async {
    final db = await seedDb();
    final csv = await ExportService(db).exportCsv(
      bookId: bookId,
      type: TransactionType.income,
    );
    final lines = csv.trim().split('\n');
    expect(lines, hasLength(2)); // 表头 + 1笔收入
    expect(lines[1], contains('收入'));
    expect(lines[1], contains('¥50.00'));
    await db.close();
  });

  test('WebDAV：HTTP 端点被拒绝（仅 HTTPS，Spec §4.3）', () async {
    final client = WebDavClient(endpoint: 'http://dav.example.com');
    expect(() => client.assertSecure(), throwsA(isA<WebDavException>()));
    await expectLater(
      client.upload('x.bk', Uint8List(0)),
      throwsA(isA<WebDavException>()),
    );
    await expectLater(
      client.download('x.bk'),
      throwsA(isA<WebDavException>()),
    );
  });

  test('WebDAV 上传/下载往返（mock 服务）', () async {
    final uploaded = <int, Uint8List>{};
    final mock = MockClient((request) async {
      if (request.method == 'PUT') {
        uploaded[request.url.path.hashCode] = request.bodyBytes;
        return http.Response('', 201);
      }
      if (request.method == 'GET') {
        final body = uploaded[request.url.path.hashCode];
        if (body == null) return http.Response('', 404);
        return http.Response.bytes(body, 200);
      }
      return http.Response('', 405);
    });

    final client = WebDavClient(
      endpoint: 'https://dav.example.com',
      client: mock,
      username: 'user',
      password: 'pass',
    );
    final data = Uint8List.fromList(List.generate(256, (i) => i % 251));
    await client.upload('backups/bk1.bk', data);
    final downloaded = await client.download('backups/bk1.bk');
    expect(downloaded, data);
  });
}
