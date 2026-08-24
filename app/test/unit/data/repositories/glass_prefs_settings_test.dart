import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/repositories/settings_repository.dart';
import 'package:bookkeep_app/shared/theme/glass/glass_quality.dart';
import 'package:drift/native.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db);
  });

  tearDown(() async => db.close());

  test('GLS-014 持久化往返：glassPrefs 全键写入读出一致', () async {
    // 默认值：standard / 开动效 / standard 强度 / 脉冲开 / 图像脉冲关
    final defaults = await repo.glassPrefs();
    expect(defaults.quality, GlassQuality.standard);
    expect(defaults.motionEnabled, isTrue);
    expect(defaults.intensity, AmbientIntensity.standard);
    expect(defaults.navPulse, isTrue);
    expect(defaults.imagePulse, isFalse);

    const custom = GlassPrefs(
      quality: GlassQuality.high,
      motionEnabled: false,
      intensity: AmbientIntensity.rich,
      navPulse: false,
      imagePulse: true,
    );
    await repo.setGlassPrefs(custom);
    final loaded = await repo.glassPrefs();
    expect(loaded.quality, GlassQuality.high);
    expect(loaded.motionEnabled, isFalse);
    expect(loaded.intensity, AmbientIntensity.rich);
    expect(loaded.navPulse, isFalse);
    expect(loaded.imagePulse, isTrue);

    // 再改回 saver 覆盖写（DoUpdate 分支）
    await repo.setGlassPrefs(
      custom.copyWith(quality: GlassQuality.saver, motionEnabled: true),
    );
    final reloaded = await repo.glassPrefs();
    expect(reloaded.quality, GlassQuality.saver);
    expect(reloaded.motionEnabled, isTrue);
  });

  test('GLS-014 缺失/脏数据回退默认（Spec §2.3 standard 兜底）', () async {
    // 只写一个非法档位字符串，其余键缺失
    await db.into(db.appMeta).insert(
          AppMetaCompanion.insert(key: 'glass_quality', value: 'ultra'),
        );
    final prefs = await repo.glassPrefs();
    expect(prefs.quality, GlassQuality.standard, reason: '非法值归 standard');
    expect(prefs.intensity, AmbientIntensity.standard, reason: '缺失归 standard');
  });
}
