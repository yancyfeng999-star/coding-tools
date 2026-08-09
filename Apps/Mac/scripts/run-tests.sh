#!/usr/bin/env bash
# Coding Tools · 跑测试
# 注意：
# 1. Tuist 4.203.1 静默忽略 .unitTests target 除非显式 scheme 引用它们
# 2. AppTests 暂时排除：需要 .app 作为 test host，在 CLI 环境下 LSUIElement 启动会失败
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> tuist install"
tuist install

echo "==> tuist generate"
tuist generate

echo "==> Build CodingTools (target + tests)"
xcodebuild build \
  -workspace CodingTools.xcworkspace \
  -scheme CodingTools \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath ./build/DerivedData

echo "==> Run 4 unit test modules"
for scheme in DomainTests CatalogTests InstallerTests ManifestSecurityTests; do
  echo "  --- $scheme ---"
  xcodebuild test \
    -workspace CodingTools.xcworkspace \
    -scheme "$scheme" \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath ./build/DerivedData \
    -quiet \
    2>&1 | tail -3
done

echo "✅ Tests OK"
