#!/usr/bin/env bash
old_branch=$1
new_branch=$2

if [ -z "$old_branch" ] || [ -z "$new_branch" ];
    then
        echo "usage:\n    git-rename-branch <old_branch> <new_branch>"
        exit 1
fi

git checkout ${old_branch}
git branch -m ${old_branch} ${new_branch}
git push origin :${old_branch} ${new_branch}
git push origin -u ${new_branch}
