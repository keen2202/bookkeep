import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/repositories/settings_repository.dart';
import 'package:bookkeep_app/shared/theme/glass_prefs.dart';
import 'package:drift/native.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db);
  });

  tearDown(() async => db.close());

  test('FGDS 持久化往返：blurEnabled 写入读出一致', () async {
    // 默认值：启用真实磨砂
    final defaults = await repo.glassPrefs();
    expect(defaults.blurEnabled, isTrue);

    await repo.setGlassPrefs(const GlassPrefs(blurEnabled: false));
    final loaded = await repo.glassPrefs();
    expect(loaded.blurEnabled, isFalse);

    // 覆盖写（DoUpdate 分支）
    await repo.setGlassPrefs(const GlassPrefs(blurEnabled: true));
    final reloaded = await repo.glassPrefs();
    expect(reloaded.blurEnabled, isTrue);
  });

  test('FGDS：键缺失回退默认（启用磨砂）；旧 v3 ambient_* 键被忽略', () async {
    // 历史遗留键（旧版本库升级场景）不应影响新模型
    await db.into(db.appMeta).insert(
          AppMetaCompanion.insert(key: 'glass_quality', value: 'saver'),
        );
    await db.into(db.appMeta).insert(
          AppMetaCompanion.insert(
              key: 'ambient_motion_enabled', value: 'false'),
        );
    final prefs = await repo.glassPrefs();
    expect(prefs.blurEnabled, isTrue, reason: '缺 glass_blur_enabled 键 → 默认开启');
  });

  test('FGDS：glass_blur_enabled=false 正确读取', () async {
    await db.into(db.appMeta).insert(
          AppMetaCompanion.insert(
              key: 'glass_blur_enabled', value: 'false'),
        );
    final prefs = await repo.glassPrefs();
    expect(prefs.blurEnabled, isFalse);
  });

  test('copyWith 语义：仅覆盖传入字段', () {
    const base = GlassPrefs(blurEnabled: false);
    expect(base.copyWith().blurEnabled, isFalse);
    expect(base.copyWith(blurEnabled: true).blurEnabled, isTrue);
    expect(GlassPrefs.defaults.blurEnabled, isTrue);
  });
}
