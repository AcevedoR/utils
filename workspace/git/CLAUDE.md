# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

A collection of Git utility shell scripts for branch management and history rewriting.

## Scripts Overview

| Script | Purpose |
|--------|---------|
| `git-delete-local-gone-branches.sh` | Deletes local branches whose remotes have been pruned |
| `git-remove-file-from-history.sh <file>` | Rewrites history to remove a file from all commits; requires force push afterward |
| `git-rename-branch.sh <old> <new>` | Renames a branch locally and on the remote |
| `git-rename-current-branch-to-feature.sh` | Renames current branch from `study/*` → `feature/*` |
| `git-rename-current-branch-to-study.sh` | Renames current branch from `feature/*` → `study/*` |

## Script Dependencies

The two convenience rename scripts depend on `git-rename-branch.sh` being executable and in `PATH`.

## Conventions

- All scripts use `#!/usr/bin/env bash`
- Arguments are validated at the top; scripts exit with usage info if required args are missing
- Scripts perform destructive Git operations (force push, history rewrite) — these are intentional and expected
