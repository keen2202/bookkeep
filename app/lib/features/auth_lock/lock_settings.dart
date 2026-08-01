import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lock_controller.dart';
import 'pin_pad.dart';

/// 设置页隐私锁区块（BK-T-008）
class LockSettingsTile extends ConsumerWidget {
  const LockSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(lockControllerProvider);
    final notifier = ref.read(lockControllerProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          title: const Text('隐私锁'),
          subtitle: Text(
            lock.pinConfigured ? '已开启（PIN + 生物识别）' : '锁定后隐藏金额，后台 30s 自动上锁',
          ),
          value: lock.pinConfigured,
          onChanged: (v) async {
            if (v) {
              final pin = await showDialog<String>(
                context: context,
                builder: (_) => const SetPinDialog(),
              );
              if (pin != null) await notifier.enable(pin);
            } else {
              final pin = await showDialog<String>(
                context: context,
                builder: (_) => const VerifyPinDialog(title: '关闭隐私锁'),
              );
              if (pin != null) {
                final ok = await notifier.disable(pin);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN 错误，无法关闭')),
                  );
                }
              }
            }
          },
        ),
        if (lock.pinConfigured) ...[
          SwitchListTile(
            title: const Text('生物识别解锁'),
            value: lock.biometricEnabled,
            onChanged: (v) => notifier.setBiometricEnabled(v),
          ),
          ListTile(
            leading: const Icon(Icons.lock_clock),
            title: const Text('立即锁定'),
            onTap: notifier.lockNow,
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('修改 PIN'),
            onTap: () async {
              final oldPin = await showDialog<String>(
                context: context,
                builder: (_) => const VerifyPinDialog(title: '修改 PIN'),
              );
              if (oldPin == null || !context.mounted) return;
              final newPin = await showDialog<String>(
                context: context,
                builder: (_) => const SetPinDialog(),
              );
              if (newPin == null) return;
              final ok = await notifier.changePin(oldPin, newPin);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('原 PIN 错误，修改失败')),
                );
              }
            },
          ),
        ],
      ],
    );
  }
}

/// 设置 PIN：两段式输入 + 确认；返回最终 PIN 或 null（取消）
class SetPinDialog extends StatefulWidget {
  const SetPinDialog({super.key});

  @override
  State<SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<SetPinDialog> {
  String? _first;
  bool _confirming = false;

  void _submit(String pin) {
    if (!_confirming) {
      setState(() {
        _first = pin;
        _confirming = true;
      });
      return;
    }
    if (pin == _first) {
      Navigator.of(context).pop(pin);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次输入不一致，请重新设置')),
      );
      setState(() {
        _first = null;
        _confirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_confirming ? '再次输入确认' : '设置 6 位数字 PIN'),
      content: PinPad(
        key: ValueKey('setpin-${_confirming ? 1 : 0}'),
        onSubmit: _submit,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

/// 校验当前 PIN；返回 PIN 或 null（取消）
class VerifyPinDialog extends StatelessWidget {
  const VerifyPinDialog({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: PinPad(onSubmit: (pin) => Navigator.of(context).pop(pin)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
