import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/shared/icons/bk_category_icons.dart';
import 'package:bookkeep_app/shared/icons/bk_icon_registry.dart';
import 'package:bookkeep_app/shared/icons/bk_icons.dart';
import 'package:bookkeep_app/shared/icons/painters/bk_category_painter.dart';

/// BK-IC-050：分类 seed `iconName` 目录、注册表与 Path 编译冒烟。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(BkIconRegistry.ensureInitialized);

  test('all category directory names resolve to a registered painter', () {
    expect(BkCategoryCatalog.names, isNotEmpty);
    for (final iconName in BkCategoryCatalog.names) {
      final id = BkCategoryCatalog.id(iconName);
      expect(id, '${BkIcons.catPrefix}$iconName');
      expect(BkIconRegistry.isRegistered(id), isTrue, reason: id);
    }
  });

  test('all category painters can compile their path and paint on 24 grid', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    for (final iconName in BkCategoryCatalog.names) {
      final painter = BkIconRegistry.resolve(
        BkCategoryCatalog.id(iconName),
        color: const Color(0xFF112233),
        selected: false,
      );
      expect(painter, isA<BkCategoryPainter>(), reason: iconName);
      // 触发 BkCategoryPaths 将命令字符串编译为 Path；命令语法错误会在此抛出。
      painter!.paint(canvas, const Size.square(24));
    }
    final picture = recorder.endRecording();
    expect(picture, isNotNull);
    picture.dispose();
  });

  test('unknown iconName maps to registered generic category id', () {
    expect(BkCategoryCatalog.id('not_a_real_icon'), BkIcons.catFallback);
    expect(BkCategoryCatalog.contains('not_a_real_icon'), isFalse);
    expect(BkIconRegistry.isRegistered(BkIcons.catFallback), isTrue);
  });

  test('shouldRepaint detects glyph changes as well as color', () {
    final a = BkIconRegistry.resolve(
      BkCategoryCatalog.id('restaurant'),
      color: const Color(0xFF000000),
      selected: false,
    )!;
    final b = BkIconRegistry.resolve(
      BkCategoryCatalog.id('flight'),
      color: const Color(0xFF000000),
      selected: false,
    )!;
    expect(a.shouldRepaint(b), isTrue);
  });
}
