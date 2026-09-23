#!/bin/sh
# Posts the one-line Run Report comment (see ADR 0007 in
# oak-wildwood/cooperage) on the triggering issue or PR, and — when the
# target is an issue — on the PR that references it too, if one exists.
# The PR is found by searching open PRs' bodies for the issue number (see
# find-pr-for-issue.sh) rather than relying on claude-code-action's
# `branch_name` output, which comes back empty in agent (schedule/dispatch)
# mode where Claude creates its own branch with git — see gh-repo-init#29.
# Shared by actions/nightly-run and actions/claude so the posting logic has
# one copy.
#
# Reads EXECUTION_FILE, MODEL, CONCLUSION, TARGET_KIND ("issue" or "pr" —
# `gh issue comment` errors on a PR number), TARGET_NUMBER,
# GITHUB_REPOSITORY and GH_TOKEN from the environment.
set -eu

dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

body=$("$dir/format-run-report.sh" "${EXECUTION_FILE:-}" "$MODEL" "${CONCLUSION:-}")

if [ "$TARGET_KIND" = "pr" ]; then
  gh pr comment "$TARGET_NUMBER" --repo "$GITHUB_REPOSITORY" --body "$body"
else
  gh issue comment "$TARGET_NUMBER" --repo "$GITHUB_REPOSITORY" --body "$body"

  pr_number=$(gh pr list --repo "$GITHUB_REPOSITORY" --state open \
    --json number,body,createdAt | "$dir/find-pr-for-issue.sh" "$TARGET_NUMBER")
  if [ -n "$pr_number" ]; then
    gh pr comment "$pr_number" --repo "$GITHUB_REPOSITORY" --body "$body"
  fi
fi
