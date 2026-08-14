#!/usr/bin/env bash
# Coding Tools · 打包 Release
#
# 阶段 7 完善：
# - Release 构建（xcodebuild）
# - DMG：hdiutil 从 .app 生成，包含 /Applications 快捷方式
# - ZIP：ditto 给 Sparkle 应用内更新用
# - SHA-256 计算
# - Sparkle 签名（如 SPARKLE_PRIVATE_KEY 已设置）
#
# 用法：
#   ./scripts/package-release.sh              # 默认 Release 配置
#   CONFIG=Debug ./scripts/package-release.sh # Debug 打包（仅用于测试）
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="CodingTools"
PLIST="Sources/App/Info.plist"
OUT_DIR="build/release"
APP_PATH="build/DerivedData/Build/Products/Release/${APP_NAME}.app"

usage() {
  cat <<EOF
package-release.sh — 打包 Release 产物

用法：
  ./scripts/package-release.sh

环境变量：
  CONFIG              Debug | Release（默认 Release）
  SPARKLE_PRIVATE_KEY 路径到 EdDSA 私钥（可选；设置后给 ZIP 签名）
  SKIP_DMG            1 = 跳过 DMG
  SKIP_ZIP            1 = 跳过 ZIP
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

CONFIG="${CONFIG:-Release}"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")

if [[ "$CONFIG" == "Release" ]]; then
  APP_PATH="build/DerivedData/Build/Products/Release/${APP_NAME}.app"
else
  APP_PATH="build/DerivedData/Build/Products/${CONFIG}/${APP_NAME}.app"
fi

mkdir -p "$OUT_DIR"

echo "==> Release build ($CONFIG) v$VERSION (build $BUILD)"
xcodebuild \
  -workspace CodingTools.xcworkspace \
  -scheme CodingTools \
  -configuration "$CONFIG" \
  -destination "${DESTINATION:-generic/platform=macOS}" \
  -derivedDataPath ./build/DerivedData \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ App not found at $APP_PATH" >&2
  exit 1
fi

# ============== ZIP（Sparkle 应用内更新） ==============
if [[ "${SKIP_ZIP:-0}" != "1" ]]; then
  echo "==> Creating ZIP for Sparkle in-app update"
  ditto -c -k --sequesterRsrc --keepParent \
    "$APP_PATH" \
    "$OUT_DIR/CodingTools-${VERSION}.zip"
  echo "    ✅ $OUT_DIR/CodingTools-${VERSION}.zip"
fi

# ============== DMG（人工下载） ==============
if [[ "${SKIP_DMG:-0}" != "1" ]]; then
  echo "==> Creating DMG (hdiutil)"
  STAGE=$(mktemp -d)
  trap 'rm -rf "$STAGE"' EXIT
  cp -R "$APP_PATH" "$STAGE/${APP_NAME}.app"
  ln -s /Applications "$STAGE/Applications"

  DMG_TMP="$OUT_DIR/.CodingTools-${VERSION}-temp.dmg"
  hdiutil create \
    -volName "Coding Tools $VERSION" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG_TMP" >/dev/null

  mv "$DMG_TMP" "$OUT_DIR/CodingTools-${VERSION}.dmg"
  echo "    ✅ $OUT_DIR/CodingTools-${VERSION}.dmg"
fi

# ============== SHA-256 ==============
echo "==> Computing SHA-256"
: > "$OUT_DIR/CodingTools-${VERSION}.sha256"
for f in "$OUT_DIR/CodingTools-${VERSION}.dmg" "$OUT_DIR/CodingTools-${VERSION}.zip"; do
  if [[ -f "$f" ]]; then
    shasum -a 256 "$f" | awk '{print $1"  '"$(basename "$f")"'"}' >> "$OUT_DIR/CodingTools-${VERSION}.sha256"
  fi
done
cat "$OUT_DIR/CodingTools-${VERSION}.sha256"

# ============== Sparkle 签名（如有私钥） ==============
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" && -f "${SPARKLE_PRIVATE_KEY}" && "${SKIP_ZIP:-0}" != "1" ]]; then
  echo "==> Signing ZIP with Sparkle EdDSA"
  SPARKLE_BIN="$(dirname "$SPARKLE_PRIVATE_KEY")"
  if [[ -x "$SPARKLE_BIN/sign_update" ]]; then
    "$SPARKLE_BIN/sign_update" \
      --ed-key-file "$SPARKLE_PRIVATE_KEY" \
      "$OUT_DIR/CodingTools-${VERSION}.zip" >/dev/null
    # sign_update 在 ZIP 旁追加 .sig 文件
    echo "    ✅ $OUT_DIR/CodingTools-${VERSION}.zip.sig"
  else
    echo "    ⚠️  sign_update not found at $SPARKLE_BIN/sign_update；跳过签名"
  fi
fi

# 打完包只留 dmg/zip，删除会进启动台的 .app。
SWEEP=0 ./scripts/cleanup-local-app-products.sh \
  "$(dirname "$APP_PATH")" \
  "$OUT_DIR"

echo
echo "✅ Release artifacts:"
ls -la "$OUT_DIR"
