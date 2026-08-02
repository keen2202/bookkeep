import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money_format.dart';
import '../../data/local/database.dart';
import '../auth_lock/lock_controller.dart';
import '../books/books_providers.dart'
    show accountRepositoryProvider, currentRoleProvider;
import 'account_card.dart';
import 'account_edit_sheet.dart';
import 'accounts_providers.dart';

/// 账户/资产管理页（Spec §3.2 / BK-P0-002）
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(accountsViewModelProvider);
    final viewer = ref.watch(currentRoleProvider) == 'viewer';
    return Scaffold(
      appBar: AppBar(title: const Text('账户')),
      body: viewModel.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (vm) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(accountsViewModelProvider),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('净资产', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(
                          ref.watch(amountMaskProvider)
                              ? maskedMoney()
                              : formatMoney(vm.netWorth),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (vm.accounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('还没有账户，点击右下角 + 新建')),
                )
              else
                for (final entry in vm.accounts)
                  _AccountTile(account: entry.account, balance: entry.balance),
            ],
          ),
        ),
      ),
      // viewer 只读（Spec §4.1 权限矩阵：UI 与服务端双重拒绝）
      floatingActionButton: viewer
          ? null
          : FloatingActionButton(
              onPressed: () => AccountEditSheet.show(context),
              tooltip: '新建账户',
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account, required this.balance});

  final Account account;
  final int balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onLongPress: () => _showActions(context, ref),
      child: AccountCard(account: account, balance: balance),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    if (ref.read(currentRoleProvider) == 'viewer') return;
    final repo = ref.read(accountRepositoryProvider);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('归档'),
              onTap: () => Navigator.pop(context, 'archive'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'edit':
        await AccountEditSheet.show(context, account: account);
      case 'archive':
        await repo.archiveAccount(account.id);
    }
    ref.invalidate(accountsViewModelProvider);
  }
}
