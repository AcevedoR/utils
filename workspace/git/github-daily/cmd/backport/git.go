package main

import (
	"fmt"
	"os/exec"
	"regexp"
	"strings"
)

var commitSHARegex = regexp.MustCompile(`^[0-9a-f]{7,40}$`)

func isCommitSHA(s string) bool {
	return commitSHARegex.MatchString(s)
}

type CommitInfo struct {
	SHA     string
	Subject string
	Body    string
}

func getCommitInfo(sha string) (CommitInfo, error) {
	subject, err := gitLogFormat(sha, "%s")
	if err != nil {
		return CommitInfo{}, fmt.Errorf("commit %s not found: %w", sha, err)
	}
	body, _ := gitLogFormat(sha, "%b")
	full, _ := gitLogFormat(sha, "%H")
	if full == "" {
		full = sha
	}
	return CommitInfo{SHA: full, Subject: strings.TrimSpace(subject), Body: strings.TrimSpace(body)}, nil
}

func gitLogFormat(sha, format string) (string, error) {
	cmd := exec.Command("git", "log", "-1", "--format="+format, sha)
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

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
