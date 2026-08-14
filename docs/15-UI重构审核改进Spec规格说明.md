# 15 - UI 重构审核改进 Spec 规格说明（14 审核不符合项修复）

| 项目 | 内容 |
| --- | --- |
| 文档编号 | BK-DOC-15 |
| 版本 | v1.0 |
| 日期 | 2026-08-12 |
| 状态 | 实施中（BK-A-001~008 completed；BK-A-009 blocked 待真机；BK-A-010 completed） |
| 审核依据 | `docs/14-UI重构审核报告.md`（不符合项 #1–#8） |
| 关联文档 | `docs/09-UI设计文档-主题与视觉体系.md`、`docs/10-UI重构Spec规格说明.md`、`docs/11-UI重构任务分解.md`、`docs/13-UI重构验收报告.md` |
| 任务拆解 | `docs/16-UI重构审核改进任务分解.md` |
| 适用范围 | `app/`（Flutter SDK `^3.12.0`，Riverpod 2.6，Drift） |

---

## 1. 背景

14 审核报告对 UI 重构（BK-UI-001~018）完成情况逐项核对，结论为"总体符合度高"，但识别出 1 个 P0 功能缺陷、2 个 P1 问题、5 个 P2 偏差及 2 处文档状态不一致。本 Spec 将上述发现转化为可执行的修复方案，任务拆解见 16 文档（BK-A-001 ~ BK-A-010）。

**问题编号约定**：沿用 14 报告 §4 表格编号（#1~#8），本 Spec 各节以 `F1`~`F8` 引用。

## 2. 改进建议总览（按维度分类）

### 2.1 代码重构建议

| 编号 | 建议 | 对应问题 |
| --- | --- | --- |
| R1 | 背景图文件解析统一收口：新增 `backgroundImageFileProvider`（FutureProvider\<File?\>），渲染侧（AppBackground / 外观页预览）一律消费解析后的绝对路径 `File`，消除"写盘绝对路径 / 读图相对路径"的双轨 | F2 |
| R2 | 外观页选图入口状态机化：`imagePath == null`（未选图）/ `enabled == false`（已选未开）/ 已启用 三态分别渲染明确的主操作按钮，消除条件块嵌套造成的入口死锁 | F1 |
| R3 | 残留原生按钮（FilledButton/OutlinedButton，5 个文件 9 处）收敛至 AppButton 四变体，保持"同种交互全应用只有一个实现"（设计原则 4） | F4 |
| R4 | widget 测试禁止绕过 UI 直调 controller 模拟用户旅程；选图用例改为"点击按钮 → fake service 返回 → 断言 UI 态"的真实交互路径 | F1 |

### 2.2 安全性增强措施

| 编号 | 建议 | 对应问题 |
| --- | --- | --- |
| S1 | 备份范围收口：`_excludedMetaPrefixes` 增加 `'bg_'`，背景偏好键不进入加密备份、不跨设备恢复（Spec §8"备份范围勿扩大"）；补回归用例防回退 | F6 |
| S2 | 背景图导入增加体积护栏：源文件 > 20MB 时拒绝并提示（解码炸弹防护，补充既有 1920px 分辨率上限） | 新增（审核延伸） |
| S3 | 脏数据防线复核：`manualAlpha` 非法值回退默认已有用例 ✓；本次补 `bg_overlay_mode` 非法值用例，保持解析层全键兜底 | F6 配套 |

### 2.3 架构优化方案

| 编号 | 建议 | 对应问题 |
| --- | --- | --- |
| A1 | 静态卡点升级：lint 范围由 `lib/features/` 扩至全 `lib/`；正则增加 8 位 ARGB 字面量模式（`0x[0-9A-Fa-f]{8}`）覆盖常量列表绕过缺口；Token/主题定义文件与取色器 hue 色带走白名单登记（文件 + 理由） | F5 |
| A2 | 秒开入口与主入口统一 builder 链：ThemeTransition + AppBackground 上提为共用函数，秒开分支不再裸用 `lockGateBuilder`（待 D1 决策确认范围） | F7 |
| A3 | 文档状态治理：任务状态以"代码完成 / 真机完成"两层标记，杜绝"待真机"任务标 done 的状态漂移 | F8 |

### 2.4 性能改进策略

