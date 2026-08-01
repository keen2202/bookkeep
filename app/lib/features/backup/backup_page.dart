import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/security/backup_cipher.dart';
import '../../data/local/database_provider.dart';
import '../../data/local/tables/transactions_table.dart';
import '../books/books_providers.dart' show booksViewModelProvider, currentBookIdProvider;
import 'backup_service.dart';
import 'export_service.dart';
import 'webdav_client_wrapper.dart';

/// 备份与导出页（Spec §4.3 / BK-T-012）：CSV 导出 / 加密备份 / 恢复 / WebDAV
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  final _backupPasswordCtrl = TextEditingController();
  final _restorePasswordCtrl = TextEditingController();
  final _davEndpointCtrl = TextEditingController();
  final _davUserCtrl = TextEditingController();
  final _davPasswordCtrl = TextEditingController();
  String? _message;

  Future<String> _docsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<void> _createBackup() async {
    final password = _backupPasswordCtrl.text;
    if (password.isEmpty) {
      setState(() => _message = '请输入备份口令');
      return;
    }
    final bytes = await BackupService(ref.read(databaseProvider)).createBackup(password);
    final dir = await _docsDir();
    final path = '$dir/backup_${DateTime.now().millisecondsSinceEpoch}.bk';
    await File(path).writeAsBytes(bytes);
    setState(() => _message = '备份已保存：$path（${bytes.length} 字节，AES-256-GCM 加密）');
  }

  Future<void> _restore() async {
    final password = _restorePasswordCtrl.text;
    if (password.isEmpty) {
      setState(() => _message = '请输入恢复口令');
      return;
    }
    final dir = await _docsDir();
    final candidates = Directory(dir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.bk'))
        .toList();
    if (candidates.isEmpty) {
      setState(() => _message = '未找到备份文件（请先创建备份）');
      return;
    }
    candidates.sort((a, b) => b.path.compareTo(a.path));
    final path = candidates.first.path;
    try {
      final restored = await BackupService(ref.read(databaseProvider))
          .restore(await File(path).readAsBytes(), password);
      setState(() => _message = '恢复成功：$path（$restored 行）');
      ref.invalidate(booksViewModelProvider);
    } on BackupCipherException catch (e) {
      setState(() => _message = '恢复失败：${e.message}（现有数据未受影响）');
    }
  }

  Future<void> _exportCsv() async {
    final bookId = ref.read(currentBookIdProvider);
    final csv = await ExportService(ref.read(databaseProvider))
        .exportCsv(bookId: bookId, type: TransactionType.expense);
    final dir = await _docsDir();
    final path = '$dir/export_${DateTime.now().millisecondsSinceEpoch}.csv';
    await File(path).writeAsString(csv);
    setState(() => _message = 'CSV 已导出：$path（${csv.length} 字符）');
  }

  Future<void> _webdavUpload() async {
    final endpoint = _davEndpointCtrl.text.trim();
    if (endpoint.isEmpty) {
      setState(() => _message = '请输入 WebDAV 端点（仅 HTTPS）');
      return;
    }
    try {
      final password = _backupPasswordCtrl.text;
      if (password.isEmpty) {
        setState(() => _message = '请先设置备份口令');
        return;
      }
      final bytes = await BackupService(ref.read(databaseProvider)).createBackup(password);
      final client = WebDavClient(
        endpoint: endpoint,
        username: _davUserCtrl.text.isEmpty ? null : _davUserCtrl.text,
        password: _davPasswordCtrl.text.isEmpty ? null : _davPasswordCtrl.text,
      );
      await client.upload('bookkeep_${DateTime.now().millisecondsSinceEpoch}.bk', bytes);
      setState(() => _message = 'WebDAV 上传成功');
    } on WebDavException catch (e) {
      setState(() => _message = 'WebDAV 上传失败：${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份与导出')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('CSV 导出（当前账本支出明细）', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('导出 CSV'),
          ),
          const Divider(height: 32),
          Text('加密备份（AES-256-GCM，口令经 PBKDF2 派生）',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _backupPasswordCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: '备份口令'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _createBackup,
            icon: const Icon(Icons.lock_outline),
            label: const Text('创建加密备份'),
          ),
          const Divider(height: 32),
          Text('恢复备份（导入 → 校验 → 原子切换；口令错误不破坏现有数据）',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _restorePasswordCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: '恢复口令'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _restore,
            icon: const Icon(Icons.restore),
            label: const Text('从最新备份恢复'),
          ),
          const Divider(height: 32),
          Text('WebDAV 备份（仅 HTTPS 端点）', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _davEndpointCtrl,
            decoration: const InputDecoration(labelText: 'WebDAV 端点（https://...）'),
          ),
          TextField(
            controller: _davUserCtrl,
            decoration: const InputDecoration(labelText: '用户名（可选）'),
          ),
          TextField(
            controller: _davPasswordCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: '密码（可选）'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _webdavUpload,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('上传加密备份到 WebDAV'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_message!),
            ),
        ],
      ),
    );
  }
}
