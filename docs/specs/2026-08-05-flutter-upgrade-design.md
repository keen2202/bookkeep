# Flutter SDK 升级设计：3.24.5 → 3.44.8（Dart 3.12.2）

日期：2026-08-05
状态：已批准

## 背景与目标

当前项目固定在 Flutter 3.24.5（Dart 3.5.x），依赖停留在 2024 年中（drift 2.20、fl_chart 0.69、flutter_lints 4 等），
且有 `drift_flutter 0.2.6` 的手动 pin 绕过旧 Dart 解析器问题。本次升级将：

1. SDK 升至 **Flutter 3.44.8 stable（Dart 3.12.2）**（本机已装于 `/opt/flutter/flutter`）
2. 全部依赖升级到最新兼容版本（major 版本可升级）
3. 修复所有破坏性变更，保证 `flutter analyze` 零告警、单元测试全绿

Server（Node.js）不涉及，完全不动。

## 执行策略

- 先提交当前工作区未提交的改动（16 个文件：drift_flutter pin、测试更新等）为一个 commit
- 在原工作树就地升级（master）
- 两阶段验证，两次 commit：
  - **Stage 1（toolchain commit）**：SDK 版本 + CI pin，旧依赖下验证
  - **Stage 2（deps commit）**：依赖升级 + 破坏性变更修复，新依赖下验证

## Stage 1 — Toolchain（`chore: upgrade Flutter SDK 3.24.5 → 3.44.8`）

- CI pin 更新（3 个文件，各 1 处 + 注释）：
  - `.github/workflows/ci.yml`、`.github/workflows/nightly.yml`、`.github/workflows/build.yaml`
  - `flutter-version: '3.24.5'` → `'3.44.8'`，同步更新「与 build.yaml 质量门禁保持一致」等注释
- `app/pubspec.yaml`：`environment.sdk` → `^3.12.0`（Dart 3.12.2）
- Android：预期零改动。AGP 9.0.1 / Kotlin 2.3.20 / Gradle 9.1 均高于 3.44 最低要求
  （AGP 最低 8.6，建议 8.11.1）；compileSdk/minSdk/targetSdk 由 Flutter Gradle Plugin 自动跟随
- iOS：Podfile `platform :ios, '13.0'` — 若 3.44.8 模板最低版本更高则对齐模板，否则保持
- 验证：旧依赖下跑 `flutter analyze` + `flutter test`
  - 风险：flutter_lints 4 可能在新 analyzer 下报「未知 lint 名」等告警，导致 analyze 非零；
    若出现，将 flutter_lints 升级并入 Stage 1，保证该 commit 质量门禁绿

## Stage 2 — 依赖现代化（`chore: upgrade dependencies for Flutter 3.44.8`）

### 升级清单（预期 major）

| 包 | 当前 | 目标 | 说明 |
|---|---|---|---|
| drift / drift_dev | 2.20.x | 3.x | 最大风险项；若 3.x 迁移成本过高则回退最新 2.2x 并记录 |
| drift_flutter | 0.2.6（pin） | 最新 | 移除 pin 注释；Dart 3.12 解析器下 drift ≥2.24 可解析 |
| fl_chart | 0.69.x | 1.x | 图表 API 变更（cashflow_chart、budget_progress_bar、reports） |
| flutter_lints | 4.x | 6.x | 新增 lint 规则，需全 lib/test 修复 |
| flutter_secure_storage | 9.2.2 | 10.x | key_store 相关 API 变更 |
| intl | 0.19 | 0.20 | DateFormat/NumberFormat 兼容性 |
| table_calendar | 3.1.2 | 最新 3.x | 预期 minor |
| local_auth / cryptography / http / uuid / path_provider / build_runner / mocktail / sqlite3 / sqlcipher_flutter_libs / sqlite3_flutter_libs | 现版本 | 最新兼容 | |

### 破坏性变更修复

- Flutter deprecations：`MaterialState*` → `WidgetState*`、`withOpacity` → `withValues(alpha:)`、
  `Color.value` → `toARGB32()`、`WillPopScope` → `PopScope`、`surfaceVariant` → `surfaceContainerHighest`
- fl_chart 1.x API 变更
- flutter_secure_storage 10.x API 变更
- drift 3.x API 变更（如有）
- flutter_lints 6 新规则违规修复

### 约束

- **不对全库跑 `dart format`**（Dart 3.12 矮胖风格 formatter 会产生巨大 diff），只格式化触碰的文件或不动
- Drift 代码重新生成：`dart run build_runner build --delete-conflicting-outputs`
- **Schema 必须保持 v6 不变**（无表结构变更 → 迁移链不动）；若生成产物变化需复查

### 验证

- `flutter analyze`：零告警（CI 质量门禁）
- `flutter test`：全绿
- `flutter pub outdated`：无遗留 major（或记录原因）

## 验证边界与风险

- 本机无 Android SDK / 模拟器 / iOS 工具链：集成测试（nightly 工作流）与 APK/IPA 构建
  只能在 CI 中验证（升级后的 workflow 即验证本身）
- 最大风险：drift 3.x 迁移规模。决策点：实施时若 `pub upgrade` 解析出 drift 3.x 且破坏面过大，
  回退 drift 至最新 2.2x 并记录到 commit message / 本设计文档

## 涉及文件

- `.github/workflows/{ci,nightly,build}.yaml` — pin
- `app/pubspec.yaml`、`app/pubspec.lock` — SDK 约束 + 依赖
- `app/lib/**` — 破坏性变更修复（charts、key_store、导航、主题等）
- `app/test/**` — 测试修复
- 可能：`app/ios/Podfile`（platform 兜底对齐）、`app/android/**`（预期不动）

## 实施结果（2026-08-05）

升级完成：`flutter analyze` 0 issues、全量测试 304/304 绿（覆盖率 52.03%）。与原设计的差异与决策落地：

- **drift 停在 2.34.3（2.x 最新）**：`pub upgrade` 实际解析到 2.34.3（drift 3.x 未进入解析结果），「回退最新 2.2x」的分支未触发，按最新 2.x 落地
- **riverpod 保持 2.6.1**：riverpod 3 破坏面大，作为独立迁移项后续单独评估（`flutter pub outdated` 遗留 major 之一）
- **sqlite3 3.x 经 native-assets hooks 提供原生库**：`sqlcipher_flutter_libs` 0.7.0+eol / `sqlite3_flutter_libs` 0.6.0+eol 变为占位包（0.7.0+eol 非「drift_flutter 0.3 强制」，实际是 sqlite3 3.x 迁移要求 hooks 占位包留在依赖图）；SQLCipher 加密改由 pubspec `hooks.user_defines.sqlite3.source: sqlcipher` 提供
- **FK 行为变化**：drift 2.34.5 codegen 为表生成 REFERENCES 约束，`PRAGMA foreign_keys = ON` 仅对新建库生效（既有 v6 库无 REFERENCES 不约束），删除父行在有子行时被 RESTRICT 拒绝
- **`flutter pub outdated` 遗留 major 仅**：riverpod 3（独立迁移）、sqlite 库（0.7.0+eol/0.6.0+eol 已 EOL，占位包），均为已记录项
