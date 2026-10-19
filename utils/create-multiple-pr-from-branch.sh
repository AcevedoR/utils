#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <count>"
  exit 1
fi

COUNT="$1"
BASE="run-develop-tests-second-batch"

# Find the highest existing increment
get_last_num() {
  git branch -a --format='%(refname:short)' \
    | grep -E "^${BASE}-[0-9]+$" \
    | sed -E "s/^${BASE}-([0-9]+)$/\1/" \
    | sort -n \
    | tail -1
}

last_num=$(get_last_num)
if [[ -z "${last_num}" ]]; then
  last_num=0
fi

for ((i=1; i<=COUNT; i++)); do
  next_num=$((last_num + i))
  new_branch="${BASE}-${next_num}"

  echo "=== Creating branch: ${new_branch}"

  # Create from current branch
  git checkout -b "${new_branch}"

  # Push it
  git push -u origin "${new_branch}"

  gh pr create --fill --base develop
done

echo "All ${COUNT} branches created and pushed."
