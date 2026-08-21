import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_icons.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/glass_icon.dart';
import '../../shared/theme/background/app_background.dart';
import '../../shared/theme/background/background_controller.dart';
import '../../shared/theme/background/background_settings.dart';
import '../../shared/theme/background/luminance.dart';
import '../../shared/theme/color_picker_dialog.dart';
import '../../shared/theme/theme_controller.dart';
import '../../shared/theme/theme_presets.dart';
import '../../shared/theme/theme_settings.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/app_snack.dart';

/// "外观"设置页（BK-UI-015，Spec §7）：
/// 主题方案（8 套预制网格 + 自定义入口）/ 图标风格 / 个性背景（开关/换图/
/// 遮罩模式滑杆 + 实时预览 + 对比度评级/模糊开关）。
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeControllerProvider);
    final background = ref.watch(backgroundControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _SectionTitle('主题方案'),
          _ThemePresetGrid(current: themeSettings),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle('图标风格'),
          _IconPackSection(current: themeSettings),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle('个性背景'),
          _BackgroundSection(
            settings: background ?? BackgroundSettings.defaults,
          ),
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

  /// 自定义种子色流程（保留旧能力，Spec D3）：种子色色板 + 取色器 + 外观模式
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
          borderRadius: AppRadius.mdAll,
          // 选中态：primary 2px 描边 + 右上角对勾
          border: selected
              ? Border.all(color: context.palette.primary, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 色板缩略预览：背景 + 表面卡片 + 主色/收支语义色示意
            Container(
              height: 40,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: p.background,
                borderRadius: AppRadius.smAll,
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 28,
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                      border: Border.all(color: p.border),
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
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 2 : 1,
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
        // 审核 F4：自定义颜色入口收敛至 AppButton.secondary（icon 并入 child Row）
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
// 图标风格（现有能力迁移保留，Spec D7）
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
        // 模块图标预览（账单/分类/周期记账/报表/日历）
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final module in AppModule.values)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassIcon(icon: moduleIcon(module, current.iconPack), size: 20),
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
// 个性背景（Spec §7）：预览 / 开关 / 换图与恢复 / 遮罩滑杆 + 评级 / 模糊
// ---------------------------------------------------------------------------
class _BackgroundSection extends ConsumerWidget {
  const _BackgroundSection({required this.settings});

  final BackgroundSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(backgroundControllerProvider.notifier);
    final imageL = ref.watch(backgroundLuminanceProvider).valueOrNull;
    final dark = context.tokens.isDark;
    final visuals = backgroundVisuals(
      settings: settings,
      imageL: imageL,
      palette: context.palette,
      dark: dark,
    );
    final imagePath = settings.imagePath;
    final hasImage = settings.enabled && imagePath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 实时预览（遮罩后有效底色 + 透明度读数；未选图态为可点击占位，
        // 点击等同「选择背景图片」，审核 F1）
        _BackgroundPreview(
          settings: settings,
          imageL: imageL,
          alpha: visuals.alpha,
          onPick: () => _pickAndApply(context, ref),
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('使用背景图片'),
          subtitle: Text(
            imagePath == null ? '请先选择一张相册图片' : '图片仅存本地，不同步不备份',
            style: context.text.bodySmall,
          ),
          value: settings.enabled,
          onChanged: imagePath == null
              ? null
              : (v) => controller.setEnabled(v),
        ),
        // 审核 F1/R2 三态主操作区：
        // ① 未选图（imagePath == null）：主按钮「选择背景图片」兜底首次选图
        //    入口（旧实现"更换图片"不渲染 + 开关禁用，功能死锁）；
        // ② 已选图：更换图片 + 恢复默认（现状不变）；开关可用
        if (imagePath == null) ...[
          const SizedBox(height: AppSpacing.xs),
          AppButton.primary(
            block: true,
            onPressed: () => _pickAndApply(context, ref),
            child: const Text('选择背景图片'),
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  child: const Text('更换图片'),
                  onPressed: () => _pickAndApply(context, ref),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton.text(
                  child: const Text('恢复默认'),
                  onPressed: () => controller.clear(),
                ),
              ),
            ],
          ),
        ],
        if (hasImage) ...[
          const SizedBox(height: AppSpacing.md),
          Text('遮罩', style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<OverlayMode>(
            segments: [
              for (final mode in OverlayMode.values)
                ButtonSegment(value: mode, label: Text(mode.label)),
            ],
            selected: {settings.overlayMode},
            onSelectionChanged: (s) =>
                controller.setOverlayMode(s.first),
          ),
          if (settings.overlayMode == OverlayMode.manual) ...[
            const SizedBox(height: AppSpacing.sm),
            _ManualAlphaSlider(settings: settings),
            const SizedBox(height: AppSpacing.xs),
            _ContrastRating(visuals: visuals),
          ] else ...[
            const SizedBox(height: AppSpacing.xs),
            Text('智能模式：按图片亮度自动调节，保证文字对比度',
                style: context.text.bodySmall),
          ],
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('背景模糊'),
            subtitle: Text('柔化背景细节，增强文字可读性（8px）',
                style: context.text.bodySmall),
            value: settings.blurEnabled,
            onChanged: (v) => controller.setBlur(v),
          ),
        ],
      ],
    );
  }

  Future<void> _pickAndApply(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(backgroundControllerProvider.notifier);
    final result = await controller.pickAndApply();
    if (!context.mounted) return;
    if (result.isSuccess) {
      AppSnack.success(context, '背景图片已应用');
    } else {
      AppSnack.error(context, result.message);
    }
  }
}

