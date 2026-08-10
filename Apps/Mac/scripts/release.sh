#!/usr/bin/env bash
# Coding Tools · 完整发版流程（v1.0.0+ 端到端）
#
# 一次跑通：bump → test → build → package(DMG+ZIP) → sign_update →
#          generate_appcast(EdDSA) → commit+tag+push → gh release create
#
# 用法：
#   NOTES="一句话中文变更" ./scripts/release.sh              # patch 升版 + 发版
#   NOTES="..." ./scripts/release.sh minor                  # minor 升版
#   NOTES="..." ./scripts/release.sh 1.2.3                  # 指定版本
#   SKIP_PUBLISH=1 NOTES="试包" ./scripts/release.sh        # 仅本地打包
#   ./scripts/release.sh --dry-run                          # 干跑（不执行）
#   ./scripts/release.sh --help
#
# 必填（正式发版）：
#   NOTES                一句中文变更说明
#
# 可选：
#   BUMP                 patch | minor | major | x.y.z（默认 patch）
#   SPARKLE_PRIVATE_KEY  EdDSA 私钥路径（默认 ../../.keys/ed25519_private_key）
#   SKIP_PUBLISH         1 = 跳过 git/gh release，只本地打包
#   SKIP_TESTS           1 = 跳过 test scheme
#   SKIP_DMG / SKIP_ZIP  1 = 跳过对应产物
#   DRY_RUN              1 = 打印命令但不执行
#   NO_BUMP              1 = 跳过版本号 bump
set -euo pipefail

cd "$(dirname "$0")/.."
REPO_ROOT="$(cd ../.. && pwd)"
PLIST="Sources/App/Info.plist"
# appcast/ 目录：只放 zip + appcast.xml（Sparkle 禁 zip+dmg 同版本共存）
OUT_DIR="build/release"
# dist/ 目录：放 dmg（人工下载，不进 appcast）
DIST_DIR="build/dist"
# 真实 bundle 名带空格（Info.plist: CFBundleName=Coding Tools）
APP_BUNDLE_NAME="Coding Tools"
APP_BUNDLE_PATH="$OUT_DIR/${APP_BUNDLE_NAME}.app"
# 产物文件名无空格（GitHub release 友好、URL 干净）
ARTIFACT_BASE="CodingTools"

# Sparkle 工具（sign_update / generate_appcast）
SPARKLE_TOOLS="$(cd "$(dirname "$0")" && pwd)/.tools/sparkle"
SIGN_UPDATE="$SPARKLE_TOOLS/sign_update"
GENERATE_APPCAST="$SPARKLE_TOOLS/generate_appcast"

# Sparkle 私钥（默认 ../../.keys/ed25519_private_key）
DEFAULT_KEY="$REPO_ROOT/.keys/ed25519_private_key"
SPARKLE_PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:-$DEFAULT_KEY}"

# ============== 帮助 ==============
usage() {
  cat <<EOF
release.sh — Coding Tools 完整发版（端到端）

用法：
  NOTES="修复 xxx" ./scripts/release.sh             # 正式发版（patch 升版）
  NOTES="..." BUMP=minor ./scripts/release.sh        # minor 升版
  NOTES="..." SKIP_PUBLISH=1 ./scripts/release.sh   # 仅本地打包
  NOTES="..." DRY_RUN=1 ./scripts/release.sh        # 干跑

必填：
  NOTES                 发版说明（一句中文）

可选：
  BUMP                  patch | minor | major | x.y.z（默认 patch）
  SPARKLE_PRIVATE_KEY   私钥路径（默认 .keys/ed25519_private_key）
  SKIP_PUBLISH          1 = 跳过 git/gh release
  SKIP_TESTS            1 = 跳过 5 个 test scheme
  SKIP_DMG / SKIP_ZIP   1 = 跳过对应产物
  NO_BUMP               1 = 跳过版本号 bump
  DRY_RUN               1 = 打印命令但不执行
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --dry-run) DRY_RUN=1; shift ;;
esac

# ============== 校验 ==============
if [[ "${DRY_RUN:-0}" != "1" ]]; then
  : "${NOTES:?NOTES not set — 发版说明必填}"
