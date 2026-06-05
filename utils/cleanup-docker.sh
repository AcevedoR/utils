#!/usr/bin/env bash
set -euo pipefail

ts() { date '+%Y-%m-%d %H:%M:%S'; }

echo "=================================================="
echo "[$(ts)] Docker Cleanup"
echo "=================================================="

echo ""
echo "=== Removing stopped containers ==="
docker container prune -f

echo ""
echo "=== Removing dangling images ==="
docker image prune -f

echo ""
echo "=== Removing all unused images ==="
docker image prune -a -f

echo ""
echo "=== Removing unused volumes ==="
docker volume prune -f

echo ""
echo "=== Removing unused networks ==="
docker network prune -f

echo ""
echo "[$(ts)] Docker cleanup complete."
