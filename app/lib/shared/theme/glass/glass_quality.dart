import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_provider.dart';
import '../../../data/repositories/settings_repository.dart';

/// 玻璃画质三档（Glassmorphism v3，Spec §2.3 / 设计文档 §7.2）：
/// 用户可调，默认「标准」。三档共享同一 Token 函数
/// （[resolveGlassSpec]），仅 σ 与填充补偿不同。
enum GlassQuality {
  /// 高保真：全部层级真实磨砂（σ 按层级表），旗舰机/桌面端
  high('高保真', '全部表面真实磨砂，适合旗舰机与桌面端'),

  /// 标准（默认）：L1/L2 fill-only + 光斑软化补偿，L3/L4 真实磨砂
  standard('标准', '主流机型流畅度与视觉上限兼顾（推荐）'),

  /// 省电：fill-only + 强补偿，L3/L4 σ×0.6，环境光强制静止
  saver('省电', '关闭环境光动效并降低弹层模糊');

  const GlassQuality(this.label, this.description);
  final String label;
  final String description;

  static GlassQuality parse(String? raw) => switch (raw) {
        'high' => high,
        'saver' => saver,
        _ => standard, // 缺失/非法默认 standard（Spec §2.3）
      };
}

/// 环境光斑强度三档（设计文档 §4.3）：含蓄 60% / 标准 85% / 浓郁 110%，
/// 缩放光斑 alpha；受 ContrastGuard 对比度联动钳制（§4.5）。
enum AmbientIntensity {
  soft('含蓄', 0.60),
  standard('标准', 0.85),
  rich('浓郁', 1.10);

  const AmbientIntensity(this.label, this.factor);
  final String label;

  /// 光斑 alpha 强度系数
  final double factor;

  static AmbientIntensity parse(String? raw) => switch (raw) {
        'soft' => soft,
        'rich' => rich,
        _ => standard,
      };
}

/// 玻璃与环境光个性化设置集合（app_meta 持久化，5 个新键，GLS-014）：
///
/// | 键 | 类型 | 默认 |
/// | glass_quality | string(high\|standard\|saver) | standard |
/// | ambient_motion_enabled | bool | true |
/// | ambient_intensity | string(soft\|standard\|rich) | standard |
/// | ambient_nav_pulse | bool | true |
/// | ambient_image_pulse | bool | false（背景图模式脉冲，§4.6 默认关）|
class GlassPrefs {
  const GlassPrefs({
    this.quality = GlassQuality.standard,
    this.motionEnabled = true,
    this.intensity = AmbientIntensity.standard,
    this.navPulse = true,
    this.imagePulse = false,
  });

  final GlassQuality quality;
  final bool motionEnabled;

  /// 用户请求的光斑强度（ContrastGuard 钳制后的有效值经
  /// [effectiveIntensity] 取得，不回写本字段）
  final AmbientIntensity intensity;

  /// 页面切换位移脉冲总开关（环境光渐变模式）
  final bool navPulse;

  /// 背景图模式脉冲开关（§4.6：默认关，可手动开启作用于遮罩明度 ±2%）
  final bool imagePulse;

  static const defaults = GlassPrefs();

  GlassPrefs copyWith({
    GlassQuality? quality,
    bool? motionEnabled,
    AmbientIntensity? intensity,
    bool? navPulse,
    bool? imagePulse,
  }) =>
      GlassPrefs(
        quality: quality ?? this.quality,
        motionEnabled: motionEnabled ?? this.motionEnabled,
        intensity: intensity ?? this.intensity,
        navPulse: navPulse ?? this.navPulse,
        imagePulse: imagePulse ?? this.imagePulse,
      );
}

/// 玻璃个性化控制器（D7：复用 app_meta 键值 + settings_repository 注入链路，
/// 不建表）。启动时由 main() 以持久化值覆盖初始 state（同 ThemeController）。
class GlassPrefsController extends Notifier<GlassPrefs> {
  GlassPrefsController({this._initial});

  final GlassPrefs? _initial;

  @override
  GlassPrefs build() => _initial ?? GlassPrefs.defaults;

  Future<void> _persist(GlassPrefs next) async {
    state = next;
    await SettingsRepository(ref.read(databaseProvider)).setGlassPrefs(next);
  }

  /// 切换画质档（即时生效：app_theme 组装器与各玻璃组件 watch 本 provider）
  Future<void> setQuality(GlassQuality q) => _persist(state.copyWith(quality: q));

  /// 环境光动效总开关
  Future<void> setMotionEnabled(bool v) =>
      _persist(state.copyWith(motionEnabled: v));

  /// 光斑强度三档
  Future<void> setIntensity(AmbientIntensity i) =>
      _persist(state.copyWith(intensity: i));

  /// 页面切换位移开关（环境光渐变模式）
  Future<void> setNavPulse(bool v) => _persist(state.copyWith(navPulse: v));

  /// 背景图模式脉冲开关
  Future<void> setImagePulse(bool v) =>
      _persist(state.copyWith(imagePulse: v));
}

/// 玻璃与环境光设置（默认值在 main() 启动时被持久化值覆盖；
/// 组件样板间等预览场景可局部 override）
final glassPrefsProvider =
    NotifierProvider<GlassPrefsController, GlassPrefs>(GlassPrefsController.new);
