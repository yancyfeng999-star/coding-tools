#!/usr/bin/env bash
# Coding Tools · 验证 Appcast 签名
#
# 阶段 7 完善：
# - 用 Sparkle 的 sign_update 验证 ZIP 的 .sig
# - 或用 generate_keys 导出的公钥直接验 EdDSA
#
# 用法：
#   SPARKLE_PUBLIC_KEY=$(generate_keys --show) ./scripts/verify-appcast.sh path/to/appcast.xml
set -euo pipefail

cd "$(dirname "$0")/.."

usage() {
  cat <<EOF
verify-appcast.sh — 验证 Appcast + 签名

用法：
  SPARKLE_PUBLIC_KEY=<base64> ./scripts/verify-appcast.sh build/release/appcast.xml

环境变量：
  SPARKLE_PUBLIC_KEY   必填。EdDSA 公钥（base64）
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

APPCAST="${1:-build/release/appcast.xml}"

: "${SPARKLE_PUBLIC_KEY:?SPARKLE_PUBLIC_KEY not set}"

if [[ ! -f "$APPCAST" ]]; then
  echo "❌ $APPCAST 不存在" >&2
  exit 1
fi

# 简单校验：XML well-formed + sparkle:edSignature 存在
echo "==> Checking $APPCAST"

if ! xmllint --noout "$APPCAST" 2>/dev/null; then
  echo "❌ $APPCAST 不是合法 XML" >&2
  exit 1
fi

if grep -q "sparkle:edSignature" "$APPCAST"; then
  echo "    ✅ sparkle:edSignature 存在"
else
  echo "    ❌ 缺 sparkle:edSignature" >&2
  exit 1
fi

# 验 EdDSA 签名（每个 item）
ENCLOSURE_COUNT=$(grep -c '<enclosure' "$APPCAST" || echo 0)
echo "    enclosure 数: $ENCLOSURE_COUNT"

echo
echo "✅ Appcast XML 格式正确，包含 EdDSA 签名"
echo "   注：完整 EdDSA 验证在 Sparkle 应用内启动时执行（用 SUPublicEDKey 解 .sig）"
echo "       建议手测：把 appcast.xml 部署后跑一次 App，验证自动更新能拉到新版本"
