# Flutter SDK 升级实现计划（3.24.5 → 3.44.8）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将项目从 Flutter 3.24.5（Dart 3.5）升级到 Flutter 3.44.8 stable（Dart 3.12.2），全部依赖升级到最新兼容版本，`flutter analyze` 零告警、`flutter test` 全绿。

**Architecture:** 两阶段提交。Stage 1（toolchain commit）= SDK + CI pin + 旧依赖下编译/测试通过所需的最小修复；Stage 2（deps commit）= 依赖升级 + 破坏性变更修复。本机 SDK 已装于 `/opt/flutter/flutter`（3.44.8）；Server 不涉及。迁移类任务无新功能，验证标准即 analyze 零告警 + 测试全绿（替代 TDD 红绿循环）。

**Tech Stack:** Flutter 3.44.8 / Dart 3.12.2 / drift 2.34 / fl_chart 1.2 / flutter_lints 6 / flutter_secure_storage 10 / local_auth 3 / intl 0.20 / Riverpod 2.6（保持）

**Spec:** `docs/specs/2026-08-05-flutter-upgrade-design.md`

---

### Task 0: 提交当前未提交的工作区改动

**Files:**
- 工作区现有 16 个已修改文件（drift_flutter pin、test 更新等）

- [ ] **Step 1: 审查当前 diff**

```bash
git status
git diff --stat
git diff app/pubspec.yaml app/test/widget/share_invite_sheet_test.dart   # 主要变化抽样
```

Expected: 16 个 M 文件；pubspec.yaml 为 `drift_flutter: 0.2.6` pin + 注释；测试文件含成员/邀请相关更新。

- [ ] **Step 2: 按 diff 实际内容提交为一个 commit**

```bash
git add -A   # 工作区仅含用户未提交改动与既有 M 文件
git commit -m "chore: 锁定 drift_flutter 0.2.6 兼容旧 Dart 解析器，补充测试"   # 消息以实际 diff 为准
```

Expected: 提交成功，`git status` 干净（除 .gitignore 忽略项）。

- [ ] **Step 3: 确认干净基线**

```bash
git status --short   # Expected: 空输出
git log --oneline -2
```

---

### Task 1: CI pin + SDK 约束 + pub get（toolchain 准备）

**Files:**
- Modify: `.github/workflows/ci.yml`（`flutter-version: '3.24.5' # 与 build.yaml 质量门禁保持一致` → `'3.44.8'`）
- Modify: `.github/workflows/nightly.yml`（同上，1 处）
- Modify: `.github/workflows/build.yaml`（3 处：quality / android / ios 作业，`flutter-version: '3.24.5'` → `'3.44.8'`，同步注释「与构建作业保持一致」）
- Modify: `app/pubspec.yaml`（`sdk: '>=3.3.0 <4.0.0'` → `sdk: '^3.12.0'`）

- [ ] **Step 1: 更新 3 个 workflow 的 flutter-version**

```bash
cd /root/workspace/bookkeep
grep -rn "3.24.5" .github/workflows/   # Expected: 共 5 处（ci 1 + nightly 1 + build 3）
```

逐个替换为 `'3.44.8'`，注释文字同步（若注释含版本号）。

- [ ] **Step 2: 更新 pubspec SDK 约束**

`app/pubspec.yaml` 中：
```yaml
environment:
  sdk: '^3.12.0'
```

- [ ] **Step 3: 检查 iOS Podfile 最低平台（对齐 3.44.8 模板）**

```bash
grep -n "platform :ios" /root/workspace/bookkeep/app/ios/Podfile
# 对比模板：grep -n "platform :ios" /opt/flutter/flutter/packages/flutter_tools/templates/app_shared/ios.tmpl/Podfile.tmpl
```

若模板最低版本高于 `13.0`，更新 `app/ios/Podfile` 的 `platform :ios`；否则保持不动。改动计入本 commit。

- [ ] **Step 4: pub get 重建 lock（新 SDK 下 sky_engine 重新解析）**

```bash
cd /root/workspace/bookkeep/app && /opt/flutter/flutter/bin/flutter pub get
```

Expected: 成功；`pubspec.lock` 中 `sky_engine`/`flutter` SDK 版本更新到 3.44.8。已知：旧 lock 的 sky_engine 0.0.99 与新 SDK 不匹配（`pub outdated` 曾报 `Package not available`），pub get 修复此问题。

