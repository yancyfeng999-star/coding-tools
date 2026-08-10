#!/usr/bin/env bash
# Coding Tools · 公证 Release
#
# 阶段 7 完善：
# - notarytool submit ZIP + DMG（上传两个以确保二者都通过）
# - 等公证完成（--wait）
# - Staple 到 DMG 和 ZIP
# - spctl 验证 Gatekeeper
#
# 用法：
#   KEYCHAIN_PROFILE=notarytool-profile ./scripts/notarize-release.sh
set -euo pipefail

cd "$(dirname "$0")/.."

PLIST="Sources/App/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
OUT_DIR="build/release"
DMG="$OUT_DIR/CodingTools-${VERSION}.dmg"
ZIP="$OUT_DIR/CodingTools-${VERSION}.zip"

usage() {
  cat <<EOF
notarize-release.sh — 提交 Apple Notary Service + Staple

必填环境变量：
  KEYCHAIN_PROFILE  notarytool credential profile（xcrun notarytool store-credentials 创建）

用法：
  KEYCHAIN_PROFILE=... ./scripts/notarize-release.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${KEYCHAIN_PROFILE:?KEYCHAIN_PROFILE not set (run: xcrun notarytool store-credentials <name>)}"

if [[ ! -f "$ZIP" ]]; then
  echo "❌ $ZIP not found; run package-release.sh first" >&2
  exit 1
fi

# 1. 提交 ZIP（最快，且是 Sparkle in-app update 用的格式）
echo "==> Submitting ZIP to notary service"
xcrun notarytool submit "$ZIP" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

# 2. 提交 DMG（如存在）
if [[ -f "$DMG" ]]; then
  echo "==> Submitting DMG to notary service"
  xcrun notarytool submit "$DMG" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait
fi

# 3. Staple
echo "==> Stapling tickets"
xcrun stapler staple "$ZIP"
[[ -f "$DMG" ]] && xcrun stapler staple "$DMG"

# 4. 验证 Staple
echo "==> Validating staples"
xcrun stapler validate "$ZIP"
[[ -f "$DMG" ]] && xcrun stapler validate "$DMG"

# 5. Gatekeeper 最终验证
echo "==> Gatekeeper final assessment"
spctl --assess --verbose "$ZIP"
[[ -f "$DMG" ]] && spctl --assess --verbose "$DMG"

echo
echo "✅ Notarized: $ZIP"
[[ -f "$DMG" ]] && echo "   $DMG"
