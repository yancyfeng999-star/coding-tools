#!/usr/bin/env bash
# Coding Tools · 完整发版流程（阶段 7 完整版）
#
# 用法：
#   NOTES="一句话中文变更" ./scripts/release.sh
#   NOTES="..." SKIP_PUBLISH=1 ./scripts/release.sh   # 仅本地打包
#   NOTES="..." ./scripts/release.sh --dry-run         # 不发版，列出会做什么
#   ./scripts/release.sh --help
#
# 环境变量：
#   NOTES                 必填（除 --help / --dry-run）。发版说明
#   SKIP_PUBLISH          1 = 只跑 build + package，不 commit / tag / push
#   SPARKLE_PUBLIC_KEY    必填（除 SKIP_PUBLISH=1）。EdDSA 公钥 base64
#   SPARKLE_PRIVATE_KEY   可选；如设置，generate-appcast 会用它签名
#   DEVELOPER_ID          必填（除 SKIP_PUBLISH=1）
#   KEYCHAIN_PROFILE      必填（除 SKIP_PUBLISH=1）
#   DRY_RUN               1 = 模拟跑，打印命令但不执行
set -euo pipefail

cd "$(dirname "$0")/.."

PLIST="Sources/App/Info.plist"
OUT_DIR="build/release"
REPO_ROOT="$(cd ../.. && pwd)"

usage() {
  cat <<EOF
release.sh — Coding Tools 完整发版

用法：
  NOTES="说明" ./scripts/release.sh             # 正式发版
  NOTES="说明" SKIP_PUBLISH=1 ./scripts/release.sh # 仅本地打包
  NOTES="说明" DRY_RUN=1 ./scripts/release.sh   # 干跑（不执行）
  ./scripts/release.sh --help

必填环境变量（正式发版）：
  NOTES                发版说明（一句中文）
  DEVELOPER_ID         Developer ID Application 身份
  KEYCHAIN_PROFILE     notarytool credential profile
  SPARKLE_PUBLIC_KEY   EdDSA 公钥（base64）

可选：
  SPARKLE_PRIVATE_KEY  EdDSA 私钥路径（generate-appcast 用）
  SKIP_PUBLISH         1 = 跳过 git / gh release
  DRY_RUN              1 = 打印命令但不执行
EOF
}

# ============== 参数解析 ==============
case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --dry-run)
    DRY_RUN=1
    shift
    ;;
esac

# 校验
if [[ "${DRY_RUN:-0}" != "1" ]]; then
  : "${NOTES:?NOTES not set (release notes, e.g. NOTES='修复 xxx')}"
  if [[ "${SKIP_PUBLISH:-0}" != "1" ]]; then
    : "${DEVELOPER_ID:?DEVELOPER_ID not set}"
    : "${KEYCHAIN_PROFILE:?KEYCHAIN_PROFILE not set}"
    : "${SPARKLE_PUBLIC_KEY:?SPARKLE_PUBLIC_KEY not set (base64 of EdDSA public key)}"
  fi
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")

echo "==> Coding Tools v$VERSION (build $BUILD)"
echo "    Notes: ${NOTES:-<not set>}"
echo "    SKIP_PUBLISH=${SKIP_PUBLISH:-0}  DRY_RUN=${DRY_RUN:-0}"
echo

# 步骤包装：在 DRY_RUN 模式下只 echo
run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "  [DRY] $*"
  else
    "$@"
  fi
}

# SUPublicEDKey 注入与还原
inject_sparkle_pubkey() {
  local placeholder='__SPARKLE_PUBLIC_KEY__'
  if [[ -z "${SPARKLE_PUBLIC_KEY:-}" ]]; then
    return 0
  fi
  echo "==> Injecting SUPublicEDKey into Info.plist"
  /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $SPARKLE_PUBLIC_KEY" "$PLIST"
  # 重要：build 完成后 trap 会调用 restore_sparkle_pubkey
}

restore_sparkle_pubkey() {
  if [[ -n "${SPARKLE_PUBLIC_KEY:-}" && "${DRY_RUN:-0}" != "1" ]]; then
    echo "==> Restoring SUPublicEDKey placeholder"
    /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey __SPARKLE_PUBLIC_KEY__" "$PLIST" || true
  fi
}

# 任何失败都尝试还原 SUPublicEDKey（避免泄露到 git status）
trap restore_sparkle_pubkey EXIT

# ============== 步骤 1-7（正式发版时执行） ==============
if [[ "${SKIP_PUBLISH:-0}" != "1" ]]; then
  echo "==> Step 1/7  跑测试"
  run ./scripts/run-tests.sh

  inject_sparkle_pubkey

  echo "==> Step 2/7  构建"
  run ./scripts/build.sh

  echo "==> Step 3/7  打包（DMG + ZIP + SHA-256）"
  run ./scripts/package-release.sh

  echo "==> Step 4/7  签名"
  run ./scripts/sign-release.sh

  echo "==> Step 5/7  公证"
  run ./scripts/notarize-release.sh

  echo "==> Step 6/7  生成 Appcast（EdDSA 签名）"
  if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    run ./scripts/generate-appcast.sh
  else
    echo "    ⚠️  SPARKLE_PRIVATE_KEY 未设置，跳过 appcast"
  fi

  # 还原 Info.plist 占位符
  restore_sparkle_pubkey

  echo "==> Step 7/7  提交 + tag + 发布"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "  [DRY] cd $REPO_ROOT && git add Apps/Mac/Sources/App/Info.plist"
    echo "  [DRY] git commit -m 'release: v$VERSION (build $BUILD)'"
    echo "  [DRY] git tag -s v$VERSION -m 'v$VERSION'"
    echo "  [DRY] git push origin main --tags"
    echo "  [DRY] gh release create v$VERSION ..."
  else
    cd "$REPO_ROOT"
    git add Apps/Mac/Sources/App/Info.plist
    if ! git diff --cached --quiet; then
      git commit -m "release: v$VERSION (build $BUILD)" || true
    fi
    git tag -s "v$VERSION" -m "v$VERSION"
    git push origin main --tags

    ASSETS=(
      "$REPO_ROOT/Apps/Mac/build/release/CodingTools-${VERSION}.zip"
      "$REPO_ROOT/Apps/Mac/build/release/CodingTools-${VERSION}.dmg"
      "$REPO_ROOT/Apps/Mac/build/release/CodingTools-${VERSION}.sha256"
    )
    [[ -f "$REPO_ROOT/Apps/Mac/build/release/appcast.xml" ]] && ASSETS+=("$REPO_ROOT/Apps/Mac/build/release/appcast.xml")

    gh release create "v$VERSION" \
      "${ASSETS[@]}" \
      --title "v$VERSION" \
      --notes "${NOTES:-Release $VERSION}"

    RELEASE_URL=$(gh release view "v$VERSION" --json url -q .url)
    echo
    echo "✅ Released v$VERSION (build $BUILD)"
    echo "   $RELEASE_URL"
  fi
else
  # SKIP_PUBLISH：仅本地打包
  echo "==> SKIP_PUBLISH=1 — 仅本地打包，不发版"
  inject_sparkle_pubkey
  run ./scripts/build.sh
  run ./scripts/package-release.sh
  restore_sparkle_pubkey
  echo
  echo "✅ Local package ready at $REPO_ROOT/Apps/Mac/$OUT_DIR"
  if [[ "${DRY_RUN:-0}" != "1" ]]; then
    ls -la "$REPO_ROOT/Apps/Mac/$OUT_DIR"
  fi
fi