| 编号 | 建议 | 对应问题 |
| --- | --- | --- |
| P1 | 选图生效链路预缓存：`pickAndApply` 落盘后对目标文件 `precacheImage`，压缩首屏解码抖动，支撑 ≤800ms 指标达成 | F8（真机验证前置优化） |
| P2 | 背景层既有性能设计复核确认：RepaintBoundary 隔离、cacheWidth 限解码、模糊可关——真机 profiling 时逐项对照 Spec §8 指标记录实测值 | F8 |
| P3 | 真机性能验收基线化：切换 ≤100ms / 选图 ≤800ms / 包体增量 ≤300KB 三项实测值回填 13 报告 §4，形成后续回归基线 | F8 |

## 3. 问题分类与优先级排序

| 优先级 | 编号 | 问题 | 影响 | 任务 |
| --- | --- | --- | --- | --- |
| P0 | F1 | 外观页首次选图无 UI 入口（`imagePath == null` 时开关禁用、"更换图片"不渲染，功能死锁；集成测试步骤②必败） | 背景系统核心流程对用户不可用 | BK-A-001 / BK-A-002 |
| P1 | F2 | 背景图渲染用相对路径（写盘绝对、读图相对），真机 CWD 不可靠，可能静默不显示（errorBuilder 吞错，遮罩仍生效，故障隐蔽） | 真机背景功能高风险 | BK-A-003 |
| P1 | F3 | ThemeSettings 旧键兼容迁移单测缺失（Spec §9 强制；13 报告声称已覆盖，与事实不符） | 升级兼容路径零保护 | BK-A-004 |
| P2 | F4 | 原生按钮残留 5 文件 9 处（budget_edit_sheet×3、backup_page×4、books_page、account_sync_section、recurring_page） | 组件化一致性缺口 | BK-A-005 |
| P2 | F5 | lint 仅覆盖 features/、正则只匹配 `Color(0x…)` 字面量，常量列表模式可绕过 | 裸值防线有缺口 | BK-A-006 |
| P2 | F6 | `bg_*` 键随 app_meta 进入备份并可跨设备恢复（Spec §8"勿扩大"） | 隐私边界 + 恢复后悬空态 | BK-A-007 |
| P2 | F7 | 秒开模式入口未包 AppBackground/ThemeTransition | 背景观感不一致（边界场景） | BK-A-008 |
| P2 | F8 | BK-UI-017/018 真机环节未执行但标 done；性能三指标未验证 | 验收证据链不完整 | BK-A-009 / BK-A-010 |

## 4. 修复方案与技术实现细节

### 4.1 F1（P0）：首次选图入口修复

**现状/根因**：`appearance_page.dart` `_BackgroundSection.build()` 中"更换图片 / 恢复默认"按钮行被包在 `if (imagePath != null)` 条件块内（442 行），而未选图时 `SwitchListTile.onChanged` 为 `null`（禁用）——两条路径均不可达 `pickAndApply()`。

**方案**（对应 R2）：
1. `_BackgroundSection` 按三态渲染主操作区：
   - `imagePath == null`：渲染 `AppButton.primary(block: true)`「选择背景图片」→ `_pickAndApply`；开关保持禁用并保留提示文案；
   - `imagePath != null && !enabled`：渲染「更换图片」+「恢复默认」（现状逻辑不变），开关可用；
   - `enabled`：现状不变（遮罩/模糊控制区）。
2. `_BackgroundPreview` 在未选图态渲染占位（surfaceVariant 底 + 图标 + 「未设置背景」文案），点击等同「选择背景图片」。
3. widget 测试改造（R4）：`appearance_page_test.dart` 选图用例删除 `tester.runAsync(controller.pickAndApply)` 直调，改为 `tester.tap(find.text('选择背景图片'))` 驱动真实链路（fake `BackgroundService` 注入不变；异步文件 IO 仍在 `runAsync` 内 pump，但触发点必须是按钮）。

**涉及文件**：
- `app/lib/features/settings/appearance_page.dart`（改）
- `app/test/widget/appearance_page_test.dart`（改）
- `app/integration_test/background_test.dart`（步骤①后新增"选择背景图片"点击断言，改）

**验收**：全新状态（无 `bg_*` 键）下可通过 UI 完成选图；集成测试步骤②通过；widget 用例无 controller 直调。

### 4.2 F2（P1）：背景图读取绝对路径化

**现状/根因**：`BackgroundService.importImage()` 写盘用 `getApplicationDocumentsDirectory()` 绝对路径；`AppBackground`（109 行）与外观页预览（551 行）用 `File(imagePath)`（相对路径 `background/bg.png`）。dart:io 相对路径按进程 CWD 解析，Android/iOS 上 CWD 无保证。

