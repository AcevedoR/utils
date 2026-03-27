package main

import (
	"fmt"
	"os"
	"strings"
)

const usage = `backport — cherry-pick a PR onto one or more branches and open new PRs

Usage:
    backport <PR-number> <branch1> [branch2...]

Example:
    backport 1234 1.2.x develop
`

func main() {
	args := os.Args[1:]
	if len(args) < 2 {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(1)
	}

	prNumber := args[0]
	targets := args[1:]

	if err := checkPrerequisites(); err != nil {
		fatalf("Error: %v\n", err)
	}

	fmt.Printf("Fetching commits from PR #%s...\n", prNumber)
	pr, err := getPR(prNumber)
	if err != nil {
		fatalf("Error: %v\n", err)
	}

	commits := pr.CommitOIDs()
	if len(commits) == 0 {
		fatalf("Error: PR #%s has no commits\n", prNumber)
	}
	fmt.Printf("Found %d commit(s): %s\n\n", len(commits), strings.Join(commits, ", "))

	for _, target := range targets {
		fmt.Printf("── Backporting onto %s\n", target)

		if err := gitFetch(target); err != nil {
			fmt.Fprintf(os.Stderr, "  Error fetching %s: %v\n", target, err)
			continue
		}

		newBranch := fmt.Sprintf("backport/%s-%s", prNumber, strings.ReplaceAll(target, "/", "-"))

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
			fmt.Fprintf(os.Stderr, "      --body \"Backport of #%s\"\n\n", prNumber)
			continue
		}

		if err := gitPush(newBranch); err != nil {
			fmt.Fprintf(os.Stderr, "  Error pushing %s: %v\n", newBranch, err)
			continue
		}

		title := fmt.Sprintf("[Backport %s] %s", target, pr.Title)
		body := fmt.Sprintf("Backport of #%s\n\n---\n%s", prNumber, pr.Body)

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
