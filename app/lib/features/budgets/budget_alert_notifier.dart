import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'budget_alert_service.dart';

/// 惰性初始化通知插件；平台不可用（非 Android/iOS、初始化失败）时降级为静默实现
final budgetAlertNotifierProvider = FutureProvider<BudgetNotifier>((ref) async {
  final notifier = await LocalBudgetNotifier.create();
  return notifier ?? _SilentNotifier();
});

class _SilentNotifier implements BudgetNotifier {
  @override
  Future<void> showBudgetAlert({required String title, required String body}) async {}
}

/// flutter_local_notifications 实现（审查 F-5）：初始化含 Android 13+ 权限请求；
/// 权限被拒时 show 抛错，由 BudgetAlertService 捕获降级（不影响记账）
class LocalBudgetNotifier implements BudgetNotifier {
  LocalBudgetNotifier(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'budget_alerts';
  static const _channelName = '预算提醒';

  /// 创建并初始化插件（含通知权限请求；返回 null 表示平台不可用）
  static Future<LocalBudgetNotifier?> create() async {
    final plugin = FlutterLocalNotificationsPlugin();
    try {
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {
      return null;
    }
    return LocalBudgetNotifier(plugin);
  }

  @override
  Future<void> showBudgetAlert({required String title, required String body}) async {
    await _plugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '预算阈值与超支提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
