package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
)

const usage = `backport — cherry-pick a PR or commit onto one or more branches and open new PRs

Usage:
    backport <PR-number> <branch1> [branch2...]   explicit PR number
    backport <commit-sha> <branch1> [branch2...]  explicit commit SHA (7–40 hex chars)
    backport --to <branch1> [--to <branch2>...]   auto-detect PR from current branch

Examples:
    backport 1234 1.2.x develop
    backport b41d0ce 1.2.x develop
    backport --to 1.2.x --to develop
`

// stringSlice is a multi-value flag (--to can be repeated).
type stringSlice []string

func (s *stringSlice) String() string     { return strings.Join(*s, ", ") }
func (s *stringSlice) Set(v string) error { *s = append(*s, v); return nil }

func main() {
	var toFlags stringSlice
	flag.Var(&toFlags, "to", "target branch to backport onto (repeatable)")
	flag.Usage = func() { fmt.Fprint(os.Stderr, usage) }
	flag.Parse()

	if err := checkPrerequisites(); err != nil {
		fatalf("Error: %v\n", err)
	}

	var firstArg string
	var targets []string

	switch {
	case len(toFlags) > 0 && flag.NArg() == 0:
		// auto-detect mode: --to branch1 --to branch2
		targets = toFlags
	case len(toFlags) == 0 && flag.NArg() >= 2:
		// explicit mode: <PR-number-or-commit-sha> <branch1> [branch2...]
		firstArg = flag.Arg(0)
		targets = flag.Args()[1:]
	default:
		fmt.Fprint(os.Stderr, usage)
		os.Exit(1)
	}

	// Resolve commits and display title from either a PR or a single commit SHA.
	var commits []string
	var backportTitle string
	var backportBody string
	var backportRef string // used in branch name: PR number or short SHA

	if isCommitSHA(firstArg) {
		fmt.Printf("Fetching commit %s...\n", firstArg)
		info, err := getCommitInfo(firstArg)
		if err != nil {
			fatalf("Error: %v\n", err)
		}
		shortSHA := info.SHA
		if len(shortSHA) > 8 {
			shortSHA = shortSHA[:8]
		}
		commits = []string{info.SHA}
		backportTitle = info.Subject
		backportBody = info.Body
		backportRef = shortSHA
		fmt.Printf("Commit %s: %s\n", shortSHA, info.Subject)
		fmt.Printf("Found 1 commit\n\n")
	} else {
		var pr PR
		var err error
		if firstArg == "" {
			fmt.Println("Detecting PR for current branch...")
			pr, err = getPR("")
		} else {
			fmt.Printf("Fetching commits from PR #%s...\n", firstArg)
			pr, err = getPR(firstArg)
		}
		if err != nil {
			fatalf("Error: %v\n", err)
		}
		commits = pr.CommitOIDs()
		if len(commits) == 0 {
			fatalf("Error: PR #%d has no commits\n", pr.Number)
		}
		backportTitle = pr.Title
		backportBody = pr.Body
		backportRef = fmt.Sprintf("%d", pr.Number)
		fmt.Printf("PR #%d: %s\n", pr.Number, pr.Title)
		fmt.Printf("Found %d commit(s): %s\n\n", len(commits), strings.Join(commits, ", "))
	}

	for _, target := range targets {
		fmt.Printf("── Backporting onto %s\n", target)

		if err := gitFetch(target); err != nil {
			fmt.Fprintf(os.Stderr, "  Error fetching %s: %v\n", target, err)
			continue
		}

		newBranch := fmt.Sprintf("backport/%s-%s", backportRef, strings.ReplaceAll(target, "/", "-"))

		if err := gitCreateAndCheckout(newBranch, target); err != nil {
			fmt.Fprintf(os.Stderr, "  Error creating branch %s: %v\n", newBranch, err)
			continue
		}

		if err := gitCherryPick(commits); err != nil {
			fmt.Fprintf(os.Stderr, "  Error: cherry-pick conflict on %s\n", target)
			fmt.Fprintf(os.Stderr, "  %v\n\n", err)
			fmt.Fprintf(os.Stderr, "  Resolve conflicts manually, then run:\n")
			fmt.Fprintf(os.Stderr, "    git cherry-pick --continue\n")
			fmt.Fprintf(os.Stderr, "    git push origin %s\n", newBranch)
			fmt.Fprintf(os.Stderr, "    gh pr create --base %s \\\n", target)
			fmt.Fprintf(os.Stderr, "      --title \"[Backport %s] %s\" \\\n", target, backportTitle)
			if isCommitSHA(firstArg) {
				fmt.Fprintf(os.Stderr, "      --body \"Backport of commit %s\"\n\n", backportRef)
			} else {
				fmt.Fprintf(os.Stderr, "      --body \"Backport of #%s\"\n\n", backportRef)
			}
			continue
		}

		if err := gitPush(newBranch); err != nil {
			fmt.Fprintf(os.Stderr, "  Error pushing %s: %v\n", newBranch, err)
			continue
		}

		title := fmt.Sprintf("[Backport %s] %s", target, backportTitle)
		var body string
		if isCommitSHA(firstArg) {
			body = fmt.Sprintf("Backport of commit %s\n\n---\n%s", backportRef, backportBody)
		} else {
			body = fmt.Sprintf("Backport of #%s\n\n---\n%s", backportRef, backportBody)
		}

		url, err := createPR(target, title, body)
		if err != nil {
			fmt.Fprintf(os.Stderr, "  Error creating PR: %v\n", err)
			continue
		}

		fmt.Printf("  PR created: %s\n\n", url)
	}
}

func fatalf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format, args...)
	os.Exit(1)
}
