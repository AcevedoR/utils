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

echo ""
echo "=================================================="
echo "[$(ts)] All done."
echo "=================================================="
