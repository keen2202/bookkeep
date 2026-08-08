import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookkeep_app/data/local/database.dart';
import 'package:bookkeep_app/data/repositories/settings_repository.dart';
import 'package:bookkeep_app/shared/theme/theme_settings.dart';

/// 个性化主题：持久化读写往返 + 预设主题
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
}
