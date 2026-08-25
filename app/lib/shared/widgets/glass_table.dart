import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/glass_tokens.dart';
import '../theme/tokens.dart';
import 'glass_panel.dart';
import 'glass_selection.dart';

/// FG-TBL 列定义
class GlassTableColumn {
  const GlassTableColumn({
    required this.label,
    this.align = Alignment.centerLeft,
    this.flex = 1,
  });

  final String label;
  final Alignment align;

  /// 列宽弹性权重（Expanded flex）
  final int flex;
}

/// FG-TBL 行数据
class GlassTableRow {
  const GlassTableRow({required this.cells, this.selected = false, this.onTap});

  /// 与 [GlassTable.columns] 一一对应的单元格内容（文字型符号可豁免容器，
  /// Spec §4.1 豁免行）
  final List<Widget> cells;

  /// 行选中态：套 FG-SEL 四层全量（Spec §4.3 行选中行）
  final bool selected;

  final VoidCallback? onTap;
}

/// FG-TBL 玻璃表格（Spec §4.3 / 设计文档 §5.3；BK-FG-020）：
///
/// - 容器：GlassPanel G2 全参数（σ20、fill 0.60/0.12、R16、双层描边、
///   环境投影）——全表唯一 BackdropFilter，行级零模糊（设计文档 §4.3、AC-06）；
/// - 表头：G3 档填充与描边值（fill 0.72/0.18），底部 0.5px 分隔线；
///   文字 `text.secondary` 加粗 600；
/// - 斑马纹：奇数行 fill α0.45/0.10、偶数行 α0.30/0.06——纯透明度区分，
///   差值固定 0.15/0.04，禁套 BackdropFilter；
/// - 行 hover：该行 fill α +0.10/+0.04，150ms 过渡；
/// - 行分隔线：0.5px，左右内缩 16px（iOS 列表惯例）；
/// - 单元格：无独立背景，padding 垂直 12 / 水平 16。
class GlassTable extends StatefulWidget {
  const GlassTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  final List<GlassTableColumn> columns;
  final List<GlassTableRow> rows;

  @override
  State<GlassTable> createState() => _GlassTableState();
}

class _GlassTableState extends State<GlassTable> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final dark = context.tokens.isDark;

    return GlassPanel(
      level: GlassLevel.g2,
      borderRadius: AppRadius.cardAll,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.cardAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context),
            for (var i = 0; i < widget.rows.length; i++) ...[
              if (i > 0)
                // 行分隔线：0.5px 发丝线，左右内缩 16px
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: dark
                        ? Colors.white
                            .withValues(alpha: GlassTableTokens.rowDividerAlphaDark)
                        : Colors.black
                            .withValues(alpha: GlassTableTokens.rowDividerAlphaLight),
                  ),
                ),
              _row(context, i, widget.rows[i]),
            ],
          ],
        ),
      ),
    );
  }

  /// 表头：G3 档填充与描边（不新增 BackdropFilter——透明感来自 G2 容器整体模糊）
  Widget _header(BuildContext context) {
    final dark = context.tokens.isDark;
    final g3Fill = resolveGlassSpec(
        level: GlassLevel.g3, brightness: context.tokens.brightness);
    return Container(
      decoration: BoxDecoration(
        color: g3Fill.fill,
        border: Border(
          bottom: BorderSide(
            color: dark
                ? Colors.white
                    .withValues(alpha: GlassTableTokens.headerDividerAlphaDark)
                : Colors.black
                    .withValues(alpha: GlassTableTokens.headerDividerAlphaLight),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm + 2, horizontal: AppSpacing.md),
      child: Row(
        children: [
          for (final column in widget.columns)
            Expanded(
              flex: column.flex,
              child: Align(
                alignment: column.align,
                child: Text(
                  column.label,
                  // 表头文字 text.secondary 加粗 600（13/600）
                  style: context.text.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int index, GlassTableRow row) {
    final dark = context.tokens.isDark;

    // 斑马纹基线：奇数行 0.45/0.10、偶数行 0.30/0.06（纯透明度区分）
    final isOdd = index.isOdd;
    var alpha = isOdd
        ? (dark ? GlassTableTokens.zebraOddFillDark : GlassTableTokens.zebraOddFillLight)
        : (dark ? GlassTableTokens.zebraEvenFillDark : GlassTableTokens.zebraEvenFillLight);
    // 行 hover：fill α +0.10/+0.04（150ms 过渡由 AnimatedContainer 承载）
    if (_hoverIndex == index) {
      alpha = (alpha + (dark ? GlassTableTokens.hoverDeltaDark : GlassTableTokens.hoverDeltaLight))
          .clamp(0.0, 1.0);
    }

    final rowFill =
        Colors.white.withValues(alpha: alpha);

    Widget content = AnimatedContainer(
      duration: GlassMotion.micro,
      curve: GlassMotion.curve,
      color: rowFill,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm + 4, horizontal: AppSpacing.md),
      child: Row(
        children: [
          for (var c = 0; c < widget.columns.length && c < row.cells.length; c++)
            Expanded(
              flex: widget.columns[c].flex,
              child: Align(
                alignment: widget.columns[c].align,
                child: DefaultTextStyle.merge(
                  style: context.text.bodyLarge,
                  child: row.cells[c],
                ),
              ),
            ),
        ],
      ),
    );

    // 行交互：hover 提亮 + 可点；选中行走 FG-SEL 四层全量
    content = MouseRegion(
      onEnter: (_) => setState(() => _hoverIndex = index),
      onExit: (_) => setState(() => _hoverIndex = null),
      cursor: row.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: row.onTap,
        child: GlassSelection(
          selected: row.selected,
          hostFillAlpha: alpha,
          borderRadius: BorderRadius.zero,
          child: content,
        ),
      ),
    );
    return content;
  }
}
