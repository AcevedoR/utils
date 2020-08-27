#!/usr/bin/env bash

file_relative_git_path=$1
if [ -z "$file_relative_git_path" ];
    then
        echo "Usage : sh $0 <file relative git path>"
        exit 1
fi

git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch $file_relative_git_path" \
  --prune-empty --tag-name-filter cat -- --all

echo "This script was guided by https://docs.github.com/en/github/authenticating-to-github/removing-sensitive-data-from-a-repository"
echo "Now you can run 'git push origin --force --all' and 'git push origin --force --tags'"