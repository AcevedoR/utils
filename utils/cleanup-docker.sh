#!/usr/bin/env bash
set -euo pipefail

ts() { date '+%Y-%m-%d %H:%M:%S'; }

_parse_bytes() {
  local val unit
  val=$(printf '%s' "$1" | grep -oE '[0-9]+\.?[0-9]*' || echo 0)
  unit=$(printf '%s' "$1" | grep -oE '[a-zA-Z]+' || echo B)
  awk -v v="${val:-0}" -v u="${unit:-B}" 'BEGIN {
    if (u == "GB") printf "%d\n", v * 1073741824
    else if (u == "MB") printf "%d\n", v * 1048576
    else if (u == "kB") printf "%d\n", v * 1024
    else printf "%d\n", v
  }'
}

_prune() {
  local label="$1" key="$2"; shift 2
  echo ""
  echo "=== ${label} ==="
  local out
  out=$("$@" 2>&1) || true
  printf '%s\n' "$out"
  if [[ -n "${CLEANUP_REPORT_FILE:-}" ]]; then
    local size_str bytes
    size_str=$(printf '%s' "$out" | grep 'Total reclaimed space:' | grep -oE '[0-9]+\.?[0-9]*[a-zA-Z]+' || echo "0B")
    bytes=$(_parse_bytes "$size_str")
    echo "${key}=${bytes}" >> "$CLEANUP_REPORT_FILE"
  fi
}

echo "=================================================="
echo "[$(ts)] Docker Cleanup"
echo "=================================================="

_prune "Removing stopped containers" docker_containers  docker container prune -f
_prune "Removing dangling images"    docker_dangling    docker image prune -f
_prune "Removing all unused images"  docker_images      docker image prune -a -f
_prune "Removing unused volumes"     docker_volumes     docker volume prune -f
_prune "Removing unused networks"    docker_networks    docker network prune -f

echo ""
echo "[$(ts)] Docker cleanup complete."
