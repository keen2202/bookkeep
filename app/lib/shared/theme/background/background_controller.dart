import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_provider.dart';
import '../../../data/repositories/settings_repository.dart';
import 'background_service.dart';
import 'background_settings.dart';

/// 背景图服务（widget 测试经 override 注入 fake）
final backgroundServiceProvider = Provider<BackgroundService>(
  (ref) => BackgroundService(),
);

/// 背景设置控制器（Spec §3.2 对外 API）
final backgroundControllerProvider =
    AsyncNotifierProvider<BackgroundController, BackgroundSettings>(
        BackgroundController.new);

/// 背景图热重载版本号：每次选图覆盖写入同一路径后自增，
/// 用于让 AppBackground / 预览的 Image 获得新 Key，立即重新解码新图。
/// 不持久化，仅会话内有效；重启后从磁盘读取，天然拿到最新文件。
final backgroundRevisionProvider = StateProvider<int>((ref) => 0);

/// 带热重载版本号的背景图 ImageProvider。
/// 继承 [FileImage] 但将 [revision] 纳入相等性，确保同路径覆盖选图后
/// 即使经过 ResizeImage 包装也不会命中旧缓存。
class RevisionFileImage extends FileImage {
  const RevisionFileImage(super.file, {required this.revision, super.scale = 1.0});

  final int revision;

  @override
  bool operator ==(Object other) =>
      other is RevisionFileImage &&
      other.runtimeType == runtimeType &&
      other.file.path == file.path &&
      other.scale == scale &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(file.path, scale, revision);
}

/// 背景设置控制器（Spec §3.2）：选图 → 压缩落盘 → 采样 → 持久化；
/// 独立 AsyncNotifier，避免阻塞主题切换（Spec D4）。
class BackgroundController extends AsyncNotifier<BackgroundSettings> {
  @override
  Future<BackgroundSettings> build() async {
    final repo = SettingsRepository(ref.read(databaseProvider));
    return repo.backgroundSettings();
  }

  Future<void> _persist(BackgroundSettings next) async {
    state = AsyncData(next);
    final repo = SettingsRepository(ref.read(databaseProvider));
    await repo.setBackgroundSettings(next);
  }

  /// 从相册选图 → 压缩拷贝到文档目录 → 采样亮度 → 应用并持久化（Spec §3.2）
  Future<PickResult> pickAndApply() async {
    final service = ref.read(backgroundServiceProvider);
    try {
      final picked = await service.pickImage();
      if (picked == null) {
        return const PickResult.failure('未选择图片');
      }
      final file = await service.importImage(picked);
      final nextRevision = ref.read(backgroundRevisionProvider) + 1;
      // P1 预缓存（Spec §2.4）：以新 revision 预热解码缓存，压缩首屏解码抖动，
      // 支撑真机"选图到生效 ≤800ms"指标；失败静默（渲染侧 errorBuilder 兜底）
      await _precacheImage(file, nextRevision);
      final current = state.valueOrNull ?? BackgroundSettings.defaults;
      await _persist(current.copyWith(
        enabled: true,
        imagePath: '${BackgroundService.dirName}/${BackgroundService.fileName}',
      ));
      // 热重载：同路径覆盖时通过 revision 让 ImageProvider 不等同，
      // 强制重新解码；backgroundImageFileProvider / backgroundLuminanceProvider
      // 均 watch 本 controller（select valueOrNull），_persist 每次写入新实例即
      // 自动触发重解析/重采样。不在 controller 内显式 invalidate：
      // Riverpod 2.6 调试模式下会触发 CircularDependencyError（依赖方在
      // 被依赖方执行期间被失效）。
      ref.read(backgroundRevisionProvider.notifier).state = nextRevision;
      return PickResult.ok(file);
    } on FormatException catch (e) {
      return PickResult.failure('图片无法读取或已损坏：$e');
    } catch (e) {
      return PickResult.failure('选图失败：$e');
    }
  }