**方案**（对应 R1）：
1. `background_controller.dart` 新增：
   ```dart
   /// 当前背景图文件（绝对路径解析；未启用/文件缺失返回 null）
   final backgroundImageFileProvider = FutureProvider<File?>((ref) async {
     final settings = ref.watch(backgroundControllerProvider.select((s) => s.valueOrNull));
     final imagePath = settings?.imagePath;
     if (settings == null || !settings.enabled || imagePath == null) return null;
     return ref.read(backgroundServiceProvider).resolveImageFile(imagePath);
   });
   ```
2. `AppBackground.build` 与 `_BackgroundPreview` 改为 watch 该 provider；`null` 时按"无背景图"分支渲染（现状已有该分支，行为收敛一致）。
3. `clear()`/`pickAndApply()` 中 invalidate 该 provider（与 `backgroundLuminanceProvider` 同步失效）。
4. 单元/widget 测试：补"相对路径键值经 provider 解析为绝对路径且文件存在"用例（利用 `path_provider` 夹具 tempDir）。

**涉及文件**：
- `app/lib/shared/theme/background/background_controller.dart`（改）
- `app/lib/shared/theme/background/app_background.dart`（改）
- `app/lib/features/settings/appearance_page.dart`（预览处，改）
- `app/test/widget/app_background_test.dart`（补用例）

**验收**：渲染链路不再出现相对路径 `File(`；既有 5 个 AppBackground 用例保持通过；新增解析用例通过。

### 4.3 F3（P1）：兼容迁移测试补齐

**方案**：
1. `theme_settings_test.dart` 新增用例「旧用户升级：仅存在 theme_seed/theme_mode 旧键 → presetId='custom'，seedColor/mode 按旧键还原」——直接写 app_meta 旧键后读 `themeSettings()`。
2. 新增「presetId 读写往返：applyPreset('t3') 持久化后重读一致」。
3. 新增「脏数据兜底：theme_preset_id 为非法值（如 't99'）→ `isCustom == true` 兜底」（对应 `ThemeSettings.preset` 的防脏设计）。

**涉及文件**：`app/test/unit/features/theme/theme_settings_test.dart`（改）

**验收**：3 个新用例通过；迁移路径（`settings_repository.dart:61`）被断言覆盖。

### 4.4 F4（P2）：原生按钮收敛

**方案**（对应 R3）：逐文件替换并核对视觉变体映射：

| 文件 | 残留 | 替换映射 |
| --- | --- | --- |
| `budget_edit_sheet.dart` | FilledButton×2（130/211）、OutlinedButton×1（217） | 主操作→`AppButton.primary(block:)`；危险（删除）→`AppButton.danger`；次要→`AppButton.secondary` |
| `backup_page.dart` | FilledButton.icon/.tonalIcon×4（145/161/177/202） | 主→primary、tonal→secondary（icon 并入 child Row） |
| `books_page.dart` | FilledButton×1（117） | → `AppButton.primary` |
| `account_sync_section.dart` | FilledButton.icon×1（140） | → `AppButton.primary`（loading 态接入 `loading:` 参数防重入） |
| `recurring_page.dart` | FilledButton×1（321） | 按语义映射 primary/danger |

注意：外观页自定义 sheet 的 `OutlinedButton.icon`（自定义颜色入口）属既有迁移内代码，一并收敛为 `AppButton.secondary`。

**涉及文件**：上表 5 个 + `appearance_page.dart`（1 处）；相关 widget 测试断言同步更新。

**验收**：`grep -rn "FilledButton\|OutlinedButton(" lib/features lib/shared` 零残留（SegmentedButton 除外）；受影响页面 widget 测试通过；Golden 基线若变化按 0.5% 容差审查后 `--update-goldens` 重建。

### 4.5 F5（P2）：静态卡点升级

**方案**（对应 A1）：
1. `tool/check_ui_tokens.dart`：
   - 扫描根由 `lib/features` 改为 `lib/`；
   - 规则表新增 `(RegExp(r'0x[0-9A-Fa-f]{8}\b'), 'ARGB 字面量 → 改用 palette/语义色')`（8 位模式精准命中颜色常量，不误伤 `0x2D` 类短 hex）；
2. 白名单登记（随规则提交，逐条注明理由）：
   - `shared/theme/theme_presets.dart` / `app_theme.dart` / `theme_settings.dart` / `tokens.dart` —— Token/主题定义文件（设计文档 §6.4 豁免语义）；
   - `shared/theme/color_picker_dialog.dart` hue 色带 7 色 —— HSV 取色器功能必需常量；
   - `features/categories/category_edit_sheet.dart` `_palette` —— 分类业务数据色（用户可选色域，非 UI 装饰），登记后限期评估是否迁入 constants。
