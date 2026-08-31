#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

usage() {
  echo "Usage: $0 [--docker] [--gradle] [--caches] [--deep] [--all] [--analyze]"
  echo "  Default (no flags): runs all cleanup scripts"
  echo "  --caches   package-manager & app caches (npm, brew, Spotify, …)"
  echo "  --deep     with --caches/--all, also wipe Gradle/Maven/JetBrains"
  echo "             caches (safe, but re-downloaded/re-indexed next build)"
  echo "  --analyze  skip cleanup, just print disk usage + biggest space hogs"
  exit 1
}

run_docker=false
run_gradle=false
run_caches=false
deep=false
analyze_only=false

if [[ $# -eq 0 ]]; then
  run_docker=true
  run_gradle=true
  run_caches=true
else
  for arg in "$@"; do
    case "$arg" in
      --docker)  run_docker=true ;;
      --gradle)  run_gradle=true ;;
      --caches)  run_caches=true ;;
      --deep)    deep=true ;;
      --all)     run_docker=true; run_gradle=true; run_caches=true ;;
      --analyze) analyze_only=true ;;
      *) usage ;;
    esac
  done
fi

# --deep is meaningless on its own; imply the caches pass.
if $deep && ! $run_caches; then
  run_caches=true
fi

# ── Formatting helpers (needed before anything prints) ─────────────────────

RED=$'\033[0;31m'; ORANGE=$'\033[0;33m'; YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

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

# Colored progress bar of disk usage for the root volume.
disk_summary() {
  local label="$1" width=40
  local line size_kb used_kb avail_kb pct color filled empty bar

  line=$(df -k / | tail -1)
  size_kb=$(awk '{print $2}' <<<"$line")
  used_kb=$(awk '{print $3}' <<<"$line")
  avail_kb=$(awk '{print $4}' <<<"$line")
  pct=$(( used_kb * 100 / size_kb ))

  if   (( pct >= 90 )); then color=$RED
  elif (( pct >= 75 )); then color=$ORANGE
  elif (( pct >= 60 )); then color=$YELLOW
  else color=$GREEN
  fi

  filled=$(( pct * width / 100 ))
  (( filled > width )) && filled=$width
  empty=$(( width - filled ))

  bar="${color}$(printf '█%.0s' $(seq 1 "$filled") 2>/dev/null)${RESET}$(printf '░%.0s' $(seq 1 "$empty") 2>/dev/null)"

  echo "${BOLD}${label}${RESET}"
  echo "[$bar] ${color}${pct}%${RESET} used"
  echo "Used: $(_fmt $((used_kb*1024)))   Avail: $(_fmt $((avail_kb*1024)))   Total: $(_fmt $((size_kb*1024)))"
}

# ── Analysis mode: report only, changes nothing ─────────────────────────────

if $analyze_only; then
  disk_summary "Current Disk Usage"
  echo ""
  echo "${BOLD}Biggest space consumers (report only, nothing deleted):${RESET}"
  echo ""
  {
    du -sk "$HOME/Library/Caches" 2>/dev/null | awk '{print $1"\t~/Library/Caches (run --caches)"}' || true
    du -sk "$HOME/Library/Containers" 2>/dev/null | awk '{print $1"\t~/Library/Containers (sandboxed app data, review manually)"}' || true
    du -sk "$HOME/Library/Logs" 2>/dev/null | awk '{print $1"\t~/Library/Logs (run this script — auto-trims 14d+)"}' || true
    du -sk "$HOME/Downloads" 2>/dev/null | awk '{print $1"\t~/Downloads (review manually)"}' || true
    du -sk "$HOME/.Trash" 2>/dev/null | awk '{print $1"\t~/.Trash (run --caches to empty)"}' || true
    du -sk "$HOME/.npm" 2>/dev/null | awk '{print $1"\t~/.npm (run --caches)"}' || true
    du -sk "$HOME/.gradle/caches" 2>/dev/null | awk '{print $1"\t~/.gradle/caches (run --deep)"}' || true
    du -sk "$HOME/.m2/repository" 2>/dev/null | awk '{print $1"\t~/.m2/repository (run --deep)"}' || true
    du -sk "$HOME/Library/Caches/JetBrains" 2>/dev/null | awk '{print $1"\t~/Library/Caches/JetBrains (run --deep)"}' || true
    du -sk "$HOME/Library/Application Support/MobileSync/Backup" 2>/dev/null | awk '{print $1"\t~/Library/Application Support/MobileSync/Backup (old iOS backups, review manually)"}' || true
  } | sort -rn | awk -F'\t' '{printf "  %8.2f GB   %s\n", $1/1048576, $2}'
  echo ""
  echo "${BOLD}Largest files in ~/Downloads older than 60 days (review manually):${RESET}"
  { { find "$HOME/Downloads" -maxdepth 2 -type f -mtime +60 -exec du -sk {} + 2>/dev/null || true; } \
    | sort -rn | head -10 \
    | awk '{printf "  %8.2f MB   %s\n", $1/1024, substr($0, index($0,$2))}'; } || true
  echo ""
  exit 0
fi

REPORT_FILE=$(mktemp)
export CLEANUP_REPORT_FILE="$REPORT_FILE"
trap 'rm -f "$REPORT_FILE"' EXIT

echo "=================================================="
echo "[$(ts)] macOS Cleanup"
echo "=================================================="
echo ""
disk_summary "Disk Usage — Before"

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
disk_summary "Disk Usage — After"

echo ""
echo "[$(ts)] Done."
