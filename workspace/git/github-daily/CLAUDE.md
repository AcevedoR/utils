# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Scripts to streamline daily git and GitHub tasks. Four areas:

- **Branch management** — create, switch, clean up, rename branches; extends scripts in the parent directory
- **PR workflows** — create/draft PRs, check status, auto-fill descriptions, merge
- **Commit workflows** — stage helpers, conventional commit formatting, amend shortcuts
- **GitHub automation** — issues, labels, milestones, releases via `gh` API

## Project structure

Single Go module at this directory level. Each binary lives under `cmd/`:

```
github-daily/
├── go.mod
├── Makefile
├── .goreleaser.yaml
└── cmd/
    ├── backport/
    └── kcheckout/
```

## Dependencies

- `git` — must be in PATH
- `gh` CLI (GitHub CLI) — must be in PATH and authenticated (`gh auth status`)

## Build & install

**After every change, run:**
```
make install
```
This builds all binaries and installs them to `/usr/local/bin/`.

**Release:** tag a commit and run `goreleaser release --clean` from this directory.

## Commands

### `backport` — cherry-pick a PR onto other branches

```
backport <PR-number> <branch1> [branch2...]   explicit PR
backport --to <branch1> [--to <branch2>...]   auto-detect PR from current branch
```

Fetches PR metadata via `gh pr view`, cherry-picks all commits onto each target branch, and opens new PRs. New PR title: `[Backport <target>] <original title>`. On conflict: aborts cleanly and prints manual steps to stderr.

### `kcheckout` — checkout a branch in both kestra repos

```
kcheckout <branch>
```

Runs `git checkout <branch>` then `git pull` in both `kestra` and `kestra-ee`, in parallel. Can be run from inside either repo or from their parent directory.
