import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_providers.dart';
import '../sync/sync_state.dart';
import '../sync/token_store.dart';

/// 设置页"账户与同步"分组（审查 B-1 / BK-FX-010）：
/// 登录/注册表单、同步状态指示、手动同步、退出登录。
class AccountSyncSection extends ConsumerStatefulWidget {
  const AccountSyncSection({super.key});

  @override
  ConsumerState<AccountSyncSection> createState() => _AccountSyncSectionState();
}

class _AccountSyncSectionState extends ConsumerState<AccountSyncSection> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  String? _email; // 已登录邮箱（从安全存储加载）
  bool _loadingEmail = true;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final email = await SecureTokenStore().readEmail();
    if (mounted) {
      setState(() {
        _email = email;
        _loadingEmail = false;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _snack('请输入有效邮箱');
      return;
    }
    if (password.length < 8) {
      _snack('密码至少 8 位');
      return;
    }
    final ok = await ref.read(syncStatusProvider.notifier).login(email, password);
    if (!ok) return;
    if (mounted) setState(() => _email = email);
  }

  Future<void> _logout() async {
    await ref.read(syncStatusProvider.notifier).logout();
    if (mounted) {
      setState(() => _email = null);
      _snack('已退出登录（本地数据保留）');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static const _phaseLabels = {
    SyncPhase.idle: '空闲',
    SyncPhase.pushing: '推送中…',
    SyncPhase.pulling: '拉取中…',
    SyncPhase.merging: '合并中…',
    SyncPhase.error: '同步出错',
  };

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider);
    final loggedIn = _email != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('账户与同步'),
          subtitle: Text(
            _loadingEmail
                ? '加载中…'
                : loggedIn
                    ? (_email ?? '已登录')
                    : '未登录：本地记账，登录后云端同步',
          ),
          trailing: loggedIn
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _statusChip(status),
                )
              : null,
        ),
        if (!_loadingEmail && !loggedIn) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '邮箱',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: '密码（≥8 位）',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: status.busy ? null : _submit,
                    icon: const Icon(Icons.login),
                    label: const Text('登录 / 注册'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!_loadingEmail && loggedIn) ...[
          ListTile(
            leading: Icon(
              switch (status.phase) {
                SyncPhase.idle => Icons.check_circle_outline,
                SyncPhase.error => Icons.error_outline,
                _ => Icons.sync,
              },
              color: status.phase == SyncPhase.error
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
            title: Text('同步状态：${_phaseLabels[status.phase]}'),
            subtitle: status.message == null ? null : Text(status.message!),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: status.busy ? null : () {
                      ref.read(syncStatusProvider.notifier).manualSync();
                    },
                    icon: const Icon(Icons.sync),
                    label: const Text('手动同步'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: status.busy ? null : _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('退出登录'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (status.message != null && !loggedIn)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              status.message!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
        const Divider(),
      ],
    );
  }

  Widget _statusChip(SyncUiState status) {
    final color = status.phase == SyncPhase.error
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.busy ? '同步中' : '已登录',
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}