---

### Task 2: 旧依赖下编译 + 测试验证（toolchain 绿）

**Files:**
- Modify: 3 个 withOpacity 文件（若报错）：`lib/shared/widgets/category_picker.dart`、`lib/features/budgets/budget_progress_bar.dart`、`lib/features/calendar/cashflow_chart.dart`

- [ ] **Step 1: flutter analyze 摸底**

```bash
cd /root/workspace/bookkeep/app && /opt/flutter/flutter/bin/flutter analyze
```

Expected 结果分三类，按下列顺序处理：
1. **编译错误（removed API）**：如 `withOpacity` 已被移除 — 就地最小修复（见 Step 2），不改依赖。
2. **flutter_lints 4 与新 analyzer 不兼容**（如「unknown lint」告警或 error）：将 `flutter_lints` 升到 `^6.0.0` 并修复其违规（并入本任务，保证 toolchain commit 质量门禁绿）。
3. **旧依赖在新 SDK 下的编译失败**（如 drift 2.20 生成代码不兼容 Dart 3.12）：将对应依赖升级并入本任务（commit 边界相应调整，commit message 注明）。

- [ ] **Step 2: 修复已移除 API（最小改动）**

`withOpacity` → `withValues(alpha:)`（若 analyzer 仍报 deprecated 也一并修）：

```dart
// 旧：color.withOpacity(0.5)
// 新：color.withValues(alpha: 0.5)
```

- [ ] **Step 3: flutter analyze 收敛**

```bash
flutter analyze
```

Expected: 0 issues（或仅剩明确记录在案的已知项）。如第 1 类之外仍有大量依赖相关错误，回到 Step 1 决策。

- [ ] **Step 4: flutter test**

```bash
flutter test
```

Expected: 全绿（计数与升级前一致或注明差异）。若旧 drift 生成代码在测试编译失败 → 按 Step 1 第 3 类处理。

- [ ] **Step 5: 提交 toolchain commit**

```bash
git add .github/workflows/ app/pubspec.yaml app/pubspec.lock <本次修复的 lib 文件>
git commit -m "chore: upgrade Flutter SDK 3.24.5 → 3.44.8（Dart 3.12.2），同步 CI pin"
```

Expected: 提交成功；`git status --short` 只剩 Stage 2 文件（如有）。

---

### Task 3: pubspec 约束升级 + pub get（deps 准备）

**Files:**
- Modify: `app/pubspec.yaml`（约束批量更新）
- Modify: `app/pubspec.lock`（pub get 生成）

- [ ] **Step 1: 更新依赖约束（精确编辑 pubspec.yaml）**

```yaml
dependencies:
  flutter_riverpod: ^2.6.1        # 保持！riverpod 3 为独立迁移（见风险）
  drift: ^2.34.3
  drift_flutter: ^0.3.1            # 移除 0.2.6 pin 及「0.2.7 要求 drift >=2.24…」注释
  sqlcipher_flutter_libs: ^0.6.0   # 保持：0.7.0+eol 为 EOL 版本，不升
  sqlite3_flutter_libs: ^0.5.24    # 保持：0.6.0+eol 为 EOL 版本，不升
  flutter_secure_storage: ^10.3.1
  local_auth: ^3.0.2
  fl_chart: ^1.2.0
  table_calendar: ^3.2.0
  cryptography: ^2.9.0
  intl: ^0.20.3
  path_provider: ^2.1.6
  http: ^1.6.0
  uuid: ^4.6.0

dev_dependencies:
  flutter_lints: ^6.0.0
  drift_dev: ^2.34.5
  build_runner: ^2.16.0
  mocktail: ^1.0.5
  sqlite3: ^3.5.1   # 若与 drift 2.34 测试栈冲突则保持 2.x，由解析器决定
```

- [ ] **Step 2: pub get**

```bash
cd /root/workspace/bookkeep/app && /opt/flutter/flutter/bin/flutter pub get
```

Expected: 解析成功。若解析冲突（如 sqlite3 3.x 与 drift 约束冲突），按 Step 1 备注降级调整后重试。

- [ ] **Step 3: 记录实际解析版本**

```bash
flutter pub deps --style=compact | head -30
```

