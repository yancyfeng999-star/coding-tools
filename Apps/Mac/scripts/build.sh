#!/usr/bin/env bash
# Coding Tools · Debug 构建
#
# 用法：
#   ./scripts/build.sh           # 默认 Debug
#   CONFIG=Release ./scripts/build.sh
#
# 阶段 7：所有配置走 Tuist generate（--no-binary-cache 让 test target 重新编译）。
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-Debug}"

usage() {
  cat <<EOF
build.sh — Coding Tools 构建脚本

用法：
  ./scripts/build.sh                # Debug 构建（默认）
  CONFIG=Release ./scripts/build.sh # Release 构建

环境变量：
  CONFIG              Debug | Release（默认 Debug）
  SKIP_TUIST_INSTALL  1 = 跳过 tuist install（CI 缓存场景）
  DERIVED_DATA           自定义 DerivedData 路径（默认 ./build/DerivedData）
  DESTINATION            xcodebuild destination（默认 generic/platform=macOS，
                         避免把 DerivedData 里的 .app 注册进启动台）
  KEEP_APP_REGISTERED    1 = 构建后不注销 Launch Services（默认注销）
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${SKIP_TUIST_INSTALL:-0}" != "1" ]]; then
  echo "==> tuist install"
  tuist install
fi

echo "==> tuist generate (--no-binary-cache for test targets)"
tuist generate CodingTools --no-binary-cache

DERIVED_DATA="${DERIVED_DATA:-./build/DerivedData}"
DESTINATION="${DESTINATION:-generic/platform=macOS}"
APP_PRODUCT="$DERIVED_DATA/Build/Products/$CONFIG/Coding Tools.app"

echo "==> xcodebuild $CONFIG ($DESTINATION)"
xcodebuild build \
  -workspace CodingTools.xcworkspace \
  -scheme CodingTools \
  -configuration "$CONFIG" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA"

# 打包只需要磁盘上的 .app；不要把它注册成可启动的本机 App。
if [[ "${KEEP_APP_REGISTERED:-0}" != "1" && -d "$APP_PRODUCT" ]]; then
  UNREGISTER_ONLY=1 SWEEP=0 ./scripts/cleanup-local-app-products.sh "$APP_PRODUCT"
fi

echo "✅ Build ($CONFIG) OK"
echo "   产物：${APP_PRODUCT}（未注册到启动台）"
