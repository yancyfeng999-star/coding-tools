#!/usr/bin/env bash
# Coding Tools · 打包 Release
# 阶段 7 由子代理 C 完善；当前占位
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/App/Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Sources/App/Info.plist)
APP_NAME="CodingTools"
OUT_DIR="build/release"
APP_PATH="build/DerivedData/Build/Products/Release/${APP_NAME}.app"

mkdir -p "$OUT_DIR"

echo "==> Release build"
xcodebuild -scheme CodingTools -configuration Release \
  -derivedDataPath ./build/DerivedData build

echo "==> Creating DMG (placeholder)"
# 阶段 7 接入：create-dmg 或自实现 hdiutil 流程
if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ App not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Creating ZIP (Sparkle in-app update)"
ditto -c -k --sequesterRsrc --keepParent \
  "$APP_PATH" \
  "$OUT_DIR/CodingTools-${VERSION}.zip"

echo "==> Computing SHA-256"
shasum -a 256 "$OUT_DIR/CodingTools-${VERSION}.zip" \
  | awk -v v="$VERSION" '{print $1"  CodingTools-"v".zip"}' \
  > "$OUT_DIR/CodingTools-${VERSION}.sha256"

echo "✅ Release artifacts:"
ls -la "$OUT_DIR"
echo
echo "⚠️  TODO (阶段 7):"
echo "   - DMG create + sign + notarize"
echo "   - Appcast generation with EdDSA"
echo "   - gh release create"