/// 遮罩后底色实时预览；未选图态渲染占位（surfaceVariant 底 + 图标 + 文案），
/// 点击等同「选择背景图片」（审核 F1）。渲染侧经 [backgroundImageFileProvider]
/// 消费绝对路径文件（审核 F2/R1，消除相对路径读取）。
class _BackgroundPreview extends ConsumerWidget {
  const _BackgroundPreview({
    required this.settings,
    required this.imageL,
    required this.alpha,
    required this.onPick,
  });

  final BackgroundSettings settings;
  final double? imageL;
  final double alpha;

  /// 未选图态点击（等同「选择背景图片」主按钮）
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final imageFile = ref.watch(backgroundImageFileProvider).valueOrNull;
    final imageRevision = ref.watch(backgroundRevisionProvider);
    final hasImage = imageFile != null;
    final effColor = hasImage
        ? Color.lerp(
            // 图（近似中灰占位）+ 主题底色按 α 混合（真实图在预览区直接渲染）
            Colors.white,
            palette.background,
            alpha,
          )!
        : palette.surfaceVariant;

    return ClipRRect(
      borderRadius: AppRadius.mdAll,
      child: GestureDetector(
        onTap: hasImage ? null : onPick,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: effColor,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: palette.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image(
                  image: ResizeImage(
                    RevisionFileImage(imageFile, revision: imageRevision),
                    width: 400,
                  ),
                  key: ValueKey('bg-preview-$imageRevision'),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              if (hasImage)
                ColoredBox(
                  color: palette.background.withValues(alpha: alpha),
                ),
              if (!hasImage)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 28,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text('未设置背景', style: context.text.bodySmall),
                    ],
                  ),
                ),
              // 预览示意卡片（保证文字可读性示意）
              if (hasImage)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Container(
                      width: 120,
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            color: palette.textPrimary,
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 24,
                            height: 3,
                            color: palette.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // 遮罩透明度读数
              if (hasImage)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: 0.85),
                        borderRadius: AppRadius.pillAll,
                      ),
                      child: Text(
                        '遮罩 ${(alpha * 100).round()}%',
                        style: context.text.labelSmall,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 手动模式滑杆（0–92%，实时生效并持久化，Spec §2.3/§5.3）
class _ManualAlphaSlider extends ConsumerWidget {
  const _ManualAlphaSlider({required this.settings});

  final BackgroundSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Slider(
      value: settings.manualAlpha.clamp(0.0, kOverlayAlphaCap),
      min: 0,
      max: kOverlayAlphaCap,
      divisions: 23, // 4% 步进
      label: '${(settings.manualAlpha * 100).round()}%',
      onChanged: (v) => ref
          .read(backgroundControllerProvider.notifier)
          .setOverlayMode(OverlayMode.manual, manualAlpha: v),
    );
  }
}

/// 对比度评级（手动模式提示，Spec §5.3：优 ≥4.5 / 良 ≥3.0 / 差 <3.0）
class _ContrastRating extends StatelessWidget {
  const _ContrastRating({required this.visuals});

  final BackgroundVisuals visuals;

  @override
  Widget build(BuildContext context) {
    final textL = relativeLuminance(context.palette.textPrimary);
    final ratio = contrastRatioFromLuminance(textL, visuals.effLum);
    final (label, color) = ratio >= 4.5
        ? ('优', context.appColors.income)
        : ratio >= 3.0
            ? ('良', context.appColors.warning)
            : ('差', context.appColors.expense);
    return Row(
      children: [
        Text('文字对比度：', style: context.text.bodySmall),
        Text('$label（${ratio.toStringAsFixed(1)}:1）',
            style: context.text.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}
