#!/usr/bin/env bash
set -euo pipefail

REPOS_ROOT="${1:-$HOME/Documents/git-repos}"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

dry_run=${CLEANUP_DRY_RUN:-false}

echo "=================================================="
echo "[$(ts)] Gradle Build Directory Cleanup$( $dry_run && echo ' (dry run)')"
echo "Scanning: $REPOS_ROOT"
echo "=================================================="

total_freed=0
count=0

# A Gradle project is marked by build.gradle* OR settings.gradle* — never both.
# In a multi-project build, settings.gradle lives only at the root while build/
# output lives only in the subprojects, so requiring both matches nothing.
_is_gradle_project() {
  local dir="$1"
  compgen -G "$dir/build.gradle*"    >/dev/null && return 0
  compgen -G "$dir/settings.gradle*" >/dev/null && return 0
  return 1
}

_sweep() {
  local target="$1"
  local size_kb size_mb
  size_kb=$(du -sk "$target" 2>/dev/null | cut -f1)
  size_kb=${size_kb:-0}
  size_mb=$(( size_kb / 1024 ))
  if $dry_run; then
    echo "  Would remove: $target  (~${size_mb} MB)"
  else
    echo "  Removing: $target  (~${size_mb} MB)"
    rm -rf "$target"
  fi
  total_freed=$(( total_freed + size_kb ))
  count=$(( count + 1 ))
}

# Gradle output directories (build/) and per-project caches (.gradle/), both
# only inside real Gradle projects. Each is re-created on the next build.
while IFS= read -r dir; do
  _is_gradle_project "$(dirname "$dir")" || continue
  _sweep "$dir"
done < <(find "$REPOS_ROOT" -type d -name node_modules -prune -o \
                            -type d -name .git -prune -o \
                            -type d \( -name build -o -name .gradle \) -print 2>/dev/null)

total_mb=$(( total_freed / 1024 ))
echo ""
if $dry_run; then
  echo "[$(ts)] Would remove $count director$([ "$count" -eq 1 ] && echo y || echo ies), freeing ~${total_mb} MB."
else
  echo "[$(ts)] Removed $count director$([ "$count" -eq 1 ] && echo y || echo ies), freed ~${total_mb} MB."
fi

if [[ -n "${CLEANUP_REPORT_FILE:-}" ]]; then
  echo "gradle_dirs=${count}"                   >> "$CLEANUP_REPORT_FILE"
  echo "gradle_bytes=$(( total_freed * 1024 ))" >> "$CLEANUP_REPORT_FILE"
fi
