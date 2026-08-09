#!/usr/bin/env bash
# Coding Tools · Debug 构建
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> tuist install"
tuist install

echo "==> tuist generate (--no-binary-cache for test targets)"
tuist generate CodingTools --no-binary-cache

echo "==> xcodebuild Debug"
xcodebuild build \
  -workspace CodingTools.xcworkspace \
  -scheme CodingTools \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath ./build/DerivedData

echo "✅ Build OK"
