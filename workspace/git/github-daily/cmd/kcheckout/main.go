package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const usage = `kcheckout — checkout a branch in both kestra and kestra-ee repos

Usage:
    kcheckout <branch>

Can be run from inside either repo or from their parent directory.
`

func main() {
	if len(os.Args) < 2 {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(1)
	}
	branch := os.Args[1]

	kestraDir, kestraEEDir, err := findRepos()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	exitCode := 0
	for _, r := range []struct{ dir, name string }{{kestraDir, "kestra"}, {kestraEEDir, "kestra-ee"}} {
		if _, err := os.Stat(r.dir); os.IsNotExist(err) {
			fmt.Fprintf(os.Stderr, "[%s] directory not found: %s\n", r.name, r.dir)
			exitCode = 1
			continue
		}
		fmt.Printf("[%s] checking out %s...\n", r.name, branch)
		cmd := exec.Command("git", "-C", r.dir, "checkout", branch)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			exitCode = 1
		}
	}
	os.Exit(exitCode)
}

func findRepos() (kestraDir, kestraEEDir string, err error) {
	currentDir, err := os.Getwd()
	if err != nil {
		return "", "", err
	}

	out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	if err != nil {
		// Not in a git repo — treat current dir as parent containing both repos
		return filepath.Join(currentDir, "kestra"), filepath.Join(currentDir, "kestra-ee"), nil
	}

	gitRoot := strings.TrimSpace(string(out))
	repoName := filepath.Base(gitRoot)
	parentDir := filepath.Dir(gitRoot)

	switch repoName {
	case "kestra":
		return gitRoot, filepath.Join(parentDir, "kestra-ee"), nil
	case "kestra-ee":
		return filepath.Join(parentDir, "kestra"), gitRoot, nil
	default:
		// Inside some other git repo — treat current dir as parent
		return filepath.Join(currentDir, "kestra"), filepath.Join(currentDir, "kestra-ee"), nil
	}
}
