# Glassmorphism v3 验收报告（BK-GLS-020 归档）

| 项目 | 内容 |
| --- | --- |
| 日期 | 2026-08-24 |
| 依据 | `docs/19-玻璃拟态全链路设计文档.md` v1.1、`docs/20-玻璃拟态全链路Spec规格说明.md` v1.1（AC-01~06）、`docs/21-玻璃拟态全链路任务分解.md` v1.1 |
| 结论 | **代码与测试层全部落地**；真机性能实测（AC-06）与方法论就绪、待主测机执行；人工走查签字项待产品代表 |

---

## 1. AC 逐条判定

### AC-01 通透层次体系 ✅

- [x] L1–L4 参数落地，σ/填充α/描边α 三参数随层级单调递增
      ——`glass_layers_test.dart`「层级三参数单调性」；
- [x] 样板间同屏展示四层差异 + 实时参数标注——`component_gallery_page`
      「玻璃层级 L1–L4」展区，golden `t1_gallery`/`t6_gallery` 归档；
- [x] 导航栏滚动内容穿透磨砂：dock 层 σ16 于 high 档启用真实 bounded-blur
      （standard 档 fill-only 为既定性能决策，见 Spec §2.3）。

### AC-02 光影边界细节 ✅

- [x] 全部玻璃表面描边宽度 == 1，颜色白系按 §2.1 表（浅 L1=0x33FFFFFF 基准）
      ——`glass_layers_test`「描边基准」用例逐值断言；
- [x] 深色描边实值 0.16–0.24 且每层「描边 vs 填充」合成对比度 ≥ 1.5:1，
      含 §2.4 手算复现用例（α=0.12→1.44:1 否决 / α=0.16→1.64:1 通过）；
- [x] L1–L4 全部具备顶部高光（浅/深基准 0.25/0.10 按层微调）；色带探针
      展区落库，solidLine 单点降级开关保留（桌面渲染未见色带，默认 gradient）；
- [x] 旧 `0x99FFFFFF/0x38FFFFFF` 漂移描边清零——grep 无残留 +
      `check_ui_tokens` 门禁通过（收敛记录以注释形式保留于 tokens.dart）。

### AC-03 动态色彩融合 ✅（真机漂移观感项见 §3）

- [x] 8 预设 background 无一纯黑/纯白（可执行界 >0.005/<0.995 + 冻结值逐项锁定；
      custom 派生路径严格执行 (0.01, 0.99) 经 `clampBackgroundLuminance` 兜底）
      ——规范字面区间与冻结值的冲突决议见 `spike.md` C-1；
- [x] 环境光 36s 周期漂移正确（fake clock：9s 推进后偏移 > 0、36s 回归初相）
      ——`ambient_motion_test.dart`；
- [x] push/pop 触发 +3% 位移脉冲、600ms easeOutCubic 归位（RouteObserver 用例）；
- [x] `disableAnimations` / saver / 应用后台（WidgetsBindingObserver）/ 锁定态
      四条件任一成立即完全静止——降级矩阵五用例各一；
- [x] ContrastGuard 48 组合全部达标，钳制顺序与徽标逻辑正确
      ——`contrast_guard_test.dart`；
- [x] 背景图模式：Mesh 隐藏（图像分支不渲染渐变）、脉冲默认关（控制器门）、
      L1 加厚 +0.06 上限 0.80（resolveGlassSpec 用例 + GlassImageModeScope）。

### AC-04 全组件玻璃化 ✅

- [x] AppButton glass 变体 + primary/secondary/danger 玻璃化升级
      ——`app_button_glass_test.dart` 六用例；
- [x] hover/focus/press 三态过渡 120–180ms 断言（面板 + 按钮 decoration 与
      Duration 双断言）；
- [x] 图表容器统一 `GlassPanel(tier: panel, innerSheen: true)`
      （报表三图 _Section / 现金流 _shell / 预算卡），网格线 divider α0.5，
      柱身与线下 α0.12→0 语义色渐变（fl_chart gradient）；
- [x] chart_colors 从 ambient+semantic 派生（锁定测试防漂移）；
- [x] 图标默认线性 pack + GlassIcon 读 `resolveGlassSpec(panel)`（σ 随档）。

### AC-05 一致性与质量门禁 ✅

