import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/local/database_provider.dart';
import 'package:bookkeep_app/data/repositories/settings_repository.dart';
import 'package:bookkeep_app/shared/theme/theme_controller.dart';
import 'package:bookkeep_app/shared/theme/theme_presets.dart';
import 'package:bookkeep_app/shared/theme/theme_settings.dart';

/// 个性化主题：持久化读写往返 + 预设主题 + 旧键兼容迁移（审核 F3）
void main() {
  test('themeSettings 未配置回退默认值', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final settings = await SettingsRepository(db).themeSettings();

    expect(settings.seedColor, ThemeSettings.defaults.seedColor);
    expect(settings.mode, ThemeMode.system);
  });

  test('setThemeSettings 读写往返（种子色 + 外观模式）', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = SettingsRepository(db);

    await repo.setThemeSettings(
      const ThemeSettings(seedColor: Color(0xFF8E24AA), mode: ThemeMode.dark),
    );
    final read = await repo.themeSettings();

    expect(read.seedColor, const Color(0xFF8E24AA));
    expect(read.mode, ThemeMode.dark);

    // 覆盖更新
    await repo.setThemeSettings(
      const ThemeSettings(seedColor: Color(0xFF0288D1), mode: ThemeMode.light),
    );
    final updated = await repo.themeSettings();
    expect(updated.seedColor, const Color(0xFF0288D1));
    expect(updated.mode, ThemeMode.light);
  });

  test('预设主题色互异且避开纯红纯绿', () async {
    final unique = kThemePresets.toSet();
    expect(unique, hasLength(kThemePresets.length));
    for (final c in kThemePresets) {
      expect(c, isNot(Colors.red.shade700));
      expect(c, isNot(Colors.green.shade800));
    }
    expect(kThemePresets.first, ThemeSettings.defaults.seedColor);
  });

  // ---------------------------------------------------------------------------
  // 审核 F3：旧键兼容迁移 / presetId 往返 / 脏数据兜底
  // （对应 settings_repository.dart themeSettings() 兼容规则，Spec §2.2）
  // ---------------------------------------------------------------------------

  test('旧用户升级：仅存在 theme_seed/theme_mode 旧键 → presetId=custom 且按旧键还原', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // 直接写旧键（模拟升级前持久化数据；无 theme_preset_id）
    await db.batch((batch) {
      batch.insert(db.appMeta,
          AppMetaCompanion.insert(key: 'theme_seed', value: 'D81B60'),
          onConflict: DoUpdate((_) => AppMetaCompanion(value: Value('D81B60'))));
      batch.insert(db.appMeta,
          AppMetaCompanion.insert(key: 'theme_mode', value: 'dark'),
          onConflict: DoUpdate((_) => AppMetaCompanion(value: Value('dark'))));
    });

    final settings = await SettingsRepository(db).themeSettings();

    expect(settings.presetId, AppThemePreset.customId);
    expect(settings.isCustom, isTrue);
    // 旧键按 6 位 hex 还原种子色与外观模式（观感与旧版一致）
    expect(settings.seedColor, const Color(0xFFD81B60));
    expect(settings.mode, ThemeMode.dark);
  });

  test('presetId 读写往返：applyPreset 持久化后重读一致', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(themeControllerProvider.notifier).applyPreset('t3');
    final read = await SettingsRepository(db).themeSettings();

    expect(read.presetId, 't3');
    // 预制主题直出路径：preset 可解析且非 custom
    expect(read.isCustom, isFalse);
    expect(read.preset!.id, 't3');
  });

  test('脏数据兜底：theme_preset_id 非法值（t99）→ isCustom=true', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = SettingsRepository(db);
    await repo.setThemeSettings(
      ThemeSettings.defaults.copyWith(presetId: 't1'),
    );

    // 直接写脏值模拟异常持久化
    await db.into(db.appMeta).insert(
          AppMetaCompanion.insert(key: 'theme_preset_id', value: 't99'),
          onConflict: DoUpdate((_) => AppMetaCompanion(value: Value('t99'))),
        );

    final read = await repo.themeSettings();
    expect(read.presetId, 't99');
    // preset 解析失败 → 按 custom 兜底（防脏设计，ThemeSettings.preset）
    expect(read.isCustom, isTrue);
    expect(read.preset, isNull);
  });
}
