#!/usr/bin/env bash
# Coding Tools · 完整发版流程
# 阶段 7 由子代理 C 完善；当前为占位实现
set -euo pipefail

cd "$(dirname "$0")/.."

: "${NOTES:?NOTES not set (release notes)}"
: "${DEVELOPER_ID:?DEVELOPER_ID not set}"
: "${KEYCHAIN_PROFILE:?KEYCHAIN_PROFILE not set}"
: "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY not set}"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/App/Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Sources/App/Info.plist)

echo "==> Coding Tools v$VERSION (build $BUILD)"
echo "    Notes: $NOTES"

if [[ "${SKIP_PUBLISH:-0}" == "1" ]]; then
  echo "==> SKIP_PUBLISH=1; local-only"
  ./scripts/build.sh
  ./scripts/package-release.sh
  exit 0
fi

# 1. 测试
./scripts/run-tests.sh

# 2. 构建
./scripts/build.sh

# 3. 打包
./scripts/package-release.sh

# 4. 签名
./scripts/sign-release.sh

# 5. 公证
./scripts/notarize-release.sh

# 6. Appcast
./scripts/generate-appcast.sh

# 7. 提交 + tag + 发布
cd ../..
git add Apps/Mac/Sources/App/Info.plist
git commit -m "release: v$VERSION (build $BUILD)" || true
git tag -s "v$VERSION" -m "v$VERSION"
git push origin main --tags

gh release create "v$VERSION" \
  Apps/Mac/build/release/CodingTools-${VERSION}.zip \
  Apps/Mac/build/release/CodingTools-${VERSION}.sha256 \
  Apps/Mac/build/release/appcast.xml \
  --title "v$VERSION" \
  --notes "$NOTES"

RELEASE_URL=$(gh release view "v$VERSION" --json url -q .url)
echo
echo "✅ Released v$VERSION (build $BUILD)"
echo "   $RELEASE_URL"
