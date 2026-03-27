#!/usr/bin/env bash

branch="$1"
if [ -z "$branch" ]; then
    echo "usage: kcheckout <branch>"
    exit 1
fi

# Locate kestra and kestra-ee directories.
# Works from inside either repo, or from a parent directory containing both.
current_dir=$(pwd)
git_root=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -n "$git_root" ]; then
    repo_name=$(basename "$git_root")
    parent_dir=$(dirname "$git_root")

    if [ "$repo_name" = "kestra" ]; then
        kestra_dir="$git_root"
        kestra_ee_dir="$parent_dir/kestra-ee"
    elif [ "$repo_name" = "kestra-ee" ]; then
        kestra_ee_dir="$git_root"
        kestra_dir="$parent_dir/kestra"
    else
        kestra_dir="$current_dir/kestra"
        kestra_ee_dir="$current_dir/kestra-ee"
    fi
else
    kestra_dir="$current_dir/kestra"
    kestra_ee_dir="$current_dir/kestra-ee"
fi

exit_code=0

checkout() {
    local dir="$1"
    local name="$2"

    if [ ! -d "$dir" ]; then
        echo "[$name] directory not found: $dir"
        exit_code=1
        return
    fi

    echo "[$name] checking out $branch..."
    if git -C "$dir" checkout "$branch"; then
        echo "[$name] done"
    else
        exit_code=1
    fi
}

checkout "$kestra_dir" "kestra"
checkout "$kestra_ee_dir" "kestra-ee"

exit $exit_code
