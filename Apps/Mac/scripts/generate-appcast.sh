#!/usr/bin/env bash
# Coding Tools · 生成 Appcast（Sparkle）
#
# 阶段 7 完善：
# - 调用 Sparkle 自带的 generate_appcast 工具（带 EdDSA 签名）
# - 扫描 build/release 下的所有 ZIP / DMG
# - 输出 appcast.xml 到 build/release
# - 同时输出到仓库根的 docs/appcast.xml（GitHub Pages / raw 访问备用）
#
# 用法：
#   SPARKLE_PRIVATE_KEY=path/to/ed25519_private_key ./scripts/generate-appcast.sh
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR="build/release"
APPCAST="$OUT_DIR/appcast.xml"
DOWNLOAD_BASE="https://github.com/yancyfeng999-star/coding-tools/releases/download"

usage() {
  cat <<EOF
generate-appcast.sh — 用 Sparkle 工具生成 EdDSA 签名 Appcast

必填环境变量：
  SPARKLE_PRIVATE_KEY  指向 EdDSA 私钥文件（generate_keys 生成）

用法：
  SPARKLE_PRIVATE_KEY=/path/to/ed_key ./scripts/generate-appcast.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY not set (path to EdDSA private key)}"

if [[ ! -f "$SPARKLE_PRIVATE_KEY" ]]; then
  echo "❌ SPARKLE_PRIVATE_KEY 文件不存在: $SPARKLE_PRIVATE_KEY" >&2
  exit 1
fi

# 定位 generate_appcast：通常与私钥同目录（Sparkle 工具链布局）
SPARKLE_BIN_DIR="$(dirname "$SPARKLE_PRIVATE_KEY")"
GENERATE_APPCAST=""

for cand in \
  "$SPARKLE_BIN_DIR/generate_appcast" \
  "$SPARKLE_BIN_DIR/../bin/generate_appcast" \
  "/usr/local/bin/generate_appcast" \
  "$(command -v generate_appcast || true)"
do
  if [[ -x "$cand" ]]; then
    GENERATE_APPCAST="$cand"
    break
  fi
done

if [[ -z "$GENERATE_APPCAST" ]]; then
  echo "❌ 找不到 generate_appcast 工具" >&2
  echo "   尝试在 \$SPARKLE_PRIVATE_KEY 附近找，或安装 Sparkle CLI" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "==> Generating appcast from $OUT_DIR"
"$GENERATE_APPCAST" \
  --ed-key-file "$SPARKLE_PRIVATE_KEY" \
  --download-url-prefix "$DOWNLOAD_BASE" \
  --account "yancyfeng999-star" \
  --channel "stable" \
  "$OUT_DIR"

if [[ ! -f "$APPCAST" ]]; then
  echo "❌ appcast.xml 未生成" >&2
  exit 1
fi

# 同步一份到 docs/appcast.xml（供 GitHub Pages / 调试用）
mkdir -p ../../docs
cp "$APPCAST" "../../docs/appcast.xml"

# 同步到仓库根（让 GitHub Pages 可访问：/appcast.xml）
cp "$APPCAST" "../../appcast.xml"

echo
echo "✅ Appcast generated:"
echo "   $APPCAST"
echo "   ../../docs/appcast.xml"
echo "   ../../appcast.xml"
echo
echo "   EdDSA 签名密钥: ${SPARKLE_PRIVATE_KEY##*/}"
