import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/chart_colors.dart';
import '../../shared/theme/glass_tokens.dart';
import '../../shared/theme/theme_presets.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/app_amount_text.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_empty.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/app_snack.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/glass_icon.dart';
import '../../shared/widgets/glass_panel.dart';
import '../../shared/widgets/glass_selection.dart';
import '../../shared/widgets/glass_table.dart';
import '../../shared/widgets/glass_nav.dart';

/// 组件 Gallery 样板间（延续 BK-UI-008）：全组件 × 8 主题切换预览，
/// 供设计走查（不影响全局主题设置）。FGDS v1.0：展区对齐 Spec §4 组件
/// 规格——玻璃层级 G1–G5、FG-ICON、FG-SEL、FG-TBL、FG-BTN 状态矩阵。
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  AppThemePreset _preset = kThemePresetsV2.first;
  bool _selected = true;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(_preset),
      child: Builder(
        builder: (themedContext) => GlassScaffold(
          title: const Text('组件样板间'),
          body: ListView(
            padding: AppSpacing.pagePadding,
            children: [
              // 8 主题切换
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final p in kThemePresetsV2)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: _preset.id == p.id,
                      onSelected: (_) => setState(() => _preset = p),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // ── 展区①：玻璃层级（Spec §3 参数表，G1–G5 同屏 + 参数标注）──
              _Section(
                title: '玻璃层级 G1–G5（同屏对比）',
                child: Column(
                  children: [
                    for (final level in GlassLevel.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: GlassPanel(
                          level: level,
                          borderRadius:
                              BorderRadius.circular(defaultRadius(level) == 0
                                  ? AppRadius.md
                                  : defaultRadius(level)),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _levelLabel(level),
                                  style: themedContext.text.titleSmall,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  'σ${level.blur.round()} · '
                                  'fill ${(resolveGlassSpec(level: level, brightness: themedContext.tokens.brightness).fill.a * 100).round()}%',
                                  style: themedContext.text.bodySmall?.copyWith(
                                    color: themedContext.palette.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ── 展区②：FG-ICON 图标容器（28/36/44 三档 + tint 变体）──
              _Section(
                title: 'GlassIcon 图标容器（28 / 36 / 44 · tint 变体）',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const GlassIcon(icon: Icons.home_outlined, size: GlassIconSize.s28),
                    const GlassIcon(icon: Icons.receipt_long_outlined, size: GlassIconSize.s36),
                    const GlassIcon(icon: Icons.add_circle_outline, size: GlassIconSize.s44),
                    const GlassIcon(
                        icon: Icons.category_outlined,
                        size: GlassIconSize.s44,
                        tint: true),
                  ],
                ),
              ),
              // ── 展区③：FG-SEL 选中态四层叠加 ──
              _Section(
                title: 'GlassSelection 选中态（FG-SEL 四层叠加，200ms 过渡）',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('选中态开关'),
                      value: _selected,
                      onChanged: (v) => setState(() => _selected = v),
                    ),
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: ClipRRect(
                          borderRadius: AppRadius.smAll,
                          child: GlassSelection(
                            selected: _selected && i == 0,
                            borderRadius: AppRadius.smAll,
                            child: Container(
                              color: resolveGlassSpec(
                                      level: GlassLevel.g2,
                                      brightness: themedContext.tokens.brightness)
                                  .fill,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Text('列表项 ${i + 1}',
                                  style: themedContext.text.bodyLarge),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ── 展区④：交互状态矩阵 ──
              _Section(
                title: '交互状态矩阵（Spec §4.4 五态）',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppButton.primary(onPressed: () {}, child: const Text('主按钮')),
                        AppButton.secondary(onPressed: () {}, child: const Text('hover 悬停试试')),
                        AppButton.danger(onPressed: () {}, child: const Text('危险按钮')),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Tab 键聚焦：primary α0.50 外环；按压 scale 0.98',
                        style: themedContext.text.bodySmall?.copyWith(
                          color: themedContext.palette.textSecondary,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: 'AppButton 按钮',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton.primary(onPressed: () {}, child: const Text('主按钮')),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton.secondary(onPressed: () {}, child: const Text('次按钮')),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton.danger(onPressed: () {}, child: const Text('危险按钮')),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton.text(onPressed: () {}, child: const Text('文字按钮')),
                    const SizedBox(height: AppSpacing.sm),
                    const AppButton.primary(loading: true, child: Text('加载中')),
                    const SizedBox(height: AppSpacing.sm),
                    const AppButton.primary(onPressed: null, child: Text('禁用态')),
                  ],
                ),
              ),
              _Section(
                title: 'AppCard 卡片与嵌套升档',
                child: Column(
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('静态卡片（G2）', style: themedContext.text.bodyLarge),
                          const SizedBox(height: AppSpacing.sm),
                          // 嵌套演示：内层下一档填充值、零新增 BackdropFilter
                          GlassPanel.nested(
                            host: GlassLevel.g2,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Text('嵌套分组容器（G3 填充值 · 无二次模糊）',
                                style: themedContext.text.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      onTap: () {},
                      child: Row(
                        children: [
                          Icon(Icons.touch_app_outlined,
                              color: themedContext.palette.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text('可点卡片（pressed fill+scale 反馈）',
                              style: themedContext.text.bodyLarge),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── 展区⑤：FG-TBL 表格 ──
              _Section(
                title: 'GlassTable 表格（斑马纹零模糊 · 行选中 FG-SEL）',
                child: GlassTable(
                  columns: const [
                    GlassTableColumn(label: '分类'),
                    GlassTableColumn(
                        label: '金额', align: Alignment.centerRight),
                  ],
                  rows: [
                    for (var i = 0; i < 4; i++)
                      GlassTableRow(
                        selected: i == 1,
                        cells: [
                          Text('示例分类 ${i + 1}'),
                          AppAmountText.minor((i + 1) * -12345),
                        ],
                      ),
                  ],
                ),
              ),
              _Section(
                title: 'AppTextField 输入框',
                child: const Column(
                  children: [
                    AppTextField(label: '标准输入框', hint: '请输入内容'),
                    SizedBox(height: AppSpacing.sm),
                    AppTextField(label: '错误态', error: '输入不合法，请重新输入'),
                  ],
                ),
              ),
              _Section(
                title: 'AppAmountText 金额',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAmountText.minor(123456, large: true),
                    const SizedBox(height: AppSpacing.sm),
                    AppAmountText.minor(-8899),
                    AppAmountText.minor(8899),
                    const AppAmountText('¥0.00'),
                  ],
                ),
              ),
              _Section(
                title: 'AppSheet / AppDialog / AppSnack',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppButton.secondary(
                      onPressed: () => showAppSheet<void>(
                        themedContext,
                        title: '底部弹层',
                        child: Text('G4 玻璃 · 顶部圆角 20 · 遮罩 α0.32。',
                            style: themedContext.text.bodyLarge),
                      ),
                      child: const Text('底部弹层'),
                    ),
                    AppButton.secondary(
                      onPressed: () => showAppConfirm(
                        themedContext,
                        title: '普通对话框',
                        content: 'G4 玻璃面板 + scrim 遮罩 α0.32。',
                      ),
                      child: const Text('对话框'),
                    ),
                    AppButton.secondary(
                      onPressed: () => showAppConfirm(
                        themedContext,
                        title: '危险确认',
                        content: '危险操作确认键为 danger 着色玻璃。',
                        danger: true,
                        confirmText: '删除',
                      ),
                      child: const Text('危险对话框'),
                    ),
                    AppButton.secondary(
                      onPressed: () => AppSnack.success(themedContext, '操作成功'),
                      child: const Text('成功提示'),
                    ),
                    AppButton.secondary(
                      onPressed: () => AppSnack.error(themedContext, '操作失败'),
                      child: const Text('失败提示'),
                    ),
                    AppButton.secondary(
                      onPressed: () => AppSnack.info(themedContext, '信息提示'),
                      child: const Text('信息提示'),
                    ),
                  ],
                ),
              ),
              _Section(
                title: 'AppEmpty 空态',
                child: AppCard(
                  child: SizedBox(
                    height: 260,
                    child: AppEmpty(
                      icon: Icons.receipt_long_outlined,
                      title: '暂无账单',
                      message: '点击右下角 + 记一笔',
                      actionLabel: '记一笔',
                      onAction: () {},
                    ),
                  ),
                ),
              ),
              _Section(
                title: '图表序列色（主色系派生）',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final c in chartSeriesColors(themedContext))
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: AppRadius.smAll,
                          border: Border.all(color: themedContext.palette.border),
                        ),
                      ),
                  ],
                ),
              ),
              _Section(
                title: '字阶',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('大标题 28 大数字 ¥1,234.56',
                        style: themedContext.tokens.displayAmountStyle),
                    Text('headline 22 页面主标题',
                        style: themedContext.text.headlineSmall),
                    Text('title 17 卡片标题/列表主文案',
                        style: themedContext.text.titleLarge),
                    Text('body 15 正文内容', style: themedContext.text.bodyLarge),
                    Text('bodySmall 13 辅助说明',
                        style: themedContext.text.bodyMedium),
                    Text('caption 12 时间戳/标签',
                        style: themedContext.text.bodySmall),
                    Text('amount 20 等宽金额 ¥8,888.00',
                        style: themedContext.tokens.amountStyle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

String _levelLabel(GlassLevel level) => switch (level) {
      GlassLevel.g1 => 'G1 图标容器层',
      GlassLevel.g2 => 'G2 内容面板层 · 卡片/表格容器',
      GlassLevel.g3 => 'G3 吸附层 · AppBar/底部导航/表头',
      GlassLevel.g4 => 'G4 浮层 · 对话框/弹层/菜单',
      GlassLevel.g5 => 'G5 轻提示 · Toast/FAB',
    };
