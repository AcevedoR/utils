# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Scripts to streamline daily git and GitHub tasks. Four areas:

- **Branch management** — create, switch, clean up, rename branches; extends scripts in the parent directory
- **PR workflows** — create/draft PRs, check status, auto-fill descriptions, merge
- **Commit workflows** — stage helpers, conventional commit formatting, amend shortcuts
- **GitHub automation** — issues, labels, milestones, releases via `gh` API

## Dependencies

- `git` — must be in PATH
- `gh` CLI (GitHub CLI) — must be in PATH and authenticated (`gh auth status`)

## Script Conventions

- Shebang: `#!/usr/bin/env bash`
- Validate required args with `[ -z "$var" ]` → print usage + `exit 1`
- Use `gh` CLI for all GitHub API calls (not raw `curl`)
- Name scripts by area prefix: `pr-*.sh`, `commit-*.sh`, `branch-*.sh`, `gh-*.sh`
- Output goes to stdout; keep messages concise and actionable

## Tools

### `backport/` — Go CLI

Cherry-picks all commits from a PR onto one or more target branches and opens new PRs.

```
backport <PR-number> <branch1> [branch2...]
```

**Build:** `cd backport && go build -o backport .`

**Install locally:** `cd backport && make install` (uses goreleaser, installs to `/usr/local/bin/backport`)

**Release:** tag a commit and run `goreleaser release --clean` from `backport/`

**How it works:**
1. Fetches PR metadata (title, body, commits) via `gh pr view`
2. For each target branch: creates `backport/<PR>-<branch>`, cherry-picks, pushes, opens PR
3. New PR title: `[Backport <target>] <original title>`, body references original PR
4. On cherry-pick conflict: aborts cleanly and prints manual steps to stderr
