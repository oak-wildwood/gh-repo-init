#!/bin/sh
# Prints, one per line, the commits that reached the default branch during a
# Nightly run and were committed by the run's own git identity. Empty output
# means the run delivered nothing straight to the default branch.
#
#   default-branch-pushes.sh <sha before the run> <sha after the run> <committer email>
#
# It looks at what landed on the default branch, not at the run's local
# branches. So a pull request merged during the run (committed by GitHub) and
# upstream commits the agent pulled into its own branch are never counted,
# while a push from any branch or a detached HEAD is.
#
# Used by actions/nightly-run. Fixtures live in
# actions/lib/default-branch-pushes.test.sh.
set -eu

before=$1
after=$2
email=$3

if [ -z "$email" ]; then
  echo "default-branch-pushes.sh: no committer email to look for" >&2
  exit 2
fi

git log --format='%H %ce' "$after" --not "$before" \
  | while read -r sha committer; do
      if [ "$committer" = "$email" ]; then printf '%s\n' "$sha"; fi
    done
