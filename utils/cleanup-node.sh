#!/usr/bin/env bash
set -euo pipefail

# Removes project-local JS build artifacts (node_modules, .nx, dist) under a
# repos root. All are regenerable — node_modules from the lockfile, .nx and dist
# from the next build — but reinstalling is slow, so directories touched within
# the last N days are left alone.

REPOS_ROOT="${CLEANUP_REPOS_ROOT:-$HOME/Documents/git-repos}"
DAYS="${CLEANUP_NODE_DAYS:-14}"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

dry_run=${CLEANUP_DRY_RUN:-false}

echo "=================================================="
echo "[$(ts)] Node/JS Artifact Cleanup$( $dry_run && echo ' (dry run)')"
echo "Scanning: $REPOS_ROOT  (keeping anything used within ${DAYS}d)"
echo "=================================================="

total_freed=0
count=0
kept_kb=0
kept=0

_sweep() {
  local target="$1"
  local size_kb size_mb

  size_kb=$(du -sk "$target" 2>/dev/null | cut -f1)
  size_kb=${size_kb:-0}
  size_mb=$(( size_kb / 1024 ))

  # Recently touched means the project is live — skip it.
  if [[ -z "$(find "$target" -maxdepth 0 -mtime "+${DAYS}" 2>/dev/null)" ]]; then
    kept_kb=$(( kept_kb + size_kb ))
    kept=$(( kept + 1 ))
    echo "  Keeping (active):  $target  (~${size_mb} MB)"
    return
  fi

  if $dry_run; then
    echo "  Would remove: $target  (~${size_mb} MB)"
  else
    echo "  Removing: $target  (~${size_mb} MB)"
    rm -rf "$target"
  fi
  total_freed=$(( total_freed + size_kb ))
  count=$(( count + 1 ))
}

# -prune stops the walk from descending into a matched directory, so nested
# node_modules are never counted or removed twice.
while IFS= read -r dir; do
  _sweep "$dir"
done < <(find "$REPOS_ROOT" -type d -name .git -prune -o \
                            -type d \( -name node_modules -o -name .nx -o -name dist \) -print -prune 2>/dev/null)

total_mb=$(( total_freed / 1024 ))
kept_mb=$(( kept_kb / 1024 ))
echo ""
if $dry_run; then
  echo "[$(ts)] Would remove $count director$([ "$count" -eq 1 ] && echo y || echo ies), freeing ~${total_mb} MB."
else
  echo "[$(ts)] Removed $count director$([ "$count" -eq 1 ] && echo y || echo ies), freed ~${total_mb} MB."
fi
echo "[$(ts)] Kept $kept active director$([ "$kept" -eq 1 ] && echo y || echo ies) (~${kept_mb} MB) — used within ${DAYS}d."

if [[ -n "${CLEANUP_REPORT_FILE:-}" ]]; then
  echo "node_dirs=${count}"                   >> "$CLEANUP_REPORT_FILE"
  echo "node_bytes=$(( total_freed * 1024 ))" >> "$CLEANUP_REPORT_FILE"
fi
