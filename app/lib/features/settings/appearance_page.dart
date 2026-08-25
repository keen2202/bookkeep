import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/glass_prefs.dart';
import '../../shared/theme/glass_tokens.dart';
import '../../shared/widgets/glass_icon.dart';
import '../../shared/theme/color_picker_dialog.dart';
import '../../shared/theme/theme_controller.dart';
import '../../shared/theme/theme_presets.dart';
import '../../shared/theme/theme_settings.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/glass_nav.dart';

/// "外观"设置页（FGDS v1.0 收敛版）：
/// 主题方案（8 套预制网格 + 自定义入口）/ 图标风格 / 玻璃质感（磨砂
/// 降级开关，fill α+0.10 补偿）。
///
/// 旧「个性背景」（背景图/遮罩/模糊）与「环境光」（光斑动效/强度/钳制）
/// 已随旧系统拆除——纯净背景为 Spec §2.2 硬约束、禁止背景图与光斑
/// （设计文档 §3，AC-02）。
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeControllerProvider);

    return GlassScaffold(
      title: const Text('外观'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _SectionTitle('主题方案'),
          _ThemePresetGrid(current: themeSettings),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle('图标风格'),
          _IconPackSection(current: themeSettings),
          const SizedBox(height: AppSpacing.lg),
          // FGDS：玻璃质感唯一可调项——低性能磨砂降级（BK-FG-003）
          const _SectionTitle('玻璃质感'),
          const _GlassBlurSection(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(title, style: context.text.titleSmall),
      );
}

// ---------------------------------------------------------------------------
// 主题方案：8 套预制卡片网格 + 第 9 格"自定义"
// ---------------------------------------------------------------------------
class _ThemePresetGrid extends ConsumerWidget {
  const _ThemePresetGrid({required this.current});

  final ThemeSettings current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(themeControllerProvider.notifier);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.6,
      children: [
        for (final preset in kThemePresetsV2)
          _PresetCard(
            preset: preset,
            selected: current.presetId == preset.id,
            onTap: () => controller.applyPreset(preset.id),
          ),
        _CustomCard(
          selected: current.isCustom,
          onTap: () => _openCustomSheet(context, ref),
        ),
      ],
    );
  }

  /// 自定义种子色流程（保留旧能力）：种子色色板 + 取色器 + 外观模式
  Future<void> _openCustomSheet(BuildContext context, WidgetRef ref) async {
    final currentSettings = ref.read(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    await showAppSheet(
      context,
      title: '自定义主题',
      child: _CustomThemeSheet(
        current: currentSettings,
        onApply: (seed, mode) => controller.applyCustomSeed(seed, mode),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AppThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = preset.palette;
    final colors = context.appColors;
    return AppCard(
      padded: false,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardAll,
          // 选中态：primary 外环（FG-SEL 描边语义的简化预览形态）
          border: selected
              ? Border.all(color: context.palette.primary, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 色板缩略预览：纯净底色（Spec §2.2 白名单底色）+ G2 玻璃面板示意
            Container(
              height: 40,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: p.background,
                borderRadius: AppRadius.smAll,
                border: Border.all(color: p.border, width: 0.5),
              ),
              child: Row(
                children: [
                  // G2 白玻璃示意（fill 取层级表浅/深值）
                  Container(
                    width: 32,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: p.isDark
                            ? GlassLevel.g2.fillAlphaDark
                            : GlassLevel.g2.fillAlphaLight,
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                      border: Border.all(
                        color: p.isDark ? Colors.white.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.06),
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: p.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Container(width: 3, height: 3, color: colors.income),
                        const SizedBox(width: 2),
                        Container(width: 3, height: 3, color: colors.expense),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 22,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.textPrimary,
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    preset.name,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, size: 16, color: context.palette.primary),
              ],
            ),
            Text(preset.styleTag, style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CustomCard extends StatelessWidget {
  const _CustomCard({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padded: false,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardAll,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 2 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.palette : Icons.palette_outlined,
              color: selected ? palette.primary : palette.textSecondary,
              size: 28,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('自定义', style: context.text.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// 自定义主题弹层：种子色色板 + 取色器 + 外观模式
class _CustomThemeSheet extends StatefulWidget {
  const _CustomThemeSheet({required this.current, required this.onApply});

  final ThemeSettings current;
  final void Function(Color seed, ThemeMode mode) onApply;

  @override
  State<_CustomThemeSheet> createState() => _CustomThemeSheetState();
}

class _CustomThemeSheetState extends State<_CustomThemeSheet> {
  late Color _seed = widget.current.seedColor;
  late ThemeMode _mode = widget.current.mode;

  void _apply() {
    widget.onApply(_seed, _mode);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('外观模式', style: context.text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
            ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
            ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('主题颜色', style: context.text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final color in kThemePresets)
              _SeedDot(
                color: color,
                selected: color.toARGB32() == _seed.toARGB32(),
                onTap: () => setState(() => _seed = color),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton.secondary(
          onPressed: () async {
            final picked = await ColorPickerDialog.show(context, initial: _seed);
            if (picked != null && mounted) setState(() => _seed = picked);
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.colorize, size: 18),
              SizedBox(width: AppSpacing.xs),
              Text('自定义颜色'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton.primary(
          onPressed: _apply,
          child: const Text('应用'),
        ),
      ],
    );
  }
}

class _SeedDot extends StatelessWidget {
  const _SeedDot({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final checkColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
              : null,
        ),
        child: selected ? Icon(Icons.check, size: 20, color: checkColor) : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 图标风格（现有能力迁移保留）
// ---------------------------------------------------------------------------
class _IconPackSection extends ConsumerWidget {
  const _IconPackSection({required this.current});

  final ThemeSettings current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(themeControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<IconPack>(
          segments: [
            for (final pack in IconPack.values)
              ButtonSegment(value: pack, label: Text(pack.label)),
          ],
          selected: {current.iconPack},
          onSelectionChanged: (s) => controller.setIconPack(s.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        // 模块图标预览（账单/分类/周期记账/报表/日历）：36 档 FG-ICON 容器
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final module in AppModule.values)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassIcon(icon: moduleIcon(module, current.iconPack)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(module.label, style: context.text.labelSmall),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 玻璃质感（BK-FG-003）：唯一可调项——磨砂降级开关（fill α +0.10 补偿）
// ---------------------------------------------------------------------------
class _GlassBlurSection extends ConsumerWidget {
  const _GlassBlurSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(glassPrefsProvider);
    final controller = ref.read(glassPrefsProvider.notifier);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('真实磨砂'),
      subtitle: Text(
        prefs.blurEnabled
            ? '容器级组件实时模糊背景（同屏 ≤20 处）；关闭后以填充加粗补偿'
            : '已关闭：玻璃改为半透明填充（α +${(kBlurDegradeFillCompensation * 100).round()}% 补偿），低端机更流畅',
        style: context.text.bodySmall,
      ),
      value: prefs.blurEnabled,
      onChanged: (v) => controller.setBlurEnabled(v),
    );
  }
}
