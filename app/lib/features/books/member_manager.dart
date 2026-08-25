import 'package:flutter/material.dart';

import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/glass_nav.dart';
import '../sync/sync_api.dart';
import 'books_api.dart';
import 'books_page.dart' show accessToken, booksApi;

/// 成员管理（Spec §4.1 / BK-T-010）：列表 + 移除/改角色（仅 owner）；
/// 未登录/不可达时优雅提示。
class MemberManagerSheet extends StatefulWidget {
  const MemberManagerSheet({super.key, required this.bookId, this.callerRole = 'owner'});

  final String bookId;

  /// 当前调用者角色（Spec §4.1：仅 owner 可移除/改角色；由入口注入）
  final String callerRole;

  static Future<void> show(BuildContext context,
      {required String bookId, String callerRole = 'owner'}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => MemberManagerSheet(bookId: bookId, callerRole: callerRole)),
    );
  }

  @override
  State<MemberManagerSheet> createState() => _MemberManagerSheetState();
}

class _MemberManagerSheetState extends State<MemberManagerSheet> {
  List<MemberDto>? _members;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await accessToken();
      if (token == null) {
        setState(() {
          _busy = false;
          _error = '尚未登录，无法查看成员';
        });
        return;
      }
      final members = await booksApi().listMembers(widget.bookId, accessToken: token);
      setState(() {
        _busy = false;
        _members = members;
      });
    } on SyncNetworkException {
      setState(() {
        _busy = false;
        _error = '无法连接同步服务';
      });
    } on SyncApiException catch (e) {
      setState(() {
        _busy = false;
        _error = '加载失败（${e.statusCode}）';
      });
    }
  }

  Future<void> _changeRole(MemberDto member, String role) async {
    try {
      final token = await accessToken();
      if (token == null) return;
      await booksApi().updateMemberRole(widget.bookId, member.userId, role,
          accessToken: token);
      if (!mounted) return;
      setState(() {
        final i = _members?.indexWhere((m) => m.userId == member.userId);
        if (i != null && i >= 0) {
          _members![i] = MemberDto(userId: member.userId, email: member.email, role: role);
        }
      });
    } on SyncApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.statusCode == 403 ? '仅 owner 可变更角色' : '变更失败')),
      );
    }
  }

  Future<void> _remove(MemberDto member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('移除 ${member.email}？'),
        content: const Text('移除后其立即失去该账本访问权限'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          AppButton.danger(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await accessToken();
      if (token == null) return;
      await booksApi().removeMember(widget.bookId, member.userId, accessToken: token);
      if (!mounted) return;
      setState(() => _members?.remove(member));
    } on SyncApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.statusCode == 403 ? '仅 owner 可移除成员' : '移除失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    return GlassScaffold(
      title: const Text('成员管理'),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : members == null
                  ? const SizedBox.shrink()
                  : ListView(
                      children: [
                        for (final member in members)
                          ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(member.email),
                            subtitle: Text(_roleLabel(member.role)),
                            trailing: member.role == 'owner'
                                ? const Icon(Icons.admin_panel_settings)
                                : widget.callerRole == 'owner'
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.swap_horiz),
                                            tooltip: '变更角色',
                                            onSelected: (role) => _changeRole(member, role),
                                            itemBuilder: (context) => [
                                              if (member.role != 'editor')
                                                const PopupMenuItem(
                                                    value: 'editor', child: Text('设为编辑者')),
                                              if (member.role != 'viewer')
                                                const PopupMenuItem(
                                                    value: 'viewer', child: Text('设为查看者')),
                                            ],
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.person_remove_outlined),
                                            tooltip: '移除',
                                            onPressed: () => _remove(member),
                                          ),
                                        ],
                                      )
                                    : null,
                          ),
                      ],
                    ),
    );
  }

  String _roleLabel(String role) => switch (role) {
        'owner' => '所有者',
        'editor' => '编辑者',
        'viewer' => '查看者',
        _ => role,
      };
}
