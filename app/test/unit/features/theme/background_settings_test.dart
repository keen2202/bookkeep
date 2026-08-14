import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/repositories/settings_repository.dart';
import 'package:bookkeep_app/shared/theme/background/background_settings.dart';

/// 背景设置持久化（Spec §9 单元层：序列化与默认值回退）
void main() {
  test('未配置回退默认值（无背景图）', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final settings = await SettingsRepository(db).backgroundSettings();

    expect(settings.enabled, isFalse);
    expect(settings.imagePath, isNull);
    expect(settings.overlayMode, OverlayMode.auto);
    expect(settings.manualAlpha, 0.70);
    expect(settings.blurEnabled, isTrue);
  });

  test('读写往返：全部字段', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = SettingsRepository(db);

    await repo.setBackgroundSettings(const BackgroundSettings(
      enabled: true,
      imagePath: 'background/bg.png',
      overlayMode: OverlayMode.manual,
      manualAlpha: 0.42,
      blurEnabled: false,
    ));
    final read = await repo.backgroundSettings();
    expect(read.enabled, isTrue);
    expect(read.imagePath, 'background/bg.png');
    expect(read.overlayMode, OverlayMode.manual);
    expect(read.manualAlpha, closeTo(0.42, 1e-9));
    expect(read.blurEnabled, isFalse);

    // 覆盖更新 + 清除图片路径
    await repo.setBackgroundSettings(read.copyWith(
      enabled: false,
      clearImage: true,
      overlayMode: OverlayMode.auto,
      manualAlpha: 0.80,
      blurEnabled: true,
    ));
    final updated = await repo.backgroundSettings();
    expect(updated.enabled, isFalse);
    expect(updated.imagePath, isNull);
    expect(updated.overlayMode, OverlayMode.auto);
    expect(updated.manualAlpha, closeTo(0.80, 1e-9));
    expect(updated.blurEnabled, isTrue);
  });

  test('脏数据兜底：非法 alpha 回退默认', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = SettingsRepository(db);
    await repo.setBackgroundSettings(const BackgroundSettings(manualAlpha: 0.66));

    // 直接写脏值模拟异常持久化
    await db.into(db.appMeta).insert(
          AppMetaCompanion.insert(key: 'bg_overlay_alpha', value: 'not-a-number'),
          onConflict: DoUpdate((_) => AppMetaCompanion(value: Value('not-a-number'))),
        );
    final read = await repo.backgroundSettings();
    expect(read.manualAlpha, BackgroundSettings.defaults.manualAlpha);
  });

  test('脏数据兜底：bg_overlay_mode 非法值回退 auto（审核 S3，解析层全键兜底）', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = SettingsRepository(db);
    await repo.setBackgroundSettings(
        const BackgroundSettings(overlayMode: OverlayMode.manual));

    // 直接写脏值模拟异常持久化
    await db.into(db.appMeta).insert(
          AppMetaCompanion.insert(key: 'bg_overlay_mode', value: 'not-a-mode'),
          onConflict: DoUpdate((_) => AppMetaCompanion(value: Value('not-a-mode'))),
        );
    final read = await repo.backgroundSettings();
    expect(read.overlayMode, OverlayMode.auto);
  });

  test('copyWith：clearImage 清除路径但保留其余字段', () {
    const s = BackgroundSettings(
      enabled: true,
      imagePath: 'background/bg.png',
      overlayMode: OverlayMode.manual,
      manualAlpha: 0.5,
      blurEnabled: false,
    );
    final cleared = s.copyWith(clearImage: true);
    expect(cleared.imagePath, isNull);
    expect(cleared.enabled, isTrue);
    expect(cleared.overlayMode, OverlayMode.manual);
    expect(cleared.manualAlpha, 0.5);
    expect(cleared.blurEnabled, isFalse);
  });
}
