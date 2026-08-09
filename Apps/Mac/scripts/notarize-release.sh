#!/usr/bin/env bash
# Coding Tools · 公证 Release
# 阶段 7 由子代理 C 完善；当前占位
set -euo pipefail

cd "$(dirname "$0")/.."

: "${KEYCHAIN_PROFILE:?KEYCHAIN_PROFILE not set}"

DMG="build/release/CodingTools-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/App/Info.plist).dmg"
ZIP="build/release/CodingTools-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/App/Info.plist).zip"

echo "==> Submitting to notary service"
xcrun notarytool submit "$ZIP" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

echo "==> Stapling"
xcrun stapler staple "$ZIP"
[[ -f "$DMG" ]] && xcrun stapler staple "$DMG"

echo "==> Verifying Gatekeeper"
xcrun stapler validate "$ZIP"
[[ -f "$DMG" ]] && xcrun stapler validate "$DMG"
spctl --assess --verbose "$ZIP"

echo "✅ Notarized: $ZIP"
