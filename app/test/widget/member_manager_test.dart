import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bookkeep_app/features/books/books_api.dart';
import 'package:bookkeep_app/features/books/books_page.dart';
import 'package:bookkeep_app/features/books/member_manager.dart';

const bookId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

const members = [
  {'user_id': 'u1', 'email': 'owner@x.com', 'role': 'owner'},
  {'user_id': 'u2', 'email': 'editor@x.com', 'role': 'editor'},
  {'user_id': 'u3', 'email': 'viewer@x.com', 'role': 'viewer'},
];

void main() {
  late BooksApi Function() origFactory;
  late Future<String?> Function() origHook;

  setUpAll(() {
    origFactory = booksApiFactory;
    origHook = accessTokenHook;
  });

  tearDown(() {
    booksApiFactory = origFactory;
    accessTokenHook = origHook;
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    required Future<http.Response> Function(http.Request) handler,
    Future<String?> Function()? tokenHook,
  }) async {
    booksApiFactory = () => BooksApi(baseUrl: 'http://test', client: MockClient(handler));
    accessTokenHook = tokenHook ?? () async => 'tok';
    await tester.pumpWidget(const MaterialApp(home: MemberManagerSheet(bookId: bookId)));
    await tester.pumpAndSettle();
  }

  testWidgets('渲染成员列表与 owner/editor/viewer 三种角色标签', (tester) async {
    await pumpSheet(tester, handler: (_) async {
      return http.Response(jsonEncode({'members': members}), 200);
    });

    expect(find.text('成员管理'), findsOneWidget);
    expect(find.text('owner@x.com'), findsOneWidget);
    expect(find.text('editor@x.com'), findsOneWidget);
    expect(find.text('viewer@x.com'), findsOneWidget);
    expect(find.text('所有者'), findsOneWidget);
    expect(find.text('编辑者'), findsOneWidget);
    expect(find.text('查看者'), findsOneWidget);
    // owner 无移除按钮，editor/viewer 各有 1 个
    expect(find.byIcon(Icons.person_remove_outlined), findsNWidgets(2));
  });

  testWidgets('点移除弹确认框，确认后调用 removeMember 并移除列表项', (tester) async {
    var removedUserId = '';
    await pumpSheet(tester, handler: (req) async {
      if (req.method == 'GET') {
        return http.Response(jsonEncode({'members': members}), 200);
      }
      if (req.method == 'DELETE') {
        expect(req.url.path, '/books/$bookId/members/u2');
        expect(req.headers['Authorization'], 'Bearer tok');
        removedUserId = 'u2';
        return http.Response('', 204);
      }
      return http.Response('not found', 404);
    });

    await tester.tap(find.byIcon(Icons.person_remove_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('移除 editor@x.com？'), findsOneWidget);
    expect(find.text('移除后其立即失去该账本访问权限'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '移除'));
    await tester.pumpAndSettle();

    expect(removedUserId, 'u2');
    expect(find.text('editor@x.com'), findsNothing);
    expect(find.text('viewer@x.com'), findsOneWidget);
  });

  testWidgets('取消移除不调用 API 且列表不变', (tester) async {
    var deleteCalled = false;
    await pumpSheet(tester, handler: (req) async {
      if (req.method == 'DELETE') {
        deleteCalled = true;
        return http.Response('', 204);
      }
      return http.Response(jsonEncode({'members': members}), 200);
    });

    await tester.tap(find.byIcon(Icons.person_remove_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(deleteCalled, isFalse);
    expect(find.text('editor@x.com'), findsOneWidget);
  });

  testWidgets('移除失败 403 提示仅 owner 可移除成员', (tester) async {
    await pumpSheet(tester, handler: (req) async {
      if (req.method == 'DELETE') {
        return http.Response(jsonEncode({'error': 'forbidden'}), 403);
      }
      return http.Response(jsonEncode({'members': members}), 200);
    });

    await tester.tap(find.byIcon(Icons.person_remove_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '移除'));
    await tester.pumpAndSettle();

    expect(find.text('仅 owner 可移除成员'), findsOneWidget);
    expect(find.text('editor@x.com'), findsOneWidget); // 列表未移除
  });

  testWidgets('成员加载失败（403）展示错误文案', (tester) async {
    await pumpSheet(tester, handler: (_) async {
      return http.Response(jsonEncode({'error': 'forbidden'}), 403);
    });

    expect(find.text('加载失败（403）'), findsOneWidget);
  });

  testWidgets('未登录时提示无法查看成员', (tester) async {
    var apiCalled = false;
    await pumpSheet(tester, handler: (req) async {
      apiCalled = true;
      return http.Response(jsonEncode({'members': members}), 200);
    }, tokenHook: () async => null);

    expect(apiCalled, isFalse);
    expect(find.text('尚未登录，无法查看成员'), findsOneWidget);
  });

  testWidgets('网络错误提示无法连接同步服务', (tester) async {
    await pumpSheet(tester, handler: (_) async => throw http.ClientException('refused'));

    expect(find.text('无法连接同步服务'), findsOneWidget);
  });
}
