#!/usr/bin/env bash
# 注销并删除本地多余的 Coding Tools.app，避免启动台 / Spotlight 出现多份。
# 永不触碰 /Applications/Coding Tools.app；废纸篓里的副本只注销不删除。
#
# 用法：
#   ./scripts/cleanup-local-app-products.sh              # 扫描默认残留根目录
#   SWEEP=0 ./scripts/cleanup-local-app-products.sh PATH # 只处理给定路径
#   UNREGISTER_ONLY=1 ./scripts/cleanup-local-app-products.sh PATH
set -euo pipefail

cd "$(dirname "$0")/.."
REPO_ROOT="$(cd ../.. && pwd)"
APP_NAME="Coding Tools.app"
PROTECTED="/Applications/Coding Tools.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
SWEEP="${SWEEP:-1}"
UNREGISTER_ONLY="${UNREGISTER_ONLY:-0}"

resolved_path() {
  local p="$1"
  if [[ -d "$p" ]]; then
    (cd "$p" && pwd)
  elif [[ -e "$p" ]]; then
    echo "$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
  else
    echo "$p"
  fi
}

is_protected() {
  local resolved
  resolved="$(resolved_path "$1")"
  [[ "$resolved" == "$PROTECTED" ]]
}

is_trash() {
  local resolved
  resolved="$(resolved_path "$1")"
  [[ "$resolved" == "$HOME/.Trash"/* ]]
}

unregister_app() {
  local app="$1"
  [[ -x "$LSREGISTER" ]] || return 0
  "$LSREGISTER" -u "$app" >/dev/null 2>&1 || true
  local updater="$app/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
  if [[ -d "$updater" ]]; then
    "$LSREGISTER" -u "$updater" >/dev/null 2>&1 || true
  fi
}

handle_app() {
  local app="$1"
  [[ -d "$app" ]] || return 0
  if is_protected "$app"; then
    echo "    skip protected $app"
    return 0
  fi
  unregister_app "$app"
  if is_trash "$app"; then
    echo "    unregistered trash copy (not deleted): $app"
    return 0
  fi
  if [[ "$UNREGISTER_ONLY" == "1" ]]; then
    echo "    unregistered $app"
    return 0
  fi
  rm -rf "$app"
  echo "    removed $app"
}

collect_apps_under() {
  local root="$1"
  [[ -e "$root" ]] || return 0
  local base
  base="$(basename "$root")"
  if [[ "$base" == "$APP_NAME" || "$base" == "Coding Tools"*.app ]]; then
    printf '%s\0' "$root"
    return 0
  fi
  [[ -d "$root" ]] || return 0
  find "$root" \( -name "$APP_NAME" -o -name "Coding Tools *.app" \) -type d -prune -print0 2>/dev/null
}

roots=()
if [[ "$SWEEP" == "1" ]]; then
  roots+=(
    "$REPO_ROOT/Apps/Mac/build"
    "$REPO_ROOT/releases"
    "$HOME/Library/Developer/Xcode/DerivedData"/CodingTools-*
    /tmp
    /private/tmp
    "$HOME/.Trash"
  )
  if [[ -n "${TMPDIR:-}" ]]; then
    roots+=("$TMPDIR")
  fi
fi
roots+=("$@")

echo "==> cleanup leftover ${APP_NAME} (protected: $PROTECTED)"
seen=""
for root in "${roots[@]}"; do
  while IFS= read -r -d '' app; do
    resolved="$(resolved_path "$app")"
    case " $seen " in
      *" $resolved "*) continue ;;
    esac
    seen+=" $resolved"
    handle_app "$resolved"
  done < <(collect_apps_under "$root")
done

if [[ "$SWEEP" == "1" && "$UNREGISTER_ONLY" != "1" ]]; then
  rm -rf "$REPO_ROOT/Apps/Mac/build/DerivedData-residuals"
  rm -f "$REPO_ROOT/Apps/Mac/build/residuals-tests.log"
  if [[ -n "${TMPDIR:-}" ]]; then
    rm -rf "${TMPDIR%/}"/coding-tools-local-build.*
    rm -rf "${TMPDIR%/}"/grok-goal-*/implementer/DerivedData
  fi
fi
