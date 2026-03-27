package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
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

	type result struct {
		name   string
		output string
		failed bool
	}

	repos := []struct{ dir, name string }{{kestraDir, "kestra"}, {kestraEEDir, "kestra-ee"}}
	results := make([]result, len(repos))

	var wg sync.WaitGroup
	for i, r := range repos {
		wg.Add(1)
		go func(i int, dir, name string) {
			defer wg.Done()
			var buf bytes.Buffer
			failed := false

			if _, err := os.Stat(dir); os.IsNotExist(err) {
				fmt.Fprintf(&buf, "[%s] directory not found: %s\n", name, dir)
				results[i] = result{name, buf.String(), true}
				return
			}

			fmt.Fprintf(&buf, "[%s] checking out %s...\n", name, branch)
			checkout := exec.Command("git", "-C", dir, "checkout", branch)
			checkout.Stdout = &buf
			checkout.Stderr = &buf
			if err := checkout.Run(); err != nil {
				results[i] = result{name, buf.String(), true}
				return
			}

			fmt.Fprintf(&buf, "[%s] pulling...\n", name)
			pull := exec.Command("git", "-C", dir, "pull")
			pull.Stdout = &buf
			pull.Stderr = &buf
			if err := pull.Run(); err != nil {
				failed = true
			}

			results[i] = result{name, buf.String(), failed}
		}(i, r.dir, r.name)
	}
	wg.Wait()

	exitCode := 0
	for _, r := range results {
		fmt.Print(r.output)
		if r.failed {
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
