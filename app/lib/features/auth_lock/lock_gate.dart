import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lock_controller.dart';
import 'pin_pad.dart';

/// MaterialApp.builder 挂载点：包裹 Navigator，锁定态覆盖含已 push 路由的整个界面
Widget lockGateBuilder(BuildContext context, Widget? child) {
  return LockGate(child: child ?? const SizedBox.shrink());
}

/// 全局锁门：锁定态覆盖整个 App；监听生命周期实现后台 30s 自动上锁
/// 与后台即时脱敏（Spec §3.6 / BK-T-008）
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final controller = ref.read(lockControllerProvider.notifier);
    switch (lifecycleState) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        controller.appBackgrounded();
      case AppLifecycleState.resumed:
        controller.appResumed();
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockControllerProvider);
    if (!lock.pinConfigured || !lock.locked) return widget.child;
    return const _LockScreen();
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  int _attempt = 0;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final lock = ref.read(lockControllerProvider);
    if (!lock.pinConfigured || !lock.biometricEnabled) return;
    final available = await ref.read(biometricProvider).available();
    if (mounted) setState(() => _bioAvailable = available);
  }

  Future<void> _submit(String pin) async {
    final ok = await ref.read(lockControllerProvider.notifier).unlockWithPin(pin);
    if (!ok && mounted) {
      setState(() => _attempt++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN 错误，请重试')),
      );
    }
  }

  Future<void> _unlockBiometric() async {
    await ref.read(lockControllerProvider.notifier).unlockWithBiometric();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('bookkeep 已锁定', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('请输入 PIN 解锁', style: theme.textTheme.bodySmall),
                if (_bioAvailable) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: _unlockBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('生物识别解锁'),
                  ),
                ],
                const SizedBox(height: 24),
                PinPad(key: ValueKey('pinpad-$_attempt'), onSubmit: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
