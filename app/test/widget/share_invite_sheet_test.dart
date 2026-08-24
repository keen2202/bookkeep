import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bookkeep_app/features/books/books_api.dart';
import 'package:bookkeep_app/features/books/books_page.dart';
import 'package:bookkeep_app/features/books/share_invite_sheet.dart';

const bookId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

/// v3 玻璃化（GLS-006）：AppButton 非文字变体改自绘玻璃管线（不再是
/// ButtonStyleButton 子类），按文案直接命中按钮中心
Future<void> tapGenerateButton(WidgetTester tester) async {
  // 页面标题（titleMedium）与按钮文案同名：取最后一个命中按钮标签
  await tester.tap(find.text('生成邀请链接').last);
  await tester.pumpAndSettle();
}

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
    await tester.pumpWidget(const MaterialApp(home: ShareInviteSheet(bookId: bookId)));
    await tester.pumpAndSettle();
  }

  testWidgets('渲染邀请页：说明文案/角色选择/加入表单', (tester) async {
    await pumpSheet(tester, handler: (_) async => http.Response('', 500));

    expect(find.text('共享账本'), findsOneWidget);
    expect(find.text('邀请链接 72 小时内有效，且仅可使用一次。成员角色：'), findsOneWidget);
    expect(find.text('编辑者（可记账）'), findsOneWidget); // 默认选中 editor
    expect(find.text('加入共享账本'), findsOneWidget);
    expect(find.text('粘贴他人分享的 token'), findsOneWidget);
    expect(find.text('加入'), findsOneWidget);

    // 打开角色下拉后两个选项均可见
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('查看者（只读）'), findsOneWidget);
  });

  testWidgets('生成邀请链接并显示 token（携带 role 参数）', (tester) async {
    var inviteCalled = false;
    await pumpSheet(tester, handler: (req) async {
      if (req.method == 'POST' && req.url.path == '/books/$bookId/invites') {
        inviteCalled = true;
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['role'], 'editor');
        return http.Response(jsonEncode({'token': 't0k3n', 'expires_at': 'x'}), 201);
      }
      return http.Response('not found', 404);
    });

    await tapGenerateButton(tester);

    expect(inviteCalled, isTrue);
    expect(find.text('邀请 token'), findsOneWidget);
    expect(find.text('t0k3n'), findsOneWidget);
  });

  testWidgets('复制按钮写入剪贴板', (tester) async {
    final log = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      log.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpSheet(tester, handler: (_) async {
      return http.Response(jsonEncode({'token': 'copy-me'}), 201);
    });
    await tapGenerateButton(tester);

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pumpAndSettle();

    expect(log.map((c) => c.method), contains('Clipboard.setData'));
    expect((log.last.arguments as Map)['text'], 'copy-me');
  });

  testWidgets('403 无权限生成邀请提示', (tester) async {
    await pumpSheet(tester,
        handler: (_) async => http.Response(jsonEncode({'error': 'forbidden'}), 403));

    await tapGenerateButton(tester);

    expect(find.text('当前角色无权限邀请成员'), findsOneWidget);
  });

  testWidgets('网络错误提示无法连接同步服务', (tester) async {
    await pumpSheet(tester, handler: (_) async => throw http.ClientException('refused'));

    await tapGenerateButton(tester);

    expect(find.text('无法连接同步服务'), findsOneWidget);
  });

  testWidgets('未登录时提示并引导粘贴他人 token', (tester) async {
    await pumpSheet(tester, handler: (_) async => http.Response('', 500),
        tokenHook: () async => null);

    await tapGenerateButton(tester);

    expect(
      find.text('尚未登录，无法生成邀请链接（可先在下方输入他人分享的 token 加入账本）'),
      findsOneWidget,
    );
  });

  testWidgets('粘贴 token 加入账本成功', (tester) async {
    await pumpSheet(tester, handler: (req) async {
      if (req.method == 'POST' && req.url.path == '/books/accept-invite') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['token'], 'inv-abc');
        return http.Response(
          jsonEncode({
            'book': {'id': bookId, 'name': '家庭账本', 'type': 'family'},
            'role': 'editor',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('not found', 404);
    });

    await tester.enterText(find.byType(TextField), 'inv-abc');
    await tester.tap(find.text('加入'));
    await tester.pumpAndSettle();

    expect(find.text('已加入「家庭账本」'), findsOneWidget);
  });

  testWidgets('无效 token（404）提示 token 无效', (tester) async {
    await pumpSheet(tester,
        handler: (_) async => http.Response(jsonEncode({'error': 'not found'}), 404));

    await tester.enterText(find.byType(TextField), 'bad-token');
    await tester.tap(find.text('加入'));
    await tester.pumpAndSettle();

    expect(find.text('token 无效'), findsOneWidget);
  });

  testWidgets('token 已被使用（409）与已过期（410）提示', (tester) async {
    await pumpSheet(tester, handler: (_) async {
      return http.Response(jsonEncode({'error': 'used'}), 409);
    });
    await tester.enterText(find.byType(TextField), 'used-token');
    await tester.tap(find.text('加入'));
    await tester.pumpAndSettle();
    expect(find.text('token 已被使用'), findsOneWidget);

    await pumpSheet(tester, handler: (_) async {
      return http.Response(jsonEncode({'error': 'expired'}), 410);
    });
    await tester.enterText(find.byType(TextField), 'exp-token');
    await tester.tap(find.text('加入'));
    await tester.pumpAndSettle();
    expect(find.text('token 已过期（72h）'), findsOneWidget);
  });
}