Expected: drift 2.34.x、fl_chart 1.2.x、flutter_lints 6.x、secure_storage 10.3.x 等。将实际版本记入 commit message。

---

### Task 4: 重新生成 drift 代码 + schema 校验

**Files:**
- Regenerate: `lib/data/local/database.g.dart`、`lib/data/local/tables/**`
- Modify: 无（表结构不变）

- [ ] **Step 1: build_runner 全量生成**

```bash
cd /root/workspace/bookkeep/app && /opt/flutter/flutter/bin/dart run build_runner build --delete-conflicting-outputs
```

Expected: 成功，无冲突；.g.dart 重新生成。

- [ ] **Step 2: schema 版本校验（迁移链不得变动）**

```bash
grep -n "schemaVersion" lib/data/local/database.dart   # Expected: => 6
git diff --stat lib/data/local/                          # .g.dart 差异属代码生成产物变化，可接受
```

Expected: `schemaVersion` 仍为 6；无表结构改动；迁移链文件（如有）零改动。

- [ ] **Step 3: 生成产物编译检查**

```bash
/opt/flutter/flutter/bin/dart analyze lib/data 2>&1 | tail -5
```

Expected: 无 error（drift 2.34 codegen 与旧生成代码 API 差异会在 analyze 阶段暴露，属于 Task 5 修复范畴）。

---

### Task 5: 修复破坏性变更（analyzer 驱动，迭代至零告警）

**Files:**
- Modify: `lib/features/calendar/cashflow_chart.dart`、`lib/features/reports/charts/report_charts.dart`、`lib/features/reports/reports_page.dart`（fl_chart 1.x）
- Modify: `lib/core/security/key_store.dart`（secure_storage 10.x）
- Modify: `lib/features/auth_lock/biometric.dart`（local_auth 3.x）
- Modify: `lib/shared/widgets/category_picker.dart`、`lib/features/budgets/budget_progress_bar.dart`、`lib/features/calendar/cashflow_chart.dart`（withOpacity，若 Stage 1 未修）
- Modify: 其他 analyzer 指出的 lint 违规文件

- [ ] **Step 1: analyze 全量摸底**

```bash
cd /root/workspace/bookkeep/app && /opt/flutter/flutter/bin/flutter analyze 2>&1 | tee /tmp/analyze1.txt
```

Expected: 错误清单分四类：deprecation（Flutter 自带提示含迁移路径）、fl_chart 1.x API、secure_storage/local_auth 3.x API、flutter_lints 6 新规则。错误消息会给出替换建议（如 `'withOpacity' is deprecated: Use withValues(alpha:)`），逐条照做。

- [ ] **Step 2: 按文件批量修复（每类一提交粒度）**

fl_chart 1.x（3 个文件）：按 analyzer 的 deprecation 提示替换（如 tooltip 配置 getter 化等）；图表行为不得改变。
secure_storage 10（key_store.dart）：`read/write` 调用点 API 变化按提示修复；key 名与存储语义不变。
local_auth 3（biometric.dart）：API 变化按提示修复；认证流程行为不变。
flutter_lints 6 违规：按规则修复（如多余 const、未使用参数等），不引入行为变化。

```bash
flutter analyze   # 每修一批跑一次，直到 0 issues
```

- [ ] **Step 3: 收敛断言**

```bash
flutter analyze 2>&1 | tail -3
```

Expected: `No issues found!`

- [ ] **Step 4: 抽查行为一致性（图表/锁屏/认证三个敏感点）**

```bash
flutter test test/widget/ 2>&1 | tail -5    # widget 测试覆盖的交互路径
```

Expected: 通过（具体测试文件以仓库实际为准：share_invite_sheet_test、voice_entry_sheet_test 等）。

---

### Task 6: 测试全绿

**Files:**
- Modify: `app/test/**`（如行为性断言受依赖升级影响）

- [ ] **Step 1: 全量测试**

```bash
cd /root/workspace/bookkeep/app && /opt/flutter/flutter/bin/flutter test
```

Expected: 全绿。失败项逐一定位：优先确认是断言受新依赖行为影响（如 fl_chart 序列化/格式），还是测试本身用了被移除 API（如旧 mocktail 写法）— 前者更新断言，后者按新 API 重写。

- [ ] **Step 2: 覆盖率基线（CI 同款命令）**

