#!/usr/bin/env bash
# iOS 毛玻璃参数一致性门禁（FGDS v1.0，Spec 23 文档 §9 AC-01/02/06/08；
# BK-FG-040。取代 Glassmorphism v3 的同名旧脚本，CI 入口路径不变）。
#
# 五条 CI 可执行检查（任一输出违规即 fail）：
#   1. BackdropFilter 唯一出口——仅允许 shared/widgets/{glass_panel,glass_icon,
#      app_button}.dart（容器级组件；行级/表格/列表禁真模糊，AC-06）；
#   2. σ 字面量零散写——lib/ 内禁止 `sigma` 数值直写（必须引用
#      GlassLevel.blur / GlassButtonTokens.*，AC-01）；
#   3. 层级表取值合法性——blur 取值仅允许 Spec §3 {12,20,28,36,44} 与
#      §4.4 矩阵 {8,16,24}（在 glass_tokens.dart 单文件内核对）；
#   4. ambient / 光斑残留——代码级 ambient Token 访问、RadialGradient、
#      Mesh、背景图选图零容忍（AC-02；文档注释中的「已拆除」说明不判违）；
#   5. 旧系统 API 残留——GlassTier/glassFill*/glassBorder/ContrastGuard/
#      AmbientMotion/AmbientGradient 零引用（AC-08）。
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

echo "== 门禁 1：BackdropFilter 唯一出口（AC-06 行级禁真模糊）=="
violations=$(grep -rn "BackdropFilter(" app/lib --include="*.dart" \
  | grep -v "shared/widgets/glass_panel.dart\|shared/widgets/glass_icon.dart\|shared/widgets/app_button.dart" || true)
if [ -n "$violations" ]; then
  echo "$violations"
  echo "FAIL: 存在玻璃出口之外的 BackdropFilter（唯一合法处：widgets/glass_panel.dart、glass_icon.dart、app_button.dart）"
  fail=1
else
  echo "OK: 无违规"
fi

echo "== 门禁 2：σ 字面量零散写（AC-01 参数单源）=="
violations=$(grep -rnE "sigma(X|Y)?:\s*[0-9]" app/lib --include="*.dart" || true)
if [ -n "$violations" ]; then
  echo "$violations"
  echo "FAIL: σ 必须引用 glass_tokens.dart（GlassLevel.blur / GlassButtonTokens），禁止字面量"
  fail=1
else
  echo "OK: 无违规"
fi

echo "== 门禁 3：层级表取值合法性（Spec §3 {12,20,28,36,44} + §4.4 {8,16,24}）=="
# G1–G5 层级 blur 表（仅取 `=> N` 值）
level_blurs=$(awk '/double get blur =>/,/};/' app/lib/shared/theme/glass_tokens.dart | grep -oE "=> [0-9]+" | grep -oE "[0-9]+" | sort -u)
level_bad=$(echo "$level_blurs" | grep -vE "^(12|20|28|36|44)$" || true)
# FG-BTN 状态矩阵 blur 常量
btn_blurs=$(awk '/abstract final class GlassButtonTokens/,/^}/' app/lib/shared/theme/glass_tokens.dart \
  | grep -oE "blur[A-Za-z]* = [0-9]+" | grep -oE "[0-9]+$" | sort -u)
btn_bad=$(echo "$btn_blurs" | grep -vE "^(8|16|20|24)$" || true)
bad_sigma="$level_bad$btn_bad"
if [ -n "$bad_sigma" ]; then
  echo "$bad_sigma"
  echo "FAIL: glass_tokens.dart 中 blur 取值超出 Spec 规定集合"
  fail=1
else
  echo "OK: 层级表取值全部来自 Spec 表格"
fi

echo "== 门禁 4：ambient / 光斑 / 背景图残留（AC-02 纯净背景）=="
violations=$(grep -rnE "\.ambient|ambient:|AmbientGradient|AmbientMotion|RadialGradient|MeshGradient|image_picker|ImagePicker" app/lib --include="*.dart" || true)
if [ -n "$violations" ]; then
  echo "$violations"
  echo "FAIL: 存在环境光 Mesh / 光斑 / 背景图代码残留（设计文档 §3 白名单制）"
  fail=1
else
  echo "OK: 无违规"
fi

echo "== 门禁 5：旧玻璃系统 API 残留（AC-08）=="
violations=$(grep -rnE "GlassTier|glassFill|glassFillStrong|glassBorder|ContrastGuard|compensatedFillAlpha|resolvedSigma|innerSheen" app/lib --include="*.dart" \
  | awk -F: '{code=$0; sub(/^[^:]+:[0-9]+:/, "", code); if (code !~ /^[ \t]*(\/\/|\*)/) print $0}' || true)
if [ -n "$violations" ]; then
  echo "$violations"
  echo "FAIL: 存在 v3 旧系统 API 残留（Spec §8 清除清单）"
  fail=1
else
  echo "OK: 无违规"
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "== FGDS 一致性门禁全部通过 =="
