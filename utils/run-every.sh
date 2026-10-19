#!/usr/bin/env bash
# Run a command every X seconds, without clearing or formatting.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <seconds> <command...>"
  exit 1
fi

interval=$1
shift
cmd="$*"

while true; do
  echo "-------------------------------------------------"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Run '$cmd' every $interval"
  bash -c "$cmd"
  echo
  sleep "$interval"
done