3. CI 无需改动（已调用同一脚本）。

**涉及文件**：`app/tool/check_ui_tokens.dart`（改）；白名单涉及文件仅注释登记。

**验收**：脚本全量扫描 `lib/` 通过（违规 0、白名单逐条有理由）；人为植入一处 `Color(0xFF…)` 于 features/ 与 shared/widgets/ 均被拦截（自测后回滚）。

### 4.6 F6（P2）：备份隐私收口

**方案**（对应 S1/S3）：
1. `backup_service.dart`：`_excludedMetaPrefixes` 增加 `'bg_'`（导出侧已按前缀过滤，见 50 行，改动一行）。
2. `backup_service_test.dart` 新增回归用例：「写入 `bg_enabled`/`bg_image_path` 后创建备份 → 恢复至新库 → `backgroundSettings()` 回退默认（enabled=false, imagePath=null）」。
3. `background_settings_test.dart` 补「`bg_overlay_mode` 非法值回退 auto」用例（S3）。

**涉及文件**：`app/lib/features/backup/backup_service.dart`、`app/test/unit/features/backup/backup_service_test.dart`、`app/test/unit/features/theme/background_settings_test.dart`

**验收**：新用例通过；既有备份 14 张表结构断言不受影响（app_meta 行数变化在用例内显式断言）。

### 4.7 F7（P2）：秒开入口背景一致性

**前置决策 D1**：09 设计文档 §5.1 约定背景作用于"五 Tab 主页面及二级页"，秒开直达的 `QuickEntrySheet` 未明确。本 Spec 决策：**纳入**——秒开页本质是全屏 sheet，底层透出背景与主流程观感连续；且 `AppBackground` 在无背景时零开销。

**方案**（对应 A2）：
1. `app.dart` 导出共用 builder：
   ```dart
   Widget appShellBuilder(BuildContext context, Widget? child) => ThemeTransition(
     child: AppBackground(child: lockGateBuilder(context, child)),
   );
   ```
2. `main.dart` 秒开分支 `builder: appShellBuilder`；主分支 builder 同步改调该函数（消除两处拼装）。
3. `app_smoke_test.dart` 增加秒开分支冒烟断言（可选）。

**涉及文件**：`app/lib/app.dart`、`app/lib/main.dart`、`app/test/widget/app_smoke_test.dart`

**验收**：两入口共用同一 builder 链；秒开模式下设置背景后 QuickEntrySheet 底层可见背景 + 遮罩。

### 4.8 F8（P2）：真机验证与文档治理

**方案**（对应 P1–P3、A3）：
1. 真机执行（Android/iOS 各 1 轮，前置：F1/F2 已修复）：
   - `flutter test integration_test/background_test.dart -d <device>` 全步骤通过；
   - 性能实测：主题切换重建耗时（profile 模式 timeline）、选图到生效端到端计时（含 P1 预缓存优化）、release 包体对比（基线 commit vs 当前）；
   - 五档亮度实图观感走查（极亮/亮/中调/暗/极暗各 1 张）。
2. 文档回填：
   - 13 报告 §4 表格"执行方式"列后补"实测结果"列；
   - 11 文档 BK-UI-017/018 状态按 A3 双层标记改为「代码 done / 真机 done」；
   - 14 报告不符合项 #1~#8 逐条标注修复 commit。

**涉及文件**：`docs/13-UI重构验收报告.md`、`docs/11-UI重构任务分解.md`、`docs/14-UI重构审核报告.md`（状态列回填）

**验收**：真机证据（测试输出 + timeline 截图 + 包体 diff）随 13 报告归档；文档状态与事实一致。

## 5. 涉及文件清单（汇总）

