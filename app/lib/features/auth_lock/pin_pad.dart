import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/glass/glass_layers.dart';

/// 自绘 PIN 数字键盘（Spec §3.6 / BK-T-008）；输入满 [length] 位自动提交。
/// Glassmorphism v3（GLS-010 散点收敛）：键帽收敛到 L1 层级 Token
/// （fill-only——批量键帽元素遵循 D2 永不启用真实磨砂）。
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onSubmit, this.length = 6});

  final void Function(String pin) onSubmit;
  final int length;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';

  void _append(String digit) {
    if (_pin.length >= widget.length) return;
    setState(() => _pin += digit);
    if (_pin.length == widget.length) {
      final value = _pin;
      // 延迟一帧提交，保证错误状态下锁屏可随 key 重建清空缓冲
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSubmit(value));
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.length; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final d in row)
                _Key(
                  label: d,
                  onTap: () => _append(d),
                ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72),
            _Key(label: '0', onTap: () => _append('0')),
            _Key(
              icon: Icons.backspace_outlined,
              onTap: _backspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // GLS-010：键帽玻璃规格（L1 填充 + 1px 白系描边，fill-only）
    final spec = resolveGlassSpec(
      tier: GlassTier.panel,
      brightness: theme.brightness,
      palette: context.palette,
      quality: context.tokens.glassQuality,
    );
    return Semantics(
      // 审查 U-12：读屏可识别按键；触控即反馈（HapticFeedback）
      button: true,
      label: icon != null ? '退格' : '数字 $label',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: 72,
          height: 64,
          margin: const EdgeInsets.all(3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: spec.fill,
            shape: BoxShape.circle,
            // 描边宽度恒 1（Border.all 默认值，Spec §2.1）
            border: Border.all(color: spec.borderColor),
          ),
          child: icon != null
              ? Icon(icon, color: theme.colorScheme.onSurfaceVariant)
              : Text(label!, style: theme.textTheme.titleLarge),
        ),
      ),
    );
  }
}
