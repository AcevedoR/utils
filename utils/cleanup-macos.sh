#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

usage() {
  echo "Usage: $0 [--docker] [--gradle] [--all]"
  echo "  Default (no flags): runs all cleanup scripts"
  exit 1
}

run_docker=false
run_gradle=false

if [[ $# -eq 0 ]]; then
  run_docker=true
  run_gradle=true
else
  for arg in "$@"; do
    case "$arg" in
      --docker) run_docker=true ;;
      --gradle) run_gradle=true ;;
      --all)    run_docker=true; run_gradle=true ;;
      *) usage ;;
    esac
  done
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

_line ╠ ╬ ╣
_row "TOTAL" "$(_fmt "$total")"
_line ╚ ╩ ╝

echo ""
echo "[$(ts)] Done."