```bash
flutter test --coverage
```

Expected: 通过；覆盖率与升级前基线对比（CI 无 app 覆盖率硬门槛，仅记录）。

- [ ] **Step 3: 提交 deps commit**

```bash
git add app/pubspec.yaml app/pubspec.lock lib/ test/
git commit -m "chore: upgrade dependencies for Flutter 3.44.8（drift 2.34 / fl_chart 1.2 / secure_storage 10 / local_auth 3 / lints 6）"
```

Expected: 提交成功。

---

### Task 7: 最终验证 + 交接

- [ ] **Step 0: 约束检查（自始至终适用）**

全程**不对全库跑 `dart format`**（Dart 3.12 矮胖风格 formatter 会产生巨大 diff）；只格式化实际修改的文件或不动格式。

- [ ] **Step 1: 终态验证**

```bash
cd /root/workspace/bookkeep/app && /opt/flutter/flutter/bin/flutter analyze && /opt/flutter/flutter/bin/flutter test
git -C /root/workspace/bookkeep status --short
```

Expected: 0 issues、全绿、工作区干净。

- [ ] **Step 2: pub outdated 终检**

```bash
/opt/flutter/flutter/bin/flutter pub outdated 2>&1 | tail -15
```

Expected: 遗留 major 仅限已记录项：flutter_riverpod 3.x（独立迁移）、sqlite3（dev，按解析结果）、+eol 的 sqlite 库（有意不升）。

- [ ] **Step 3: 更新设计文档状态**

`docs/specs/2026-08-05-flutter-upgrade-design.md`：drift 未出 3.x（实际 2.34.3）→ 回退分支未触发；记录 riverpod 3 为后续项。提交为 docs commit（并入 deps commit 或单独 commit，二选一）。

- [ ] **Step 4: 交接说明（写给用户）**

- 本机无 Android/iOS 工具链：APK/AAB/IPA 构建、集成测试由升级后的 CI workflow 承担（push/tag 触发 build.yaml，nightly 跑 integration_test）
- 若 CI 出现与本地不一致的告警（如新版 flutter_lints 在 CI 的 analyzer 版本差异），按 analyze 输出就地修复
- riverpod 3 迁移建议单独开任务（25 个文件使用面）

---

## 风险与决策记录

| 决策点 | 结论 | 触发条件 |
|---|---|---|
| drift 出 3.x？ | 未发生（最新 2.34.3，仍 2.x），设计文档回退分支不触发 | — |
| riverpod 3.4.2 | 不升级，保持 ^2.6.1（25 文件使用面，属独立迁移） | — |
| sqlcipher_flutter_libs 0.7.0+eol / sqlite3_flutter_libs 0.6.0+eol | 不升（pub.dev 标记 EOL） | — |
| 旧依赖无法在新 SDK 编译 | 对应依赖升级并入 Stage 1 commit，消息注明 | Task 2 Step 1 触发 |
| flutter_lints 4 与新 analyzer 不兼容 | flutter_lints ^6.0.0 并入 Stage 1 | Task 2 Step 1 触发 |
| sqlite3 3.5.1 与 drift 测试栈冲突 | 保持 2.x | Task 3 Step 2 解析冲突 |
| 本机验证边界 | analyze + unit test 本地；integration/构建在 CI | 环境无 Android/iOS SDK |

## 涉及文件总览

- `.github/workflows/{ci,nightly,build}.yaml` — flutter-version pin（5 处）
- `app/pubspec.yaml` / `app/pubspec.lock` — SDK 约束 + 依赖
- `app/lib/features/calendar/cashflow_chart.dart`、`app/lib/features/reports/charts/report_charts.dart`、`app/lib/features/reports/reports_page.dart` — fl_chart 1.x
- `app/lib/core/security/key_store.dart` — secure_storage 10
- `app/lib/features/auth_lock/biometric.dart` — local_auth 3
- `app/lib/shared/widgets/category_picker.dart`、`app/lib/features/budgets/budget_progress_bar.dart` — withOpacity
- `app/lib/data/local/database.g.dart`、`app/lib/data/local/tables/**` — 重新生成（schema v6 不变）
- `app/test/**` — 按需修复
- `docs/specs/2026-08-05-flutter-upgrade-design.md` — 状态更新
