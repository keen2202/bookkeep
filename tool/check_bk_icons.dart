// BK-ICON 裸 Icons 扫描（BK-DOC-34 AC-01 / BK-IC-042）。
//
// 扫描 app/lib 下 `Icons.` 引用，白名单外全部报错。
// 首页路径零容忍：receipt_long_outlined / bar_chart_outlined。
//
// 用法（仓库根）：dart run tool/check_bk_icons.dart
// 白名单：tool/bk_icons_allowlist.txt（每行一个文件名）

import 'dart:io';

/// 首页零容忍图标（正式路径禁止出现）
const zeroTolerance = [
  'Icons.receipt_long_outlined',
  'Icons.bar_chart_outlined',
];

/// 过渡期白名单（分类库 P2 迁移前；BK-IC-044 收紧）
const defaultAllowPatterns = [
  'category_icon.dart',
  'component_gallery_page.dart',
  // 非核心链路图标，P1 门禁后逐步清空
  'app.dart',
  'accounts_page.dart',
  'account_card.dart',
  'account_sync_section.dart',
  'appearance_page.dart',
  'backup_page.dart',
  'bill_detail_sheet.dart',
  'books_page.dart',
  'book_switcher.dart',
  'budget_manage_sheet.dart',
  'budget_summary_card.dart',
  'calendar_page.dart',
  'capture_confirm_page.dart',
  'categories_page.dart',
  'category_edit_sheet.dart',
  'category_picker.dart',
  'csv_import_page.dart',
  'currency_manage_page.dart',
  'lock_settings.dart',
  'member_manager.dart',
  'pin_pad.dart',
  'quick_entry_sheet.dart',
  'recurring_page.dart',
  'share_invite_sheet.dart',
  'app_snack.dart',
];

void main() {
  final originalCwd = Directory.current.path;
  var libDir = Directory('lib');
  if (!libDir.existsSync()) {
    final alt = Directory(p('app/lib'));
    if (alt.existsSync()) {
      Directory.current = p('app');
      libDir = Directory('lib');
    } else {
      stderr.writeln('未找到 lib/ 目录');
      exit(2);
    }
  }

  final allow = <String>{...defaultAllowPatterns};
  for (final candidate in [
    p(originalCwd, 'tool/bk_icons_allowlist.txt'),
    p(originalCwd, 'bk_icons_allowlist.txt'),
    '../tool/bk_icons_allowlist.txt',
    'tool/bk_icons_allowlist.txt',
  ]) {
    final f = File(candidate);
    if (!f.existsSync()) continue;
    for (final line in f.readAsLinesSync()) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      allow.add(t);
    }
    break;
  }

  final issues = <String>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    final rel = file.path.replaceAll('\\', '/');
    final fileName = rel.split('/').last;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('//')) continue;
      for (final m
          in RegExp(r'(?<![A-Za-z0-9_])Icons\.[A-Za-z0-9_]+').allMatches(line)) {
        final icon = m.group(0)!;
        final loc = '$rel:${i + 1}';
        // 白名单文件整体豁免（含零容忍图标——组件画廊仅作对比演示）
        if (allow.contains(fileName) || allow.contains(rel)) continue;
        if (zeroTolerance.contains(icon)) {
          issues.add('$loc  零容忍图标 $icon');
          continue;
        }
        issues.add('$loc  $icon');
      }
    }
  }

  stdout.writeln('== BK-ICON 裸 Icons 扫描（AC-01）==');
  if (issues.isEmpty) {
    stdout.writeln('PASS  无白名单外 Icons.* 引用');
    exit(0);
  }
  for (final issue in issues) {
    stdout.writeln('FAIL  $issue');
  }
  stdout.writeln('共 ${issues.length} 处待收敛');
  exit(1);
}

/// 简易 path join（避免引入 path 包）
String p(String a, [String? b]) {
  if (b == null || b.isEmpty) return a;
  if (a.endsWith('/') || a.endsWith('\\')) return '$a$b';
  return '$a${Platform.pathSeparator}$b';
}
