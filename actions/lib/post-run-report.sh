#!/bin/sh
# Posts the one-line Run Report comment (see ADR 0007 in
# oak-wildwood/cooperage) on the triggering issue or PR, and on the PR opened
# from BRANCH_NAME too if that's a different thread. Shared by
# actions/nightly-run and actions/claude so the posting logic has one copy.
#
# Reads EXECUTION_FILE, MODEL, CONCLUSION, TARGET_KIND ("issue" or "pr" —
# `gh issue comment` errors on a PR number), TARGET_NUMBER, BRANCH_NAME
# (optional), GITHUB_REPOSITORY and GH_TOKEN from the environment.
set -eu

dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

body=$("$dir/format-run-report.sh" "${EXECUTION_FILE:-}" "$MODEL" "${CONCLUSION:-}")

if [ "$TARGET_KIND" = "pr" ]; then
  gh pr comment "$TARGET_NUMBER" --repo "$GITHUB_REPOSITORY" --body "$body"
else
  gh issue comment "$TARGET_NUMBER" --repo "$GITHUB_REPOSITORY" --body "$body"
fi

if [ -n "${BRANCH_NAME:-}" ]; then
  pr_number=$(gh pr list --repo "$GITHUB_REPOSITORY" --head "$BRANCH_NAME" \
    --json number --jq '.[0].number // empty')
  if [ -n "$pr_number" ] && { [ "$TARGET_KIND" != "pr" ] || [ "$pr_number" != "$TARGET_NUMBER" ]; }; then
    gh pr comment "$pr_number" --repo "$GITHUB_REPOSITORY" --body "$body"
  fi
fi
