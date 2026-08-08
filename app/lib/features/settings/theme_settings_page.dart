import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database_provider.dart';
import '../../data/repositories/settings_repository.dart';
import '../../shared/theme/color_picker_dialog.dart';
import '../../shared/theme/theme_settings.dart';

/// 个性化主题设置页：预设主题色 + 自定义取色 + 外观模式；
/// 每次选择即时生效（写 app_meta + 更新 provider → 全树热重建）
class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  Future<void> _apply(BuildContext context, WidgetRef ref, ThemeSettings next) async {
    final repo = SettingsRepository(ref.read(databaseProvider));
    await repo.setThemeSettings(next);
    ref.read(themeSettingsProvider.notifier).state = next;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeSettingsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('个性化主题')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('外观模式', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
              ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
              ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
            ],
            selected: {current.mode},
            onSelectionChanged: (s) => _apply(
              context,
              ref,
              ThemeSettings(seedColor: current.seedColor, mode: s.first),
            ),
          ),
          const SizedBox(height: 24),
          Text('主题颜色', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in kThemePresets)
                _PresetDot(
                  color: color,
                  selected: color.toARGB32() == current.seedColor.toARGB32(),
                  onTap: () => _apply(
                    context,
                    ref,
                    ThemeSettings(seedColor: color, mode: current.mode),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.colorize),
            label: const Text('自定义颜色'),
            onPressed: () async {
              final picked = await ColorPickerDialog.show(
                context,
                initial: current.seedColor,
              );
              if (picked != null && context.mounted) {
                await _apply(
                  context,
                  ref,
                  ThemeSettings(seedColor: picked, mode: current.mode),
                );
              }
            },
          ),
          if (current.mode != ThemeMode.system) ...[
            const SizedBox(height: 8),
            Text(
              current.mode == ThemeMode.light ? '当前：浅色模式' : '当前：深色模式',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PresetDot extends StatelessWidget {
  const _PresetDot({required this.color, required this.selected, required this.onTap});

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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
              : null,
        ),
        child: selected ? Icon(Icons.check, color: checkColor) : null,
      ),
    );
  }
}
