package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
)

const usage = `backport — cherry-pick a PR onto one or more branches and open new PRs

Usage:
    backport <PR-number> <branch1> [branch2...]   explicit PR
    backport --to <branch1> [--to <branch2>...]   auto-detect PR from current branch

Examples:
    backport 1234 1.2.x develop
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

	var prNumber string
	var targets []string

	switch {
	case len(toFlags) > 0 && flag.NArg() == 0:
		// auto-detect mode: --to branch1 --to branch2
		targets = toFlags
	case len(toFlags) == 0 && flag.NArg() >= 2:
		// explicit mode: <PR-number> <branch1> [branch2...]
		prNumber = flag.Arg(0)
		targets = flag.Args()[1:]
	default:
		fmt.Fprint(os.Stderr, usage)
		os.Exit(1)
	}

	var pr PR
	var err error

	if prNumber == "" {
		fmt.Println("Detecting PR for current branch...")
		pr, err = getPR("")
	} else {
		fmt.Printf("Fetching commits from PR #%s...\n", prNumber)
		pr, err = getPR(prNumber)
	}
	if err != nil {
		fatalf("Error: %v\n", err)
	}

	commits := pr.CommitOIDs()
	if len(commits) == 0 {
		fatalf("Error: PR #%d has no commits\n", pr.Number)
	}
	fmt.Printf("PR #%d: %s\n", pr.Number, pr.Title)
	fmt.Printf("Found %d commit(s): %s\n\n", len(commits), strings.Join(commits, ", "))

	for _, target := range targets {
		fmt.Printf("── Backporting onto %s\n", target)

		if err := gitFetch(target); err != nil {
			fmt.Fprintf(os.Stderr, "  Error fetching %s: %v\n", target, err)
			continue
		}

		newBranch := fmt.Sprintf("backport/%d-%s", pr.Number, strings.ReplaceAll(target, "/", "-"))

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
			fmt.Fprintf(os.Stderr, "      --title \"[Backport %s] %s\" \\\n", target, pr.Title)
			fmt.Fprintf(os.Stderr, "      --body \"Backport of #%d\"\n\n", pr.Number)
			continue
		}

		if err := gitPush(newBranch); err != nil {
			fmt.Fprintf(os.Stderr, "  Error pushing %s: %v\n", newBranch, err)
			continue
		}

		title := fmt.Sprintf("[Backport %s] %s", target, pr.Title)
		body := fmt.Sprintf("Backport of #%d\n\n---\n%s", pr.Number, pr.Body)

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
