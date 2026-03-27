package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
)

type PR struct {
	Number      int    `json:"number"`
	Title       string `json:"title"`
	Body        string `json:"body"`
	HeadRefName string `json:"headRefName"`
	Commits     []struct {
		OID string `json:"oid"`
	} `json:"commits"`
}

func (pr PR) CommitOIDs() []string {
	oids := make([]string, len(pr.Commits))
	for i, c := range pr.Commits {
		oids[i] = c.OID
	}
	return oids
}

func getPR(number string) (PR, error) {
	cmd := exec.Command("gh", "pr", "view", number, "--json", "number,title,body,headRefName,commits")
	out, err := cmd.Output()
	if err != nil {
		return PR{}, fmt.Errorf("gh pr view %s failed: %s", number, strings.TrimSpace(string(out)))
	}
	var pr PR
	if err := json.Unmarshal(out, &pr); err != nil {
		return PR{}, fmt.Errorf("failed to parse PR JSON: %w", err)
	}
	return pr, nil
}

func createPR(base, title, body string) (string, error) {
	cmd := exec.Command("gh", "pr", "create", "--base", base, "--title", title, "--body", body)
	out, err := cmd.Output()
	if err != nil {
		combined, _ := exec.Command("gh", "pr", "create", "--base", base, "--title", title, "--body", body).CombinedOutput()
		return "", fmt.Errorf("gh pr create failed: %s", strings.TrimSpace(string(combined)))
	}
	return strings.TrimSpace(string(out)), nil
}
