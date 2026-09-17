import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/lock_repository.dart';
import '../../shared/icons/bk_icon.dart';
import '../../shared/icons/bk_icons.dart';
import '../../shared/widgets/app_button.dart';
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
    final repo = ref.read(lockRepositoryProvider);
    if (await repo.isLockedOut()) {
      final until = await repo.pinLockUntil();
      final secs = until == null
          ? 0
          : until.difference(DateTime.now()).inSeconds.clamp(0, 3600);
      if (!mounted) return;
      setState(() => _attempt++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('尝试次数过多，请 $secs 秒后再试')),
      );
      return;
    }
    final ok = await ref.read(lockControllerProvider.notifier).unlockWithPin(pin);
    if (!ok && mounted) {
      final fails = await repo.pinFailCount();
      if (!mounted) return;
      setState(() => _attempt++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fails >= LockRepository.failThresholdHard
                ? 'PIN 错误，已锁定 5 分钟'
                : fails >= LockRepository.failThresholdSoft
                    ? 'PIN 错误，已冷却 30 秒'
                    : 'PIN 错误，请重试',
          ),
        ),
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
                // BK-IC-041：隐私锁主形用 bk.status.lock
                BkIcon(
                  BkIcons.statusLock,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text('bookkeep 已锁定', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('请输入 PIN 解锁', style: theme.textTheme.bodySmall),
                if (_bioAvailable) ...[
                  const SizedBox(height: 16),
                  AppButton.secondary(
                    onPressed: _unlockBiometric,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fingerprint, size: 18),
                        SizedBox(width: 8),
                        Text('生物识别解锁'),
                      ],
                    ),
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
