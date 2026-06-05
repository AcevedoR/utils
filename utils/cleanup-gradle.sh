#!/usr/bin/env bash
set -euo pipefail

REPOS_ROOT="${1:-$HOME/Documents/git-repos}"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

echo "=================================================="
echo "[$(ts)] Gradle Build Directory Cleanup"
echo "Scanning: $REPOS_ROOT"
echo "=================================================="

total_freed=0
count=0

while IFS= read -r build_dir; do
  parent="$(dirname "$build_dir")"
  # Only treat as Gradle output if a Gradle file exists alongside it
  if ! ls "$parent"/build.gradle* "$parent"/settings.gradle* &>/dev/null 2>&1; then
    continue
  fi

  size_kb=$(du -sk "$build_dir" 2>/dev/null | cut -f1)
  size_mb=$(( size_kb / 1024 ))
  echo "  Removing: $build_dir  (~${size_mb} MB)"
  rm -rf "$build_dir"
  total_freed=$(( total_freed + size_kb ))
  count=$(( count + 1 ))
done < <(find "$REPOS_ROOT" -type d -name "build" -not -path "*/.git/*" 2>/dev/null)

total_mb=$(( total_freed / 1024 ))
echo ""
echo "[$(ts)] Removed $count build director$([ "$count" -eq 1 ] && echo y || echo ies), freed ~${total_mb} MB."

if [[ -n "${CLEANUP_REPORT_FILE:-}" ]]; then
  echo "gradle_dirs=${count}"            >> "$CLEANUP_REPORT_FILE"
  echo "gradle_bytes=$(( total_freed * 1024 ))" >> "$CLEANUP_REPORT_FILE"
fi