  /// 以真实解码预热 ImageCache（Spec §2.4 P1）；监听器立即注册保证加载被触发，
  /// 结果不等待、失败静默
  Future<void> _precacheImage(File file, int revision) async {
    final provider = RevisionFileImage(file, revision: revision);
    // 同一路径覆盖选图时，先清掉旧 FileImage/旧 revision 缓存，再预热新图。
    await FileImage(file).evict();
    await RevisionFileImage(file, revision: revision - 1).evict();
    await provider.evict();
    final stream = provider.resolve(ImageConfiguration.empty);
    stream.addListener(ImageStreamListener((_, _) {}, onError: (_, _) {}));
  }

  /// 重新采样当前图片亮度（主题明暗切换后遮罩重算，Spec §3.2）；
  /// 采样结果经 [backgroundLuminanceProvider] 缓存并由本方法失效
  Future<void> refreshOverlay() async {
    final settings = state.valueOrNull;
    final imagePath = settings?.imagePath;
    if (settings == null || !settings.enabled || imagePath == null) return;
    ref.invalidate(backgroundLuminanceProvider);
  }

  Future<void> setOverlayMode(OverlayMode mode, {double? manualAlpha}) async {
    final current = state.valueOrNull ?? BackgroundSettings.defaults;
    await _persist(current.copyWith(
      overlayMode: mode,
      manualAlpha: manualAlpha ?? current.manualAlpha,
    ));
  }

  Future<void> setBlur(bool enabled) async {
    final current = state.valueOrNull ?? BackgroundSettings.defaults;
    await _persist(current.copyWith(blurEnabled: enabled));
  }

  /// 恢复纯色背景并删除本地图片文件（Spec §3.2）
  Future<void> clear() async {
    final current = state.valueOrNull ?? BackgroundSettings.defaults;
    await _persist(current.copyWith(enabled: false, clearImage: true));
    // 图片文件 provider 经 watch 本 controller 自动随 settings 更新，
    // 无需（也不能）在 controller 内显式 invalidate（依赖环，见 pickAndApply）
    ref.invalidate(backgroundLuminanceProvider);
    final service = ref.read(backgroundServiceProvider);
    await service.deleteImage();
  }

  /// 仅切换开关（保留已选图片，重启后图片仍在）
  Future<void> setEnabled(bool enabled) async {
    final current = state.valueOrNull ?? BackgroundSettings.defaults;
    if (enabled && current.imagePath == null) return; // 无图不可开启
    await _persist(current.copyWith(enabled: enabled));
  }
}

/// 当前背景图亮度（缓存采样结果；选图/clear/refreshOverlay 时失效）。
/// 主题明暗切换不影响亮度本身，AppBackground 侧按 palette 重算 α。
final backgroundLuminanceProvider = FutureProvider<double?>((ref) async {
  final settings =
      ref.watch(backgroundControllerProvider.select((s) => s.valueOrNull));
  final imagePath = settings?.imagePath;
  if (settings == null || !settings.enabled || imagePath == null) return null;
  final docs = await ref
      .read(backgroundServiceProvider)
      .resolveImageFile(imagePath);
  if (docs == null) return null;
  return ref.read(backgroundServiceProvider).sampleLuminance(docs);
});

/// 当前背景图文件（绝对路径解析，审核 F2/R1）：
/// 渲染侧（AppBackground / 外观页预览）一律消费本 provider 解析后的绝对路径
/// `File`，消除"写盘绝对路径 / 读图相对路径"双轨（真机 CWD 不可靠，
/// 相对路径可能静默渲染失败）。未启用 / 未选图 / 文件缺失返回 null
/// （渲染侧走"无背景图"分支）。
final backgroundImageFileProvider = FutureProvider<File?>((ref) async {
  final settings =
      ref.watch(backgroundControllerProvider.select((s) => s.valueOrNull));
  final imagePath = settings?.imagePath;
  if (settings == null || !settings.enabled || imagePath == null) return null;
  return ref.read(backgroundServiceProvider).resolveImageFile(imagePath);
});
