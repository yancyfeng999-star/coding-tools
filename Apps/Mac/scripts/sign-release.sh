#!/usr/bin/env bash
# Coding Tools · 签名 Release
# 阶段 7 由子代理 C 完善；当前占位
set -euo pipefail

cd "$(dirname "$0")/.."

: "${DEVELOPER_ID:?DEVELOPER_ID not set (e.g. 'Developer ID Application: Your Name (TEAMID)')}"
: "${KEYCHAIN_PROFILE:?KEYCHAIN_PROFILE not set (notarytool credential profile)}"

APP="build/DerivedData/Build/Products/Release/CodingTools.app"

if [[ ! -d "$APP" ]]; then
  echo "❌ $APP not found; run package-release.sh first" >&2
  exit 1
fi

echo "==> Signing with $DEVELOPER_ID"
codesign \
  --deep \
  --force \
  --options runtime \
  --timestamp \
  --sign "$DEVELOPER_ID" \
  "$APP"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --verbose "$APP" || true

echo "✅ Signed: $APP"
