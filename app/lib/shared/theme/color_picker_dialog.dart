import 'package:flutter/material.dart';

import '../widgets/app_button.dart';
import 'app_theme.dart';

/// 自绘 HSV 取色器（无第三方依赖）：SV 方块 + 色相滑条 + 实时预览/HEX
///
/// 注：色相滑条与 SV 方块内的光谱渐变为功能性绘制（HSV 色彩空间固有取色），
/// 不属于主题硬编码，不入 lint 收敛范围。
class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({super.key, required this.initial});

  final Color initial;

  static Future<Color?> show(BuildContext context, {required Color initial}) {
    return showDialog<Color>(
      context: context,
      builder: (_) => ColorPickerDialog(initial: initial),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  String get _hex => '#${(_hsv.toColor().toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _setHue(double hue) => setState(() => _hsv = _hsv.withHue(hue.clamp(0, 360)));

  void _setSv(Offset pos, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final s = (pos.dx / size.width).clamp(0.0, 1.0);
    final v = (1 - pos.dy / size.height).clamp(0.0, 1.0);
    setState(() => _hsv = _hsv.withSaturation(s).withValue(v));
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return AlertDialog(
      title: const Text('选择颜色'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onPanDown: (d) => _setSv(d.localPosition, constraints.biggest),
                onPanUpdate: (d) => _setSv(d.localPosition, constraints.biggest),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 160),
                  painter: _SvSquarePainter(hue: _hsv.hue),
                  child: Align(
                    alignment: Alignment(_hsv.saturation * 2 - 1, 1 - _hsv.value * 2),
                    child: _thumb(_hsv.toColor()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onTapDown: (d) =>
                    _setHue(d.localPosition.dx / constraints.maxWidth * 360),
                onHorizontalDragUpdate: (d) =>
                    _setHue(d.localPosition.dx / constraints.maxWidth * 360),
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ]),
                  ),
                  child: Align(
                    alignment: Alignment(_hsv.hue / 360 * 2 - 1, 0),
                    child: _thumb(color),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Text(_hex, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        AppButton.primary(
          onPressed: () => Navigator.pop(context, color),
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _thumb(Color color) {
    // UI 重构（Spec §6 收敛）：描边/阴影取 palette，描边色随取色动态取对比色
    final palette = context.palette;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: onColorFor(color), width: 2),
        boxShadow: [BoxShadow(color: palette.scrim.withValues(alpha: 0.26), blurRadius: 2)],
      ),
    );
  }
}

/// SV 方块：底色 = 当前色相，叠加 白→透明（横向）与 透明→黑（纵向）
class _SvSquarePainter extends CustomPainter {
  const _SvSquarePainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [hueColor, Colors.white],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SvSquarePainter oldDelegate) => oldDelegate.hue != hue;
}