fi
if [[ ! -x "$SIGN_UPDATE" ]]; then
  echo "❌ Sparkle 工具缺失: $SIGN_UPDATE" >&2
  echo "   请跑: mkdir -p $SPARKLE_TOOLS && cp /path/to/sparkle/bin/* $SPARKLE_TOOLS/" >&2
  exit 1
fi
if [[ ! -f "$SPARKLE_PRIVATE_KEY" ]]; then
  echo "❌ Sparkle 私钥缺失: $SPARKLE_PRIVATE_KEY" >&2
  echo "   跑 generate_keys -x .keys/ed25519_private_key 生成" >&2
  exit 1
fi

# ============== 步骤包装 ==============
run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "  [DRY] $*"
  else
    "$@"
  fi
}

# ============== 步骤 1: bump version ==============
if [[ "${NO_BUMP:-0}" != "1" ]]; then
  BUMP_MODE="${BUMP:-${1:-patch}}"
  echo "==> Step 1/7  bump version ($BUMP_MODE)"
  run ./scripts/bump-version.sh "$BUMP_MODE"
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
TAG="v$VERSION"
echo "    → $TAG (build $BUILD)"
echo

# ============== 步骤 2: tests ==============
if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  echo "==> Step 2/7  跑 5 个 test scheme"
  run ./scripts/run-tests.sh
fi

# ============== 步骤 3: build (Release) ==============
echo "==> Step 3/7  xcodebuild Release"
export CONFIG=Release
# 强制 clean Localization Resources（修 v1.0.0 出现的 .lproj cache bug：.app 没拿到新加的 key）
rm -rf build/DerivedData/Build/Intermediates.noindex/CodingTools.build/Release/CodingTools.build/{zh-Hans,en}.lproj
run ./scripts/build.sh

# 把 Release 配置的 .app 拷到 OUT_DIR 方便打包
mkdir -p "$OUT_DIR"
if [[ -d "build/DerivedData/Build/Products/Release/${APP_BUNDLE_NAME}.app" ]]; then
  rm -rf "$APP_BUNDLE_PATH"
  cp -R "build/DerivedData/Build/Products/Release/${APP_BUNDLE_NAME}.app" "$APP_BUNDLE_PATH"
fi
if [[ ! -d "$APP_BUNDLE_PATH" ]]; then
  echo "❌ App not found: $APP_BUNDLE_PATH" >&2
  exit 1
fi
echo

# ============== 步骤 4: package (ZIP + DMG + PKG) ==============
echo "==> Step 4/7  打包 ZIP + DMG + PKG"
mkdir -p "$OUT_DIR" "$DIST_DIR"
# OUT_DIR: ZIP + PKG（Sparkle appcast 引用；同版本 zip + pkg 共存，pkg 是另一个 enclosure）
# DIST_DIR: DMG（人下载用，**不进** appcast）
if [[ "${SKIP_ZIP:-0}" != "1" ]]; then
  ditto -c -k --sequesterRsrc --keepParent \
    "$APP_BUNDLE_PATH" \
    "$OUT_DIR/${ARTIFACT_BASE}-${VERSION}.zip"
  echo "    ✅ $OUT_DIR/${ARTIFACT_BASE}-${VERSION}.zip"
fi
if [[ "${SKIP_PKG:-0}" != "1" ]]; then
  # PKG：未签名（没 Apple ID），用户首次安装需右键 → 打开绕过 Gatekeeper。
  # Sparkle 应用内更新会自动用 installertask 静默安装（不需要 GUI 弹窗）。
  PKG_PATH="$OUT_DIR/${ARTIFACT_BASE}-${VERSION}.pkg"
  rm -f "$PKG_PATH"
  pkgbuild \
    --root "$APP_BUNDLE_PATH" \
    --install-location "/Applications/Coding Tools.app" \
    --identifier "com.codingtools.macos" \
    --version "$VERSION" \
    "$PKG_PATH" 2>&1
  echo "    ✅ $PKG_PATH (未签名 — 上 Apple ID 后加 --sign 'Developer ID Installer: ...')"
