#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

usage() {
  echo "Usage: $0 [--docker] [--gradle] [--caches] [--deep] [--all]"
  echo "  Default (no flags): runs all cleanup scripts"
  echo "  --caches   package-manager & app caches (npm, brew, Spotify, …)"
  echo "  --deep     with --caches/--all, also wipe Gradle/Maven/JetBrains"
  echo "             caches (safe, but re-downloaded/re-indexed next build)"
  exit 1
}

run_docker=false
run_gradle=false
run_caches=false
deep=false

if [[ $# -eq 0 ]]; then
  run_docker=true
  run_gradle=true
  run_caches=true
else
  for arg in "$@"; do
    case "$arg" in
      --docker) run_docker=true ;;
      --gradle) run_gradle=true ;;
      --caches) run_caches=true ;;
      --deep)   deep=true ;;
      --all)    run_docker=true; run_gradle=true; run_caches=true ;;
      *) usage ;;
    esac
  done
fi

# --deep is meaningless on its own; imply the caches pass.
if $deep && ! $run_caches; then
  run_caches=true
fi

REPORT_FILE=$(mktemp)
export CLEANUP_REPORT_FILE="$REPORT_FILE"
trap 'rm -f "$REPORT_FILE"' EXIT

echo "=================================================="
echo "[$(ts)] macOS Cleanup"
echo "=================================================="

if $run_docker; then
  echo ""
  bash "$SCRIPT_DIR/cleanup-docker.sh"
fi

if $run_gradle; then
  echo ""
  bash "$SCRIPT_DIR/cleanup-gradle.sh"
fi

if $run_caches; then
  echo ""
  if $deep; then
    bash "$SCRIPT_DIR/cleanup-caches.sh" --deep
  else
    bash "$SCRIPT_DIR/cleanup-caches.sh"
  fi
fi

# ── Report helpers ──────────────────────────────────────────────────────────

_rpt()  { grep -m1 "^${1}=" "$REPORT_FILE" 2>/dev/null | cut -d= -f2 || echo 0; }

_fmt() {
  awk -v b="${1:-0}" 'BEGIN {
    if (b >= 1073741824) printf "%.2f GB\n", b/1073741824
    else if (b >= 1048576) printf "%.2f MB\n", b/1048576
    else if (b >= 1024)    printf "%.2f kB\n", b/1024
    else                   printf "%d B\n",    b
  }'
}

_row()  { printf "║  %-33s║ %13s ║\n" "$1" "$2"; }
_line() { printf "${1}%s${2}%s${3}\n" "$(printf '═%.0s' {1..35})" "$(printf '═%.0s' {1..15})"; }

# ── Collect numbers ─────────────────────────────────────────────────────────

total=0

if $run_docker; then
  d_containers=$(_rpt docker_containers)
  d_dangling=$(_rpt docker_dangling)
  d_images=$(_rpt docker_images)
  d_volumes=$(_rpt docker_volumes)
  total=$(( total + d_containers + d_dangling + d_images + d_volumes ))
fi

if $run_gradle; then
  g_dirs=$(_rpt gradle_dirs)
  g_bytes=$(_rpt gradle_bytes)
  total=$(( total + g_bytes ))
fi

if $run_caches; then
  c_pkg=$(_rpt caches_pkg)
  c_app=$(_rpt caches_app)
  c_dev=$(_rpt caches_dev)
  total=$(( total + c_pkg + c_app + c_dev ))
fi

# ── Print table ──────────────────────────────────────────────────────────────

echo ""
_line ╔ ╦ ╗
_row "Cleanup Summary" "Space Freed"
_line ╠ ╬ ╣

if $run_docker; then
  _row "Stopped containers"       "$(_fmt "$d_containers")"
  _row "Dangling images"          "$(_fmt "$d_dangling")"
  _row "Unused images"            "$(_fmt "$d_images")"
  _row "Unused volumes"           "$(_fmt "$d_volumes")"
  _row "Unused networks"          "—"
fi

if $run_gradle; then
  _row "Gradle build dirs (${g_dirs} removed)" "$(_fmt "$g_bytes")"
fi

if $run_caches; then
  _row "Package-manager caches"    "$(_fmt "$c_pkg")"
  _row "Application caches"         "$(_fmt "$c_app")"
  $deep && _row "Dev tool caches (deep)"  "$(_fmt "$c_dev")"
fi

_line ╠ ╬ ╣
_row "TOTAL" "$(_fmt "$total")"
_line ╚ ╩ ╝

echo ""
echo "[$(ts)] Done."