| 文件 | 改动 | 关联 |
| --- | --- | --- |
| `app/lib/features/settings/appearance_page.dart` | 改 | F1/F2/F4 |
| `app/lib/shared/theme/background/background_controller.dart` | 改 | F2 |
| `app/lib/shared/theme/background/app_background.dart` | 改 | F2 |
| `app/lib/features/backup/backup_service.dart` | 改（1 行） | F6 |
| `app/lib/features/budgets/budget_edit_sheet.dart` | 改 | F4 |
| `app/lib/features/backup/backup_page.dart` | 改 | F4 |
| `app/lib/features/books/books_page.dart` | 改 | F4 |
| `app/lib/features/settings/account_sync_section.dart` | 改 | F4 |
| `app/lib/features/recurring/recurring_page.dart` | 改 | F4 |
| `app/lib/app.dart` / `app/lib/main.dart` | 改 | F7 |
| `app/tool/check_ui_tokens.dart` | 改 | F5 |
| `app/test/widget/appearance_page_test.dart` | 改 | F1 |
| `app/test/widget/app_background_test.dart` | 改 | F2 |
| `app/test/unit/features/theme/theme_settings_test.dart` | 改 | F3 |
| `app/test/unit/features/backup/backup_service_test.dart` | 改 | F6 |
| `app/test/unit/features/theme/background_settings_test.dart` | 改 | F6 |
| `app/integration_test/background_test.dart` | 改 | F1/F8 |
| `docs/11-UI重构任务分解.md` / `docs/13-UI重构验收报告.md` / `docs/14-UI重构审核报告.md` | 状态回填 | F8 |

## 6. 验证与测试方案

| 层 | 用例/动作 | 关联问题 | 通过标准 |
| --- | --- | --- | --- |
| 单元 | 兼容迁移 3 用例（旧键→custom / presetId 往返 / 脏数据兜底） | F3 | 全绿 |
| 单元 | 备份排除 bg_* 回归 + overlay_mode 脏数据 | F6 | 全绿 |
| Widget | 首次选图真实交互路径（点击按钮驱动）；AppBackground 绝对路径解析 | F1/F2 | 全绿，且无 controller 直调残留 |
| Widget | 按钮收敛涉及的 5 个页面回归 | F4 | 全绿 |
| Golden | 按钮收敛后基线审查（容差 0.5%） | F4 | 差异均在容差内或评审后重建基线 |
| 静态 | 全 lib/ 扫描 0 违规；白名单逐条有理由；植入自测可拦截 | F5 | 退出码 0 |
| 集成（真机） | background_test 全步骤（含新增"选择背景图片"断言） | F1/F8 | Android/iOS 各 1 轮通过 |
| 性能（真机） | 切换 ≤100ms / 选图 ≤800ms / 包体增量 ≤300KB | F8 | 实测值回填 13 报告 |
| 人工 | 五档亮度实图观感 + 秒开模式背景观感 | F7/F8 | 走查记录归档 |

CI 卡点：`flutter analyze` + `dart run tool/check_ui_tokens.dart` + `flutter test --coverage` 保持既有链路，无需新增 workflow。

## 7. 实施进度追踪表

| 任务 | 问题 | 优先级 | 状态 | 验证 |
| --- | --- | --- | --- | --- |
| BK-A-001 | F1 首次选图入口 | P0 | completed | widget + 集成断言 |
| BK-A-002 | F1 选图测试真实路径化 | P0 | completed | widget 用例无直调 |
| BK-A-003 | F2 绝对路径化 | P1 | completed | 新增解析用例 |
| BK-A-004 | F3 迁移测试补齐 | P1 | completed | 3 新用例 |
| BK-A-005 | F4 按钮收敛 | P2 | completed | grep 零残留 + Golden |
| BK-A-006 | F5 lint 升级 | P2 | completed | 全 lib/ 0 违规 |
| BK-A-007 | F6 备份收口 | P2 | completed | 回归用例 |
| BK-A-008 | F7 秒开背景 | P2 | completed | 冒烟 + 走查（走查随真机） |
| BK-A-009 | F8 真机验证 | P2 | blocked（无设备） | 真机证据归档 |
| BK-A-010 | F8 文档回填 | P2 | completed | 状态一致 |

*状态实时同步维护于 `docs/16-UI重构审核改进任务分解.md`，以该文件为准。*

## 8. 风险与回退

| 风险 | 等级 | 缓解 |
| --- | --- | --- |
| F1/F2 修复触及背景链路，回归面集中 | 中 | 全部改动配套 widget/集成用例；真机验证（BK-A-009）前置依赖这两项完成 |
| 按钮收敛引起 Golden 漂移 | 低 | 0.5% 容差审查；超预期漂移逐张人工评审后重建基线 |
| lint 扩范围后历史存量集中暴露 | 低 | 白名单制过渡；存量逐条登记理由，新增零容忍 |
| 真机设备不可用导致 BK-A-009 阻塞 | 中 | 代码类任务（001~008）不依赖真机，可先全部收口；009 允许标 blocked 并记录阻塞条件 |
| 回退 | — | 全部为前端偏好/测试/工具链改动，无数据迁移；单项可按 commit 独立 revert |

---

*任务拆解、依赖与验收清单见 `docs/16-UI重构审核改进任务分解.md`。*