fi
if [[ "${SKIP_DMG:-0}" != "1" ]]; then
  STAGE=$(mktemp -d)
  trap 'rm -rf "$STAGE"' EXIT
  cp -R "$APP_BUNDLE_PATH" "$STAGE/${APP_BUNDLE_NAME}.app"
  ln -s /Applications "$STAGE/Applications"
  DMG_TMP="$DIST_DIR/.${ARTIFACT_BASE}-${VERSION}-temp.dmg"
  hdiutil create \
    -volName "Coding Tools $VERSION" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG_TMP" >/dev/null
  mv "$DMG_TMP" "$DIST_DIR/${ARTIFACT_BASE}-${VERSION}.dmg"
  echo "    ✅ $DIST_DIR/${ARTIFACT_BASE}-${VERSION}.dmg"
fi
echo

# ============== 步骤 5: 生成 appcast.xml (EdDSA 签名) ==============
# generate_appcast 会用 --ed-key-file 给每个 artifact 签 edSignature + length
# 并把 appcast.xml 直接写到 archives 目录（不用 stdout redirect）。
echo "==> Step 5/7  生成 appcast.xml (generate_appcast 自带 EdDSA 签名)"
APPCAST="$OUT_DIR/appcast.xml"
ZIP_PATH="$OUT_DIR/${ARTIFACT_BASE}-${VERSION}.zip"

# 读取版本号 + build 号
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")

# 清掉 OUT_DIR 里残留的 .app 和上次失败的 appcast.xml（避免 generate_appcast 解析坏文件）
rm -rf "$APP_BUNDLE_PATH" "$APPCAST"

if [[ -f "$ZIP_PATH" ]]; then
  # Sparkle 2.x: --download-url-prefix **不会**自动插入 tag 段。
  # 如果 prefix 嵌 $TAG (如 .../download/v1.0.0)，generate_appcast 拼出来是
  #   .../download/v1.0.0CodingTools-1.0.0.zip （粘一起，没 /）
  # 解法：prefix 用不带 tag 的根 URL .../download/，generate_appcast 写出来后
  # 用 sed 在 prefix 后插入 ${TAG}/ 段。
  PREFIX="https://github.com/yancyfeng999-star/coding-tools/releases/download/"
  "$GENERATE_APPCAST" \
    --ed-key-file "$SPARKLE_PRIVATE_KEY" \
    --download-url-prefix "$PREFIX" \
    "$OUT_DIR"
  if [[ ! -f "$APPCAST" ]]; then
    echo "    ❌ appcast.xml 未生成" >&2
    exit 1
  fi
  # 把 <enclosure url="<PREFIX><filename>" 改成 <PREFIX><TAG>/<filename>
  sed -i '' "s|${PREFIX}|${PREFIX}${TAG}/|g" "$APPCAST"

  # 追加 .pkg 的 <enclosure>（generate_appcast 不支持 .pkg，参考官方 doc 手写）
  PKG_PATH="$OUT_DIR/${ARTIFACT_BASE}-${VERSION}.pkg"
  if [[ -f "$PKG_PATH" ]]; then
    PKG_SIG=$("$SIGN_UPDATE" --ed-key-file "$SPARKLE_PRIVATE_KEY" -p "$PKG_PATH" 2>/dev/null | tail -1 | tr -d '\n')
    PKG_LEN=$(stat -f%z "$PKG_PATH")
    PKG_URL="${PREFIX}${TAG}/${ARTIFACT_BASE}-${VERSION}.pkg"
    # Sparkle 2.x 严格要求每个 <enclosure> 显式 xml:lang
    PKG_ENCLOSURE="            <enclosure xml:lang=\"en\" url=\"${PKG_URL}\" length=\"${PKG_LEN}\" type=\"application/vnd.apple.installer-package+xml\" sparkle:edSignature=\"${PKG_SIG}\" sparkle:installationType=\"package\"/>"
    # 在 zip <enclosure> 之后插入 pkg <enclosure>
    sed -i '' "/sparkle:edSignature=\"[^\"]*\"\\/>/a\\
${PKG_ENCLOSURE}
" "$APPCAST"
    echo "    ✅ +pkg enclosure added (length=$PKG_LEN, edSig=${PKG_SIG:0:16}...)"
  fi
  # 统一给所有 <enclosure 加 xml:lang="en"（Sparkle 2.x 强要求；PKG 已经有了所以这里只补 ZIP）
  sed -i '' 's|<enclosure |<enclosure xml:lang="en" |g' "$APPCAST"
  echo "    ✅ $APPCAST ($(wc -l < "$APPCAST") lines, $(grep -c '<enclosure' "$APPCAST" || echo 0) items)"
  echo "    (URLs patched to include ${TAG}/ segment)"
