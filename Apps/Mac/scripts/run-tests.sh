#!/usr/bin/env bash
# Coding Tools · 跑测试
#
# 阶段 7 完善：
# - 5 个 unit test scheme（Domain / Catalog / Installer / ManifestSecurity / Updates）
# - AppTests 暂不通过 CodingTools scheme 跑（LSUIElement CLI 启动失败），单独跑
# - 收集每个 scheme 的 pass / fail 数量
set -euo pipefail

cd "$(dirname "$0")/.."

DERIVED_DATA="${DERIVED_DATA:-./build/DerivedData}"

usage() {
  cat <<EOF
run-tests.sh — 跑全部单元测试

用法：
  ./scripts/run-tests.sh           # 跑 5 个 test scheme
  SCHEMES="DomainTests" ./scripts/run-tests.sh  # 仅跑指定 scheme

环境变量：
  SCHEMES            空格分隔的 scheme 列表（默认全部 5 个）
  DERIVED_DATA       自定义 DerivedData 路径
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

echo "==> tuist install"
tuist install

echo "==> tuist generate"
tuist generate

# 注：阶段 7 改为"按需 build" — 每个 test scheme 自己 build 依赖
# （不预先 build CodingTools scheme，避免其他 Agent 暂未合入的代码阻塞测试）

# 5 个显式 test scheme
DEFAULT_SCHEMES="DomainTests CatalogTests InstallerTests ManifestSecurityTests UpdatesTests"
SCHEMES="${SCHEMES:-$DEFAULT_SCHEMES}"

declare -i TOTAL_PASS=0
declare -i TOTAL_FAIL=0
FAILED_SCHEMES=()

for scheme in $SCHEMES; do
  echo "==> [$scheme] xcodebuild test"
  LOG="$DERIVED_DATA/test-${scheme}.log"
  mkdir -p "$DERIVED_DATA"

  set +e
  xcodebuild test \
    -workspace CodingTools.xcworkspace \
    -scheme "$scheme" \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    >"$LOG" 2>&1
  RC=$?
  set -e

  # 解析结果：取最后一次 "Executed N tests, with M failures" 模式
  EXEC_LINE=$(grep -E "Executed [0-9]+ tests?, with [0-9]+ failures?" "$LOG" | tail -1 || true)
  if [[ -n "$EXEC_LINE" ]]; then
    PASS=$(echo "$EXEC_LINE" | awk '{for(i=1;i<=NF;i++) if($i=="tests,") {print $(i-1); exit}}')
    FAIL=$(echo "$EXEC_LINE" | awk '{for(i=1;i<=NF;i++) if($i=="failures") {print $(i-1); exit}}')
    PASS="${PASS:-0}"
    FAIL="${FAIL:-0}"
  else
    PASS=0
    FAIL=0
  fi
  TOTAL_PASS=$((TOTAL_PASS + PASS))
  TOTAL_FAIL=$((TOTAL_FAIL + FAIL))

  if [[ $RC -ne 0 || $FAIL -gt 0 ]]; then
    FAILED_SCHEMES+=("$scheme")
    echo "    ❌ $scheme  exit=$RC  passed=$PASS  failed=$FAIL  (log: $LOG)"
  else
    echo "    ✅ $scheme  passed=$PASS"
  fi
done

echo
echo "==> Total: $TOTAL_PASS passed, $TOTAL_FAIL failed"

if [[ ${#FAILED_SCHEMES[@]} -gt 0 ]]; then
  echo "❌ 失败 scheme: ${FAILED_SCHEMES[*]}"
  exit 1
fi

echo "✅ All tests OK"
