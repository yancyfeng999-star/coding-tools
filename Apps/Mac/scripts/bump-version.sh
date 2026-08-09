#!/usr/bin/env bash
# Coding Tools · 升版（patch / minor / major / 指定版本）
set -euo pipefail

cd "$(dirname "$0")/.."

PLIST="Sources/App/Info.plist"
MODE="${1:-patch}"

if [[ "$MODE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  TARGET="$MODE"
else
  CURRENT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
  IFS='.' read -r MAJOR MINOR PATCH <<<"$CURRENT"
  case "$MODE" in
    patch) PATCH=$((PATCH + 1)) ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    *) echo "Usage: $0 [patch|minor|major|x.y.z]" >&2; exit 1 ;;
  esac
  TARGET="$MAJOR.$MINOR.$PATCH"
fi

CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
NEW_BUILD=$((CURRENT_BUILD + 1))

echo "==> Bumping to v$TARGET (build $NEW_BUILD)"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $TARGET" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST"

echo "==> Updating CHANGELOG"
DATE=$(date +%Y-%m-%d)
NEW_HEADER="## [$TARGET] - $DATE"
awk -v h="$NEW_HEADER" '
  /^## \[Unreleased\]/ { print; print ""; print h; print ""; next }
  { print }
' ../../CHANGELOG.md > ../../CHANGELOG.md.new
mv ../../CHANGELOG.md.new ../../CHANGELOG.md

cd ../..
git add Apps/Mac/Sources/App/Info.plist CHANGELOG.md
git commit -m "chore: bump version to v$TARGET (build $NEW_BUILD)"

echo "✅ v$TARGET (build $NEW_BUILD)"
