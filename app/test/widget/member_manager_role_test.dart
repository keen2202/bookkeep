import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bookkeep_app/features/books/books_api.dart';
import 'package:bookkeep_app/features/books/books_page.dart';
import 'package:bookkeep_app/features/books/member_manager.dart';
import 'package:bookkeep_app/features/sync/token_store.dart';

/// 成员管理改角色（Spec §4.1 / BK-T-010）：仅 owner 可见并执行角色变更。
void main() {
  late List<Map<String, String>> patchCalls;

  setUp(() {
    patchCalls = [];
    accessTokenHook = () async => 'test-token';
    booksApiFactory = () => BooksApi(
          baseUrl: 'http://test',
          client: MockClient((request) async {
            if (request.method == 'PATCH') {
              patchCalls.add({
                'path': request.url.path,
                'body': request.body,
              });
              return http.Response(
                  jsonEncode({'user_id': 'u2', 'role': 'viewer'}), 200);
            }
            if (request.method == 'DELETE') {
              return http.Response('', 204);
            }
            if (request.method == 'GET' &&
                request.url.path == '/books/b1/members') {
              return http.Response(
                  jsonEncode({
                    'members': [
                      {'user_id': 'u1', 'email': 'owner@test', 'role': 'owner'},
                      {'user_id': 'u2', 'email': 'editor@test', 'role': 'editor'},
                      {'user_id': 'u3', 'email': 'viewer@test', 'role': 'viewer'},
                    ],
                  }),
                  200);
            }
            return http.Response('not found', 404);
          }),
        );
  });

  tearDown(() {
    booksApiFactory = () => BooksApi(baseUrl: 'http://localhost:3000');
    accessTokenHook = () async =>
        SecureTokenStore().read().then((t) => t?.accessToken);
  });

  Widget harness(String callerRole) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  MemberManagerSheet.show(context, bookId: 'b1', callerRole: callerRole),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('owner 可将成员设为查看者并更新列表', (tester) async {
    await tester.pumpWidget(harness('owner'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('editor@test'), findsOneWidget);
    expect(find.text('编辑者'), findsOneWidget);

    // 打开编辑者的角色菜单 → 设为查看者
    await tester.tap(find.descendant(
      of: find.widgetWithText(ListTile, 'editor@test'),
      matching: find.byIcon(Icons.swap_horiz),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设为查看者'));
    await tester.pumpAndSettle();

    expect(patchCalls, hasLength(1));
    expect(patchCalls.single['path'], '/books/b1/members/u2');
    expect(patchCalls.single['body'], contains('viewer'));
    // editor@test 行已变为「查看者」
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'editor@test'),
        matching: find.text('查看者'),
      ),
      findsOneWidget,
    );
    // 设为查看者后菜单不再出现该项
    await tester.tap(find.descendant(
      of: find.widgetWithText(ListTile, 'editor@test'),
      matching: find.byIcon(Icons.swap_horiz),
    ));
    await tester.pumpAndSettle();
    expect(find.text('设为查看者'), findsNothing);
    expect(find.text('设为编辑者'), findsOneWidget);
  });

  testWidgets('owner 可将成员设为编辑者', (tester) async {
    await tester.pumpWidget(harness('owner'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.widgetWithText(ListTile, 'viewer@test'),
      matching: find.byIcon(Icons.swap_horiz),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设为编辑者'));
    await tester.pumpAndSettle();

    expect(patchCalls, hasLength(1));
    expect(patchCalls.single['body'], contains('editor'));
  });

  testWidgets('非 owner 调用者看不到角色变更与移除入口', (tester) async {
    await tester.pumpWidget(harness('editor'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('editor@test'), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz), findsNothing);
    expect(find.byIcon(Icons.person_remove_outlined), findsNothing);
  });

  testWidgets('owner 移除成员仍可用（确认框流程）', (tester) async {
    await tester.pumpWidget(harness('owner'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.widgetWithText(ListTile, 'editor@test'),
      matching: find.byIcon(Icons.person_remove_outlined),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();

    expect(find.text('editor@test'), findsNothing);
  });
}
