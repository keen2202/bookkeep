import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/chart_colors.dart';
import '../../shared/theme/glass/glass_layers.dart';
import '../../shared/theme/glass/glass_panel.dart';
import '../../shared/theme/glass/glass_quality.dart' as gq;
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

/// 组件 Gallery 样板间（BK-UI-008，设计文档 §6.3）：
/// 全组件 × 8 主题切换预览，供设计走查（不影响全局主题设置）。
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  AppThemePreset _preset = kThemePresetsV2.first;
  // 样板间独立画质预览（不影响全局设置）
  gq.GlassQuality _quality = gq.GlassQuality.standard;
  Offset _demoPulse = Offset.zero;
  bool _probeSolidLine = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(_preset, quality: _quality),
      child: Builder(
        builder: (themedContext) => Scaffold(
          appBar: AppBar(title: const Text('组件样板间')),
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
              const SizedBox(height: AppSpacing.sm),
              // 画质档切换（样板间局部预览，GLS-015）
              SegmentedButton<gq.GlassQuality>(
                segments: [
                  for (final q in gq.GlassQuality.values)
                    ButtonSegment(value: q, label: Text(q.label)),
                ],
                selected: {_quality},
                onSelectionChanged: (s) => setState(() => _quality = s.first),
              ),
              const SizedBox(height: AppSpacing.lg),
              // ── v3 新增展区①：玻璃层级（L1–L4 同屏 + 参数标注）──
              _Section(
                title: '玻璃层级 L1–L4（同屏对比）',
                child: Column(
                  children: [
                    for (final tier in GlassTier.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: GlassPanel(
                          tier: tier,
                          borderRadius:
                              BorderRadius.circular(tier == GlassTier.overlay ? AppRadius.lg : AppRadius.md),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _tierLabel(tier),
                                  style: themedContext.text.titleSmall,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  'σ${_sigmaLabel(themedContext, tier)} · '
                                  'fill ${(resolveGlassSpec(tier: tier, brightness: themedContext.tokens.brightness, palette: themedContext.palette, quality: _quality).fill.a * 100).round()}%'
                                  ' · border ${(resolveGlassSpec(tier: tier, brightness: themedContext.tokens.brightness, palette: themedContext.palette, quality: _quality).borderColor.a * 100).round()}%',
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
              // ── 展区②：交互状态矩阵（hover/focus/press）──
              _Section(
                title: '交互状态矩阵',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppButton.primary(onPressed: () {}, child: const Text('hover 悬停试试')),
                        AppButton.glass(onPressed: () {}, child: const Text('glass 变体')),
                        AppButton.danger(onPressed: () {}, child: const Text('danger 玻璃')),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Tab 键聚焦：primary 2px 外环 + α0.18 光晕；按压 96% 缩放',
                        style: themedContext.text.bodySmall?.copyWith(
                          color: themedContext.palette.textSecondary,
                        )),
                    const SizedBox(height: AppSpacing.sm),
                    const AppTextField(label: 'focus 光晕', hint: '聚焦查看 primary 光晕'),
                  ],
                ),
              ),
              // ── 展区③：环境光演示（脉冲触发/暂停）──
              _Section(
                title: '环境光演示',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppButton.secondary(
                          onPressed: () =>
                              setState(() => _demoPulse = const Offset(0, -1)),
                          child: const Text('模拟 push 脉冲'),
                        ),
                        AppButton.secondary(
                          onPressed: () =>
                              setState(() => _demoPulse = const Offset(0, 1)),
                          child: const Text('模拟 pop 脉冲'),
                        ),
                        AppButton.text(
                          onPressed: () => setState(() => _demoPulse = Offset.zero),
                          child: const Text('归位'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: AppRadius.mdAll,
                      child: SizedBox(
                        height: 120,
                        child: CustomPaint(
                          painter: _GalleryAmbientPainter(
                            palette: themedContext.palette,
                            pulse: _demoPulse,
                          ),
                          child: Center(
                            child: Text(
                              '光斑位移演示：${_demoPulse == Offset.zero ? '静止' : _demoPulse.dy < 0 ? '向上 +3%' : '向下 +3%'}',
                              style: themedContext.text.bodyMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── 展区④：色带探针（黑底放大高光条，Spec §3.2 防线④）──
              _Section(
                title: '色带探针',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 80,
                      decoration: const BoxDecoration(color: Colors.black),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      alignment: Alignment.center,
                      child: Container(
                        height: 40,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.smAll,
                          gradient: _probeSolidLine
                              ? null
                              : LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: const Alignment(0, 0.45),
                                  colors: [
                                    Colors.white.withValues(alpha: 0.25),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                          color: _probeSolidLine ? Colors.black : null,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _probeSolidLine
                              ? 'solidLine：1px 实线 + 1px 半强线'
                              : 'gradient：顶部高光渐变（α_top 0.25）',
                          style: themedContext.text.bodySmall,
                        ),
                        AppButton.text(
                          onPressed: () => setState(
                              () => _probeSolidLine = !_probeSolidLine),
                          child: Text(_probeSolidLine ? '切渐变' : '切 solidLine'),
                        ),
                      ],
                    ),
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
                title: 'AppCard 卡片',
                child: Column(
                  children: [
                    AppCard(
                      child: Text('静态卡片', style: themedContext.text.bodyLarge),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      onTap: () {},
                      child: Row(
                        children: [
                          Icon(Icons.touch_app_outlined,
                              color: themedContext.palette.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text('可点卡片（水波纹 + 按压 4%）',
                              style: themedContext.text.bodyLarge),
                        ],
                      ),
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
                        child: Text('拖拽柄 32×4、圆角 lg、背板 scrim 54%、下滑关闭。',
                            style: themedContext.text.bodyLarge),
                      ),
                      child: const Text('底部弹层'),
                    ),
                    AppButton.secondary(
                      onPressed: () => showAppConfirm(
                        themedContext,
                        title: '普通对话框',
                        content: '标题 title + 内容 body + 按钮区右对齐。',
                      ),
                      child: const Text('对话框'),
                    ),
                    AppButton.secondary(
                      onPressed: () => showAppConfirm(
                        themedContext,
                        title: '危险确认',
                        content: '危险操作确认键为 danger 样式。',
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
                      onPressed: () => AppSnack.info(themedContext, '中性信息'),
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
                title: '图表序列色（palette 派生）',
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
                title: '字阶（七级）',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('displayAmount 34 大数字 ¥1,234.56',
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
                    Text('amount 17 等宽金额 ¥8,888.00',
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

String _tierLabel(GlassTier tier) => switch (tier) {
      GlassTier.panel => 'L1 内容面板 · 卡片/图表容器',
      GlassTier.dock => 'L2 吸附层 · 导航栏/吸顶栏',
      GlassTier.overlay => 'L3 浮层 · 弹窗/底部弹层',
      GlassTier.floating => 'L4 悬浮提示 · SnackBar/FAB',
    };

String _sigmaLabel(BuildContext context, GlassTier tier) {
  final spec = resolveGlassSpec(
    tier: tier,
    brightness: context.tokens.brightness,
    palette: context.palette,
    quality: context.tokens.glassQuality,
  );
  return spec.sigmaX == 0 ? '0(fill-only)' : spec.sigmaX.round().toString();
}

/// 展区③演示画笔：黑底上按 pulse 方向平移的软化光斑（非生产管线）
class _GalleryAmbientPainter extends CustomPainter {
  _GalleryAmbientPainter({required this.palette, required this.pulse});

  final ThemePalette palette;
  final Offset pulse;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);
    final colors = [
      ...palette.ambient.take(3),
      if (palette.ambient.length > 3) palette.ambient[3],
    ];
    final anchors = [
      const Alignment(-0.75, -0.85),
      const Alignment(0.95, -0.05),
      const Alignment(-0.15, 1.05),
      const Alignment(0.75, 0.85),
    ];
    for (var i = 0; i < anchors.length; i++) {
      var center = anchors[i].withinRect(Offset.zero & size);
      center += pulse * size.shortestSide;
      final rect = Rect.fromCenter(
        center: center,
        width: size.width * 0.7,
        height: size.height * 1.2,
      );
      final gradient = RadialGradient(
        colors: [
          colors[i % colors.length].withValues(alpha: 0.85),
          colors[i % colors.length].withValues(alpha: 0.38),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      );
      canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    }
  }

  @override
  bool shouldRepaint(_GalleryAmbientPainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.palette != palette;
}
