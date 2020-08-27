#!/usr/bin/env bash

old_branch="$(git rev-parse --abbrev-ref HEAD)"
echo "old_branch: $old_branch"
new_branch="$(echo $old_branch | sed -e 's/^study/feature/g')"
echo "new_branch: $new_branch"

git-rename-branch $old_branch $new_branch

