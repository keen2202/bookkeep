import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'luminance.dart';

/// 背景图存取/压缩/采样（BK-UI-013，Spec §5.4）：
/// 选图（image_picker，Android 13+ PhotoPicker / iOS 相册权限）→
/// 压缩（最长边 1920px）→ 文档目录固定文件名 → 32×32 采样亮度。
///
/// 压缩编码说明：Spec D6 禁止第三方图像库，dart:ui 仅支持 PNG 编码
/// （ImageByteFormat 无 JPEG），故 Spec §5.4 的"JPEG Q85"以
/// 「最长边 1920px + PNG 无损重编码」实现——分辨率上限与解码成本
/// 受控目标达成，画质反而无损。文件仅存本地文档目录（隐私，Spec §8）。
class BackgroundService {
  BackgroundService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const dirName = 'background';
  static const fileName = 'bg.png';

  /// 最长边压缩上限（Spec §5.4.2：1920px）
  static const int maxEdgePx = 1920;

  /// 从相册选图；用户取消返回 null
  Future<XFile?> pickImage() => _picker.pickImage(source: ImageSource.gallery);

  /// 应用文档目录下背景图文件的绝对路径
  Future<String> _targetPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/$dirName/$fileName';
  }

  /// 目标图片文件（不存在时父目录自动创建）
  Future<File> targetFile() async => File(await _targetPath());

  /// 压缩导入：读取源图 → 最长边 1920px 缩放下采样 → PNG 重编码 → 覆盖写入。
  /// 解码失败（非图片/损坏）抛 [FormatException]。
  Future<File> importImage(XFile source) async {
    final bytes = await source.readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final w = descriptor.width, h = descriptor.height;
      final maxEdge = math.max(w, h);
      final scale = maxEdge > maxEdgePx ? maxEdgePx / maxEdge : 1.0;
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (w * scale).round()),
        targetHeight: math.max(1, (h * scale).round()),
      );
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw const FormatException('图片编码失败');
      final file = await targetFile();
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png.buffer.asUint8List(), flush: true);
      return file;
    } finally {
      descriptor.dispose();
    }
  }

  /// 采样当前背景图亮度（Spec §5.4.3：32×32 解码 < 16ms）；文件缺失返回 null
  Future<double?> sampleLuminance(File file) async {
    if (!await file.exists()) return null;
    return decodeLuminance(await file.readAsBytes());
  }

  /// 当前背景图文件；不存在返回 null
  Future<File?> imageFile() async {
    final file = await targetFile();
    return await file.exists() ? file : null;
  }

  /// 由持久化的相对路径（文档目录内）解析为绝对路径；文件不存在返回 null
  Future<File?> resolveImageFile(String relativePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/$relativePath');
    return await file.exists() ? file : null;
  }

  /// 删除本地背景图（clear() 时调用，Spec §5.4.4）
  Future<void> deleteImage() async {
    final file = await targetFile();
    if (await file.exists()) await file.delete();
  }
}

/// 选图结果（Spec §3.2：携带失败原因，UI 提示）
class PickResult {
  const PickResult._({this.file, this.error});

  const PickResult.ok(File file) : this._(file: file);
  const PickResult.failure(String error) : this._(error: error);

  /// 成功导入并压缩后的背景图文件
  final File? file;

  /// 失败原因（用户取消视为失败并提示"未选择图片"）
  final String? error;

  bool get isSuccess => file != null;
  String get message => error ?? '';
}
