import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/services/capture_candidate.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/glass_nav.dart';
import '../../books/books_providers.dart' show transactionRepositoryProvider;
import '../capture_confirm_page.dart';
import '../import_service.dart';

/// CSV 导入页（Spec §4.2 / BK-T-011）：粘贴账单 CSV → 解析 → 去重 → 确认页入账。
/// 支持支付宝/微信账单格式自动识别。
class CsvImportPage extends ConsumerStatefulWidget {
  const CsvImportPage({super.key});

  @override
  ConsumerState<CsvImportPage> createState() => _CsvImportPageState();
}

class _CsvImportPageState extends ConsumerState<CsvImportPage> {
  final _csvCtrl = TextEditingController();
  String? _source;
  String? _hint;
  List<CaptureCandidate>? _parsed;

  Future<void> _parse() async {
    final csv = _csvCtrl.text.trim();
    if (csv.isEmpty) return;
    final service = CsvImportService(ref.read(transactionRepositoryProvider));
    final source = _detectSource(csv);
    final candidates = service.parse(csv, source: source);
    if (candidates.isEmpty) {
      setState(() {
        _parsed = null;
        _hint = '未识别到有效账单记录（请确认粘贴的是支付宝/微信账单 CSV）';
      });
      return;
    }
    // 去重（批内 + 库内；幂等回归：重复导入不产生重复流水）
    final deduped = await service.dedupe(candidates);
    setState(() {
      _parsed = deduped;
      _source = source;
      _hint = '共识别 ${candidates.length} 条，其中重复 ${candidates.length - deduped.length} 条已跳过';
    });
  }

  String _detectSource(String csv) {
    if (csv.contains('交易分类') && csv.contains('交易对方')) return '支付宝';
    if (csv.contains('交易类型') && csv.contains('交易对方')) return '微信';
    return '支付宝';
  }

  Future<void> _confirm() async {
    final parsed = _parsed;
    if (parsed == null || parsed.isEmpty) return;
    await CaptureConfirmPage.show(context, candidates: parsed, source: _source);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    return GlassScaffold(
      title: const Text('CSV 导入'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('粘贴支付宝/微信账单 CSV（导出账单后复制内容）：'),
            const SizedBox(height: 8),
            TextField(
              controller: _csvCtrl,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '交易时间,交易分类,交易对方,...',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton.primary(
                    onPressed: _parse,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_file, size: 18),
                        SizedBox(width: 8),
                        Text('解析并去重'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_hint!),
              ),
            if (parsed != null && parsed.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppButton.secondary(
                onPressed: _confirm,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fact_check_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text('确认入账（${parsed.length} 笔）'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 设置页权限/功能引导项（Spec §4.2：通知/短信权限按需申请并明示用途；
/// 本环境以说明 + 入口为主，权限申请在设备端接入）
class AutoCaptureSettingsEntry extends StatelessWidget {
  const AutoCaptureSettingsEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.table_chart_outlined),
          title: const Text('CSV 导入'),
          subtitle: const Text('支付宝/微信账单导入，自动去重'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CsvImportPage()),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.notifications_active_outlined),
          title: Text('通知/短信自动记账'),
          subtitle: Text('需在设备端授权通知与短信读取权限（按需申请，明示用途）'),
          enabled: false,
        ),
      ],
    );
  }
}
