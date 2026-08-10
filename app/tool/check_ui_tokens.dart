// UI 重构静态卡点（BK-UI-011 / Spec §9 静态层）：
// features/ 下禁止裸色值 `Color(0x…)` 与裸字号 `fontSize:`，颜色/字号一律走
// Design Token（palette / TextTheme / AppAmountText）。
//
// 用法：dart run tool/check_ui_tokens.dart（CI 卡点；退出码非 0 即失败）
//
// 白名单制：确需例外的位置在 _whitelist 中登记「文件:行号 + 理由」，
// 行号漂移即失效，倒逼及时整改。

import 'dart:io';

final _rules = <(RegExp, String)>[
  (RegExp(r'Color\(0x[0-9a-fA-F]+\)'), '裸色值 Color(0x…) → 改用 context.palette / appColors'),
  (RegExp(r'fontSize\s*:'), '裸字号 fontSize: → 改用 TextTheme 字阶 / AppAmountText'),
];

/// 白名单（相对 lib/ 的路径前缀 : 行内特征子串 → 理由）
final _whitelist = <String, String>{
  // 示例：'reports/xx.dart:Color(0xFF000000)': '遮罩基色，主题无关',
};

int main() {
  final featuresDir = Directory('lib/features');
  if (!featuresDir.existsSync()) {
    stderr.writeln('未找到 lib/features（请在 app/ 根目录运行）');
    return 2;
  }
  var violations = 0;
  for (final entity in featuresDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relPath = entity.path.replaceAll('\\', '/').replaceFirst('lib/', '');
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final (pattern, advice) in _rules) {
        if (!pattern.hasMatch(line)) continue;
        final whitelisted = _whitelist.keys.any((key) {
          final sep = key.indexOf(':');
          if (sep <= 0) return false;
          return relPath.startsWith(key.substring(0, sep)) &&
              line.contains(key.substring(sep + 1));
        });
        if (whitelisted) continue;
        violations++;
        stderr.writeln('✗ $relPath:${i + 1}: $advice\n    ${line.trim()}');
      }
    }
  }
  if (violations > 0) {
    stderr.writeln('\n共 $violations 处裸值违规（features/ 禁 Color(0x…/fontSize:）');
    return 1;
  }
  stdout.writeln('✓ features/ 无裸色值/裸字号残留');
  return 0;
}
