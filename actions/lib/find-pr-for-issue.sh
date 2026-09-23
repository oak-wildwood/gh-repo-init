#!/bin/sh
# Given the JSON array from `gh pr list --json number,body,createdAt` on
# stdin, prints the number of the oldest open PR whose body references the
# given issue (a bare "#<issue>", "Closes #<issue>", etc. all count) — or
# nothing if none matches.
#
# Needed because claude-code-action's `branch_name` output comes back
# empty in agent (schedule/dispatch) mode, where Claude creates its own
# branch with git, so the PR can't be found by branch name. Used both to
# find the PR to post the Run Report on, and to find a freshly opened PR
# whose body doesn't have the Closes directive yet, so it can be added.
#
# Usage: find-pr-for-issue.sh <issue_number> < prs.json
set -eu

issue_number=$1

jq -r --arg n "$issue_number" '
  [.[] | select(.body // "" | test("(^|[^0-9])#" + $n + "([^0-9]|$)"))]
  | sort_by(.createdAt) | .[0].number // empty
'
