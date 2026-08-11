#!/usr/bin/env bash
# Coding Tools · 升版（patch / minor / major / 指定版本）
#
# 阶段 7 完善：
# - 校验 git 工作区干净
# - 校验 tag 未占用
# - 生成 CHANGELOG 段（如果不存在）
# - 用 [Unreleased] → [X.Y.Z] 模式
# - git add + commit
#
# 用法：
#   ./scripts/bump-version.sh patch         # 0.0.0 → 0.0.1
#   ./scripts/bump-version.sh minor         # 0.0.0 → 0.1.0
#   ./scripts/bump-version.sh major         # 0.0.0 → 1.0.0
#   ./scripts/bump-version.sh 1.2.3         # 直接指定
#   ./scripts/bump-version.sh --check       # 仅显示当前版本，不修改
set -euo pipefail

cd "$(dirname "$0")/.."

PLIST="Sources/App/Info.plist"
CHANGELOG="../../CHANGELOG.md"

usage() {
  cat <<EOF
bump-version.sh — 升版 Info.plist + CHANGELOG

用法：
  ./scripts/bump-version.sh [patch|minor|major|x.y.z]   # 默认 patch
  ./scripts/bump-version.sh --check                     # 查看当前版本
  ./scripts/bump-version.sh --help                      # 显示帮助

环境变量：
  SKIP_GIT  1 = 不 git commit（CI 场景）
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

MODE="${1:-patch}"

if [[ "$MODE" == "--check" ]]; then
  CUR=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
  BLD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
  echo "current: v$CUR (build $BLD)"
  exit 0
fi

# 工作区干净校验（排除非 owned paths）
if [[ "${SKIP_GIT:-0}" != "1" ]]; then
  if [[ -n "$(git -C ../.. status --porcelain -- ':(exclude).multi-agent-collaboration/**' 2>/dev/null || true)" ]]; then
    echo "❌ 工作区有未提交改动（已排除 .multi-agent-collaboration 协作目录）" >&2
    git -C ../.. status --short >&2
    exit 1
  fi
fi

# 计算新版本
if [[ "$MODE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  TARGET="$MODE"
else
  CURRENT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
  IFS='.' read -r MAJOR MINOR PATCH <<<"$CURRENT"
  case "$MODE" in
    patch) PATCH=$((PATCH + 1)) ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    *) echo "❌ Usage: $0 [patch|minor|major|x.y.z]" >&2; exit 1 ;;
  esac
  TARGET="$MAJOR.$MINOR.$PATCH"
fi

# Tag 占用校验
if [[ "${SKIP_GIT:-0}" != "1" ]]; then
  if git -C ../.. rev-parse "v$TARGET" >/dev/null 2>&1; then
    echo "❌ tag v$TARGET 已存在" >&2
    exit 1
  fi
fi

CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
NEW_BUILD=$((CURRENT_BUILD + 1))

echo "==> Bumping to v$TARGET (build $NEW_BUILD)"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $TARGET" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST"

# CHANGELOG 段不再由本脚本写入：
# - 旧逻辑会在 ## [Unreleased] 后插入裸 header（缺 ### Changed 与 - 暂未发布 body），
#   与 release.sh 的 Python 段二次写入会产生重复段。
# - 现在由 release.sh 的 Python 段统一负责（在标准 marker 之后一次性插入完整段落）。
# - 若单独跑本脚本（如本地 dry-run），CHANGELOG 不会变；后续 release.sh 会补齐。

# git commit（只提交 Info.plist）
if [[ "${SKIP_GIT:-0}" != "1" ]]; then
  cd ../..
  git add Apps/Mac/Sources/App/Info.plist
  git commit -m "chore: bump version to v$TARGET (build $NEW_BUILD)"
fi

echo "✅ v$TARGET (build $NEW_BUILD)"