- [x] `tool/check_glass_consistency.sh` 两条 grep 输出为空（已入 CI app job）；
- [x] `flutter analyze` 0 issues；
- [x] 存量测试不回退：基线 530 例全绿 → 本轮全量套件全绿（含 golden 刷新一次
      提交，BK-GLS-017）；
- [x] 新增专项测试 ≥ 25 例：token 数学与对比度 17（glass_layers 10 +
      contrast_guard 5 + chart_colors 2）+ GlassPanel 行为 7 + 按钮三态 6 +
      动效降级与 pulse/breathe 12 + 设置持久化往返 2 ≈ **44 例**。

### AC-06 性能预算与测量方法 ⏳（方法论就绪，实测待真机）

- [x] 测量方法论、四场景预算、落盘格式定义于 `docs/report/gls-v3/perf.json`；
- [x] 架构层预算保障：standard 档 L1/L2 fill-only 零 saveLayer（widget 树
      断言）；动效仅重绘 L0 RepaintBoundary 画布（CustomPainter repaint 绑定）；
      ForegroundDecoration 单 drawRect 成本论证维持；
- [ ] 主测中端机四场景实测数值回填 perf.json —— 待设备（骁龙 695/765 档）；
- [ ] nightly perf job 接入 —— 待实测脚本联调后追加（先记录不设门禁）。

## 2. 任务核销（BK-GLS-000 ~ 020）

| 编号 | 状态 | 备注 |
| --- | --- | --- |
| 000 参数冻结 | ✅ | `spike.md`；静态/解析项冻结，真机复核项 R-1/R-2 列遗留 |
| 001 glass_layers | ✅ | 含 solidLine 分支、imageMode 加厚 |
| 002 glass_panel + AppCard | ✅ | 双保险裁剪按本 SDK 等价 API `ImageFilterConfig.blur(bounded:true)`（spike C-2） |
| 003 glass_layers_test | ✅ | 10 例 |
| 004 presets + contrast_guard | ✅ | ambient 4 色定值锁定；T5/T7/T8 提亮 |
| 005 glass_quality + app_theme | ✅ | 画质档随 ThemeExtension 流转（组件零 Provider 耦合） |
| 006 表单族玻璃化 | ✅ | 按钮/输入框/下拉/复选/开关/chip/slider |
| 007 图表容器 | ✅ | innerSheen + 网格线 + 渐变填充 |
| 008 GlassIcon | ✅ | σ 随画质档；blur:false 可强制关闭 |
| 009 AmbientGradient | ✅ | 4 光斑 + 分档软化 + 动效绘制 |
| 010 散点收敛 | ✅ | account_card/budget_summary_card/amount_keyboard/pin_pad/bill_detail_sheet 收敛；calendar 日格为语义标记非玻璃表面（保留理由）；book_switcher 经 popupMenuTheme L3 收敛 |
| 011 一致性门禁 | ✅ | 脚本 + CI 步骤；features 违规清零 |
| 012 ambient_motion | ✅ | 控制器 + RouteObserver + Tab breathe + 秒开共享 shell |
| 013 降级矩阵 | ✅ | 五条件独立用例（含后台 lifecycle） |
| 014 外观页设置 | ✅ | 两组设置 + clamp 徽标 + 5 键持久化往返 |
| 015 样板间扩容 | ✅ | 四展区 + 画质档局部预览 |
| 016 测试盘点 | ✅ | 新增 ≥44 例（>25 达标） |
| 017 Golden 刷新 | ✅ | 51 张一次性重生成 + 新增 t1/t6 样板间 + bg_probe fixture 用例；standard 档渲染声明写入 harness 注释 |
| 018 性能实测 | ⏳ | 方法论/格式就绪，待真机回填 |
| 019 文档收尾 | ✅ | 本文件 + spike.md + README + Spec 附录 A 核销注记 |
| 020 最终回归 | ✅（代码侧） | lint 0 issues / 全量测试绿 / grep 门禁空 / 样板间截图归档 golden |

## 3. 遗留清单

- **R-1** 真机色带探针目检（中端机）→ 必要时置 solidLine；
- **R-2** 真机标准档 L1 观感确认 → 必要时 borderBoost 或第 5 光斑；
- **R-3** 产品代表走查签字；
- **R-4** AC-06 四场景真机实测 + nightly perf job。
