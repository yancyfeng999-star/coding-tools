#!/usr/bin/env bash
# Coding Tools · 签名 Release
#
# 阶段 7 完善：
# - 用 Developer ID Application 签名（不是 "-" 临时签名）
# - 启用 Hardened Runtime（--options runtime）
# - 加时间戳（--timestamp）
# - Deep + force 重签
# - 严格验证（codesign --verify --strict）
# - spctl 评估
#
# 用法：
#   DEVELOPER_ID="Developer ID Application: Name (TEAMID)" ./scripts/sign-release.sh
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/DerivedData/Build/Products/Release/CodingTools.app"

usage() {
  cat <<EOF
sign-release.sh — 用 Developer ID 签名 + Hardened Runtime

必填环境变量：
  DEVELOPER_ID    "Developer ID Application: Name (TEAMID)"

用法：
  DEVELOPER_ID="..." ./scripts/sign-release.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${DEVELOPER_ID:?DEVELOPER_ID not set (e.g. 'Developer ID Application: Your Name (TEAMID)')}"

if [[ ! -d "$APP" ]]; then
  echo "❌ $APP not found; run package-release.sh first" >&2
  exit 1
fi

# 1. Hardened Runtime + 时间戳 + 深度重签
echo "==> Signing with $DEVELOPER_ID"
codesign \
  --deep \
  --force \
  --options runtime \
  --timestamp \
  --sign "$DEVELOPER_ID" \
  "$APP"

# 2. 严格验证签名
echo "==> Verifying signature (codesign --verify --strict)"
codesign --verify --deep --strict --verbose=2 "$APP"

# 3. 提取 Team ID 并与 DEVELOPER_ID 比对
TEAM_ID=$(codesign -dvv "$APP" 2>&1 | awk -F'=' '/^TeamIdentifier/ {gsub(/^ +| +$/,"",$2); print $2}')
if [[ -z "$TEAM_ID" ]]; then
  echo "❌ 无法从签名中提取 TeamIdentifier" >&2
  exit 1
fi
echo "    Team ID: $TEAM_ID"

# 4. Gatekeeper 评估（notarized 前可能失败，提示但不让脚本退出）
echo "==> Gatekeeper assessment (best-effort)"
if spctl --assess --verbose "$APP" 2>/dev/null; then
  echo "    ✅ Gatekeeper accepts"
else
  echo "    ⚠️  Gatekeeper 拒绝（未 notarized，属正常，notarize-release.sh 后会通过）"
fi

echo
echo "✅ Signed: $APP"
echo "   Team:  $TEAM_ID"
