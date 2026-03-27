package main

import (
	"fmt"
	"os/exec"
	"strings"
)

func checkPrerequisites() error {
	if err := exec.Command("git", "rev-parse", "--git-dir").Run(); err != nil {
		return fmt.Errorf("not inside a git repository")
	}
	if err := exec.Command("gh", "auth", "status").Run(); err != nil {
		return fmt.Errorf("gh CLI is not authenticated — run: gh auth login")
	}
	return nil
}

func gitFetch(branch string) error {
	return run("git", "fetch", "origin", branch)
}

func gitCreateAndCheckout(newBranch, fromBranch string) error {
	return run("git", "checkout", "-b", newBranch, "origin/"+fromBranch)
}

func gitCherryPick(commits []string) error {
	args := append([]string{"cherry-pick"}, commits...)
	cmd := exec.Command("git", args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		// abort so the repo is left clean
		_ = run("git", "cherry-pick", "--abort")
		return fmt.Errorf("cherry-pick failed:\n%s", strings.TrimSpace(string(out)))
	}
	return nil
}

func gitPush(branch string) error {
	return run("git", "push", "origin", branch)
}

func run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s %s failed: %s", name, strings.Join(args, " "), strings.TrimSpace(string(out)))
	}
	return nil
}
