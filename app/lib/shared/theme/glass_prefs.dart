import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database_provider.dart';
import '../../data/repositories/settings_repository.dart';

/// 玻璃偏好（FGDS v1.0，BK-FG-003）：唯一用户可调项——低性能设备可
/// 禁用真实磨砂，玻璃面板以 fill α +0.10 补偿（Spec §3 派生规则）。
///
/// 旧 Glassmorphism v3 的画质三档与环境光四键
/// （glass_quality / ambient_*）已随旧系统一次性拆除（Spec §8 清除清单，
/// AC-08）；历史持久化键被读取时忽略、不再写入。
class GlassPrefs {
  const GlassPrefs({this.blurEnabled = true});

  /// true：容器级组件启用 BackdropFilter 真模糊；false：fill-only 降级
  final bool blurEnabled;

  static const defaults = GlassPrefs();

  GlassPrefs copyWith({bool? blurEnabled}) =>
      GlassPrefs(blurEnabled: blurEnabled ?? this.blurEnabled);
}

/// 玻璃偏好控制器（复用 app_meta 键值 + settings_repository 注入链路）。
/// 启动时由 main() 以持久化值覆盖初始 state（同 ThemeController）。
class GlassPrefsController extends Notifier<GlassPrefs> {
  GlassPrefsController({this._initial});

  final GlassPrefs? _initial;

  @override
  GlassPrefs build() => _initial ?? GlassPrefs.defaults;

  Future<void> _persist(GlassPrefs next) async {
    state = next;
    await SettingsRepository(ref.read(databaseProvider)).setGlassPrefs(next);
  }

  /// 切换磨砂降级开关（即时生效：AppBackground watch 后经作用域下发）
  Future<void> setBlurEnabled(bool v) =>
      _persist(state.copyWith(blurEnabled: v));
}

/// 玻璃偏好（默认值在 main() 启动时被持久化值覆盖）
final glassPrefsProvider =
    NotifierProvider<GlassPrefsController, GlassPrefs>(GlassPrefsController.new);
