#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Cleans regenerable developer / package-manager / application caches.
#   (default)  transparent caches only — re-downloaded/rebuilt on demand,
#              no rebuild-from-scratch cost (npm, bun, brew, playwright,
#              Spotify, Chrome, Trash).
#   --deep     also wipe heavy dev caches that force a re-download or
#              re-index next time you build (Gradle & Maven repos,
#              JetBrains IDE caches/indexes).

ts() { date '+%Y-%m-%d %H:%M:%S'; }

deep=false
for arg in "$@"; do
  case "$arg" in
    --deep) deep=true ;;
    *) ;;
  esac
done

_fmt() {
  awk -v b="${1:-0}" 'BEGIN {
    if (b >= 1073741824) printf "%.2f GB\n", b/1073741824
    else if (b >= 1048576) printf "%.2f MB\n", b/1048576
    else if (b >= 1024)    printf "%.2f kB\n", b/1024
    else                   printf "%d B\n",    b
  }'
}

# Sum the apparent size (in bytes) of the existing paths passed in.
_size_bytes() {
  local total=0 kb p
  for p in "$@"; do
    [[ -e "$p" ]] || continue
    kb=$(du -sk "$p" 2>/dev/null | cut -f1 || echo 0)
    total=$(( total + ${kb:-0} * 1024 ))
  done
  echo "$total"
}

# Measure, remove, and tally. Accumulates into the named bucket variable.
_reclaim() {
  local bucket="$1" label="$2"; shift 2
  local before
  before=$(_size_bytes "$@")
  if [[ "$before" -gt 0 ]]; then
    for p in "$@"; do
      [[ -e "$p" ]] || continue
      rm -rf "$p" 2>/dev/null || true
    done
    printf '  %-24s %s\n' "$label" "freed $(_fmt "$before")"
  else
    printf '  %-24s %s\n' "$label" "nothing to remove"
  fi
  printf -v "$bucket" '%d' "$(( ${!bucket:-0} + before ))"
}

echo "=================================================="
echo "[$(ts)] Cache Cleanup$( $deep && echo ' (deep)')"
echo "=================================================="

pkg_bytes=0
app_bytes=0
dev_bytes=0

# ── Package-manager download caches (transparent) ────────────────────────────
echo ""
echo "=== Package-manager caches ==="
_reclaim pkg_bytes "npm"        "$HOME/.npm/_cacache" "$HOME/.npm/_npx"
_reclaim pkg_bytes "bun"        "$HOME/Library/Caches/bun"
_reclaim pkg_bytes "playwright" "$HOME/Library/Caches/ms-playwright"
if command -v brew >/dev/null 2>&1; then
  brew_cache="$(brew --cache 2>/dev/null || true)"
  before=$(_size_bytes "$brew_cache")
  brew cleanup -s >/dev/null 2>&1 || true
  after=$(_size_bytes "$brew_cache")
  freed=$(( before > after ? before - after : 0 ))
  printf '  %-24s %s\n' "homebrew" "freed $(_fmt "$freed")"
  pkg_bytes=$(( pkg_bytes + freed ))
fi

# ── Application caches (transparent) ──────────────────────────────────────────
echo ""
echo "=== Application caches ==="
_reclaim app_bytes "spotify"     "$HOME/Library/Caches/com.spotify.client"
_reclaim app_bytes "chrome"      "$HOME/Library/Caches/Google"
_reclaim app_bytes "*-updaters"  $HOME/Library/Caches/*-updater
_reclaim app_bytes "trash"       "$HOME/.Trash"/* "$HOME/.Trash"/.[!.]*

# ── Heavy dev caches (re-download / re-index on next build) ───────────────────
if $deep; then
  echo ""
  echo "=== Dev tool caches (deep) ==="
  _reclaim dev_bytes "gradle"    "$HOME/.gradle/caches" "$HOME/.gradle/daemon"
  _reclaim dev_bytes "maven"     "$HOME/.m2/repository"
  _reclaim dev_bytes "jetbrains" "$HOME/Library/Caches/JetBrains"
fi

total=$(( pkg_bytes + app_bytes + dev_bytes ))
echo ""
echo "[$(ts)] Cache cleanup complete — freed $(_fmt "$total")."

if [[ -n "${CLEANUP_REPORT_FILE:-}" ]]; then
  {
    echo "caches_pkg=${pkg_bytes}"
    echo "caches_app=${app_bytes}"
    echo "caches_dev=${dev_bytes}"
  } >> "$CLEANUP_REPORT_FILE"
fi
