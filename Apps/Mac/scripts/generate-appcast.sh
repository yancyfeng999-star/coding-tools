#!/usr/bin/env bash
# Coding Tools · 生成 Appcast（Sparkle）
# 阶段 7 由子代理 C 完善；当前占位
set -euo pipefail

cd "$(dirname "$0")/.."

: "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY not set (path to EdDSA private key)}"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/App/Info.plist)
OUT_DIR="build/release"
APPCAST="$OUT_DIR/appcast.xml"

mkdir -p "$OUT_DIR"

echo "==> Generating appcast from $OUT_DIR"
# Sparkle 工具会扫描 ZIP/DMG，自动生成 appcast
"$SPARKLE_PRIVATE_KEY/../bin/generate_appcast" \
  --account "yancyfeng999-star" \
  --download-url-prefix "https://github.com/yancyfeng999-star/coding-tools/releases/download" \
  "$OUT_DIR"

echo "✅ Appcast: $APPCAST"
