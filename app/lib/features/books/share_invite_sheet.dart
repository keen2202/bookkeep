import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/glass_nav.dart';
import '../sync/sync_api.dart';
import 'books_page.dart' show accessToken, booksApi;

/// 邀请成员（Spec §4.1 / BK-T-010）：生成 72h 一次性 token（服务端）；
/// 未登录/不可达时明确提示并允许粘贴 token 加入他人账本。
class ShareInviteSheet extends StatefulWidget {
  const ShareInviteSheet({super.key, required this.bookId});

  final String bookId;

  static Future<void> show(BuildContext context, {required String bookId}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShareInviteSheet(bookId: bookId)),
    );
  }

  @override
  State<ShareInviteSheet> createState() => _ShareInviteSheetState();
}

class _ShareInviteSheetState extends State<ShareInviteSheet> {
  String? _token;
  String? _error;
  bool _busy = false;
  String _role = 'editor';
  final _joinCtrl = TextEditingController();
  String? _joinResult;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await accessToken();
      if (token == null) {
        setState(() {
          _busy = false;
          _error = '尚未登录，无法生成邀请链接（可先在下方输入他人分享的 token 加入账本）';
        });
        return;
      }
      final created =
          await booksApi().createInvite(widget.bookId, role: _role, accessToken: token);
      setState(() {
        _busy = false;
        _token = created;
      });
    } on SyncNetworkException {
      setState(() {
        _busy = false;
        _error = '无法连接同步服务';
      });
    } on SyncApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.statusCode == 403 ? '当前角色无权限邀请成员' : '邀请失败（${e.statusCode}）';
      });
    }
  }

  Future<void> _join() async {
    final token = _joinCtrl.text.trim();
    if (token.isEmpty) return;
    setState(() {
      _busy = true;
      _joinResult = null;
    });
    try {
      final access = await accessToken();
      if (access == null) {
        setState(() {
          _busy = false;
          _joinResult = '尚未登录，无法加入共享账本';
        });
        return;
      }
      final book = await booksApi().acceptInvite(token, accessToken: access);
      setState(() {
        _busy = false;
        _joinResult = '已加入「${book.name}」';
      });
    } on SyncNetworkException {
      setState(() {
        _busy = false;
        _joinResult = '无法连接同步服务';
      });
    } on SyncApiException catch (e) {
      setState(() {
        _busy = false;
        _joinResult = switch (e.statusCode) {
          404 => 'token 无效',
          409 => 'token 已被使用',
          410 => 'token 已过期（72h）',
          _ => '加入失败（${e.statusCode}）',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: const Text('共享账本'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('生成邀请链接', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('邀请链接 72 小时内有效，且仅可使用一次。成员角色：'),
          DropdownButtonFormField<String>(
            initialValue: _role,
            items: const [
              DropdownMenuItem(value: 'editor', child: Text('编辑者（可记账）')),
              DropdownMenuItem(value: 'viewer', child: Text('查看者（只读）')),
            ],
            onChanged: (v) => setState(() => _role = v ?? 'editor'),
          ),
          const SizedBox(height: 12),
          AppButton.primary(
            onPressed: _busy ? null : _generate,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link, size: 18),
                SizedBox(width: 8),
                Text('生成邀请链接'),
              ],
            ),
          ),
          if (_token != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('邀请 token'),
                subtitle: Text(_token!,
                    style: Theme.of(context).textTheme.bodySmall),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: '复制',
                  onPressed: () => Clipboard.setData(ClipboardData(text: _token!)),
                ),
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const Divider(height: 32),
          Text('加入共享账本', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _joinCtrl,
            decoration: const InputDecoration(labelText: '粘贴他人分享的 token'),
          ),
          const SizedBox(height: 12),
          AppButton.secondary(
            onPressed: _busy ? null : _join,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.login, size: 18),
                SizedBox(width: 8),
                Text('加入'),
              ],
            ),
          ),
          if (_joinResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_joinResult!),
            ),
        ],
      ),
    );
  }
}
