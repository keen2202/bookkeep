#!/usr/bin/env bash
# 玻璃拟态一致性门禁（Glassmorphism v3，Spec §8 / BK-GLS-011）
#
# 两条 CI 可执行检查（输出非空即 fail）：
#   1. BackdropFilter 唯一出口规则——仅允许 shared/theme/glass/、
#      shared/theme/glass_icon.dart、shared/theme/background/ 三处；
#   2. features 层禁直接引用 AppGlass.fill*/AppGlass.border*（改走 resolveGlassSpec）。
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

echo "== 门禁 1：BackdropFilter 唯一出口（Spec §8.1/§8.2）=="
violations=$(grep -rn "BackdropFilter(" app/lib --include="*.dart" \
  | grep -v "shared/theme/glass/\|shared/theme/glass_icon.dart\|shared/theme/background/" || true)
if [ -n "$violations" ]; then
  echo "$violations"
  echo "FAIL: 存在玻璃出口之外的 BackdropFilter（唯一合法处：glass/glass_panel.dart、glass_icon.dart、background/）"
  fail=1
else
  echo "OK: 无违规"
fi

echo "== 门禁 2：features 层禁用 AppGlass.fill*/border* 直引（D5）=="
violations=$(grep -rn "AppGlass\.fill\|AppGlass\.border" app/lib/features --include="*.dart" || true)
if [ -n "$violations" ]; then
  echo "$violations"
  echo "FAIL: features 层必须经 resolveGlassSpec()/GlassPanel 消费层级规格"
  fail=1
else
  echo "OK: 无违规"
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "== 一致性门禁全部通过 =="