else
  echo "    ⚠️  $ZIP_PATH 不存在，跳过 appcast"
fi
echo

# ============== 步骤 6: 写 CHANGELOG + commit + tag + push ==============
if [[ "${SKIP_PUBLISH:-0}" != "1" ]]; then
  echo "==> Step 6/7  commit + tag + push"
  cd "$REPO_ROOT"

  # 写 CHANGELOG
  CHANGELOG="CHANGELOG.md"
  if [[ -f "$CHANGELOG" ]]; then
    DATE=$(date +%Y-%m-%d)
    TMP_CHANGELOG=$(mktemp)
    echo "## [$VERSION] - $DATE" > "$TMP_CHANGELOG"
    echo "" >> "$TMP_CHANGELOG"
    echo "### Changed" >> "$TMP_CHANGELOG"
    echo "" >> "$TMP_CHANGELOG"
    echo "- $NOTES" >> "$TMP_CHANGELOG"
    echo "" >> "$TMP_CHANGELOG"
    # 在 ## [Unreleased] 后插入新段；如果不存在则追加到文件头
    if grep -q "## \[Unreleased\]" "$CHANGELOG"; then
      awk '/^## \[Unreleased\]/{print; print ""; print "### Changed"; print ""; print "- 暂未发布"; print ""; next} /^## / && !/Unreleased/{system("cat '"$TMP_CHANGELOG"'"); print; next} {print}' "$CHANGELOG" > "$TMP_CHANGELOG.tmp"
      # 简化：直接在 ## [Unreleased] 段下追加新版本
      python3 -c "
import sys
with open('$CHANGELOG') as f: content = f.read()
new_section = '''## [$VERSION] - $DATE

### Changed

- $NOTES

'''
content = content.replace('## [Unreleased]', '## [Unreleased]\n\n### Changed\n\n- 暂未发布\n', 1)
content = content.replace('## [Unreleased]\n\n### Changed\n\n- 暂未发布\n', '## [Unreleased]\n\n### Changed\n\n- 暂未发布\n\n' + new_section)
with open('$TMP_CHANGELOG', 'w') as f: f.write(content)
"
      mv "$TMP_CHANGELOG" "$CHANGELOG"
    else
      # 文件没有 Unreleased 段，直接追加
      cat "$TMP_CHANGELOG" >> "$CHANGELOG"
    fi
    rm -f "$TMP_CHANGELOG.tmp"
  fi

  git add -A
  if ! git diff --cached --quiet; then
    run git commit -m "release: $TAG (build $BUILD)

$NOTES"
  fi
  run git tag -a "$TAG" -m "$TAG"
  run git push origin main --tags
  echo

  # ============== 步骤 7: gh release create ==============
  echo "==> Step 7/7  gh release create"
  ASSETS=(
    "$REPO_ROOT/Apps/Mac/$ZIP_PATH"
    "$REPO_ROOT/Apps/Mac/$APPCAST"
  )
  PKG_FULL="$REPO_ROOT/Apps/Mac/$OUT_DIR/${ARTIFACT_BASE}-${VERSION}.pkg"
  [[ -f "$PKG_FULL" ]] && ASSETS+=("$PKG_FULL")
  [[ -f "$REPO_ROOT/Apps/Mac/$DIST_DIR/${ARTIFACT_BASE}-${VERSION}.dmg" ]] && ASSETS+=("$REPO_ROOT/Apps/Mac/$DIST_DIR/${ARTIFACT_BASE}-${VERSION}.dmg")

  run gh release create "$TAG" \
    "${ASSETS[@]}" \
    --title "$TAG" \
    --notes "$NOTES" \
    --latest

  RELEASE_URL=$(gh release view "$TAG" --json url -q .url 2>/dev/null || echo "")
  echo
  echo "✅ Released $TAG (build $BUILD)"
  echo "   ${RELEASE_URL:-https://github.com/yancyfeng999-star/coding-tools/releases/tag/$TAG}"
else
  echo "==> SKIP_PUBLISH=1 — 跳过 git / gh release，仅本地打包"
fi
