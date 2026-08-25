// UI 重构静态卡点（BK-UI-011 / Spec §9 静态层，审核 F5/A1 升级）：
// 全 lib/ 下禁止裸色值 `Color(0x…)`、8 位 ARGB 字面量 `0x????????` 与裸字号
// `fontSize:`，颜色/字号一律走 Design Token（palette / TextTheme /
// AppAmountText）。范围由 lib/features 扩至全 lib/，并新增 8 位 ARGB 字面量
// 规则，封堵「常量列表绕过 Color(0x…) 包裹」的缺口（如 `_palette = [0xFF...]`）。
//
// 用法：dart run tool/check_ui_tokens.dart（CI 卡点；退出码非 0 即失败）
//
// 白名单制：确需例外的位置在 _whitelist 中登记「路径前缀:行内特征子串 + 理由」，
// 行号漂移不失效（按行内容匹配），倒逼及时整改。

import 'dart:io';

final _rules = <(RegExp, String)>[
  (RegExp(r'Color\(0x[0-9a-fA-F]+\)'), '裸色值 Color(0x…) → 改用 context.palette / appColors'),
  // 8 位 ARGB 字面量（精准命中颜色常量；不误伤 0x2D 类短 hex 与字节数组）
  (RegExp(r'0x[0-9A-Fa-f]{8}\b'), 'ARGB 字面量 → 改用 palette/语义色'),
  (RegExp(r'fontSize\s*:'), '裸字号 fontSize: → 改用 TextTheme 字阶 / AppAmountText'),
];

/// 白名单（相对 lib/ 的路径前缀 : 行内特征子串 → 理由）。
/// 审核 F5/A1：Token/主题定义文件豁免（设计文档 §6.4）；功能必需色与
/// 业务数据色逐条登记并注明理由，新增零容忍。
final _whitelist = <String, String>{
  // —— Token/主题定义文件（设计文档 §6.4 豁免语义：色值/字号的唯一定义处）——
  'shared/theme/glass_tokens.dart:Color(0x': 'FGDS 唯一参数源（Spec §2/§3/§5 全部玻璃/文字/语义色 Token，BK-FG-001）',
  'shared/theme/theme_presets.dart:Color(0x': '8 套预制主题品牌主色与中性槽位 Token（BK-FG-032 收敛后仅主题色差异）',
  'shared/theme/theme_presets.dart:0xFF': '同上：主色/容器色字面量',
  'shared/theme/app_theme.dart:Color(0xFF': 'custom 种子色路径中性槽位与语义色定义（Token 层）',
  'shared/theme/tokens.dart:fontSize:': '七级字阶 Token 定义（Token 层）',
  'shared/theme/theme_settings.dart:Color(0xFF': 'kThemePresets 自定义色板定义（Token 层）',
  // —— 功能必需 / 业务数据色（非 UI 装饰）——
  'shared/theme/color_picker_dialog.dart:Color(0xFF': 'HSV 取色器 hue 色带 7 色（取色功能必需）',
  'features/categories/category_edit_sheet.dart:0xFF': '分类业务可选色域 _palette（用户数据色）',
  'features/sync/sync_merger.dart:0xFF607D8B': '同步分类颜色默认值（业务数据色）',
  'data/repositories/settings_repository.dart:0xFF000000': '旧键 hex 解析拼装不透明 alpha（数据解析层）',
};

int main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('未找到 lib/（请在 app/ 根目录运行）');
    return 2;
  }
  var violations = 0;
  for (final entity in libDir.listSync(recursive: true)) {
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
    stderr.writeln('\n共 $violations 处裸值违规（lib/ 禁 Color(0x…/ARGB 字面量/fontSize:）');
    // 注意：Dart 3.12+ 不再将 main 的返回值映射为进程退出码，
    // 必须显式 exit(1) 才能让 CI 卡点真正生效（审核 F5/A1）
    exit(1);
  }
  stdout.writeln('✓ lib/ 无裸色值/ARGB 字面量/裸字号残留');
  return 0;
}
