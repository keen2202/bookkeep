import 'package:flutter/material.dart';

import '../../domain/services/capture_candidate.dart';
import '../../shared/widgets/app_button.dart';
import 'capture_confirm_page.dart';
import 'sms_parser.dart';

/// 语音识别接口抽象（Spec §4.2 / BK-T-011）：默认关闭，预留 LLM 抽取扩展。
/// 设备端实现（如系统 STT）接入后返回文本，规则引擎抽取金额/分类/时间。
abstract class VoiceRecognizer {
  Future<String?> recognize();
}

/// 默认关闭的实现：不调用任何系统能力
class DisabledVoiceRecognizer implements VoiceRecognizer {
  const DisabledVoiceRecognizer();

  @override
  Future<String?> recognize() async => null;
}

/// 规则引擎抽取：文本 → 候选（分类/金额/时间）
class VoiceRuleEngine {
  const VoiceRuleEngine();

  CaptureCandidate? extract(String text) {
    // 复用短信规则引擎（金额/方向/对方正则）
    final candidate = SmsCaptureParser().parse(text);
    if (candidate == null) return null;
    // 时间抽取：今天/昨天/明天 或 HH:mm
    final now = DateTime.now();
    final day = now;
    DateTime occurredAt = candidate.occurredAt;
    if (text.contains('昨天')) {
      occurredAt = day.subtract(const Duration(days: 1));
    } else if (text.contains('明天')) {
      occurredAt = day.add(const Duration(days: 1));
    } else if (text.contains('今天')) {
      occurredAt = day;
    }
    final timeRe = RegExp(r'(\d{1,2})[:：](\d{2})');
    final timeMatch = timeRe.firstMatch(text);
    if (timeMatch != null) {
      occurredAt = DateTime(
        occurredAt.year,
        occurredAt.month,
        occurredAt.day,
        int.parse(timeMatch.group(1)!),
        int.parse(timeMatch.group(2)!),
      );
    }
    return CaptureCandidate(
      amountMinor: candidate.amountMinor,
      occurredAt: occurredAt,
      counterparty: candidate.counterparty,
      type: candidate.type,
      categoryName: _categoryHint(text),
      source: 'voice',
      raw: text,
    );
  }

  String? _categoryHint(String text) {
    // 具体词优先（打车/地铁 先于 午餐 判定），避免同句多词误判
    const hints = {
      '打车': '交通', '地铁': '交通', '公交': '交通',
      '电影': '娱乐', '游戏': '娱乐',
      '超市': '日用', '购物': '购物',
      '早餐': '早餐', '午餐': '午餐', '晚餐': '晚餐', '饭': '午餐',
    };
    for (final entry in hints.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }
}

/// 语音记账入口（Spec §4.2 / BK-T-011）：语音转文本（默认关闭）→ 规则引擎抽取 → 确认页。
/// 设备支持输入文本模拟（供测试与降级使用）。
class VoiceEntrySheet extends StatefulWidget {
  const VoiceEntrySheet({super.key, this.recognizer});

  final VoiceRecognizer? recognizer;

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VoiceEntrySheet()),
    );
  }

  @override
  State<VoiceEntrySheet> createState() => _VoiceEntrySheetState();
}

class _VoiceEntrySheetState extends State<VoiceEntrySheet> {
  final _textCtrl = TextEditingController();
  String? _hint;

  Future<void> _recognize() async {
    final recognizer = widget.recognizer ?? const DisabledVoiceRecognizer();
    final text = await recognizer.recognize();
    if (text == null || text.isEmpty) {
      setState(() => _hint = '语音识别未开启（默认关闭）；请先输入文本');
      return;
    }
    _textCtrl.text = text;
    await _extract();
  }

  Future<void> _extract() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final candidate = const VoiceRuleEngine().extract(text);
    if (candidate == null) {
      setState(() => _hint = '无法从文本中识别金额与收支方向');
      return;
    }
    if (!mounted) return;
    await CaptureConfirmPage.show(
      context,
      candidates: [candidate],
      categoryNameFor: (c) => c.categoryName,
      source: 'voice',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('语音记账')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textCtrl,
              decoration: const InputDecoration(
                labelText: '语音转文字结果 / 手动输入',
                hintText: '例如：昨天午餐 打车花了25元',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            AppButton.primary(
              onPressed: _recognize,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic, size: 18),
                  SizedBox(width: 8),
                  Text('语音识别'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AppButton.secondary(
              onPressed: _extract,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 18),
                  SizedBox(width: 8),
                  Text('提取并确认'),
                ],
              ),
            ),
            if (_hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_hint!),
              ),
          ],
        ),
      ),
    );
  }
}
