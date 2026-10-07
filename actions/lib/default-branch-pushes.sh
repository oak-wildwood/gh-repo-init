#!/bin/sh
# Prints, one per line, the commits that reached the default branch during a
# Nightly run and were committed by the run's own git identity. Empty output
# means the run delivered nothing straight to the default branch.
#
#   default-branch-pushes.sh <sha before the run> <sha after the run> <committer email>
#
# It looks at what landed on the default branch itself (its first-parent line),
# not at the run's local branches. So a pull request merged during the run is
# never counted, whether squashed (committed by GitHub) or merged with a merge
# commit (its branch's commits are off that line), and neither are upstream
# commits the agent pulled into its own branch. A push from any branch or a
# detached HEAD is.
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

# An unknown commit would make git log print nothing, which reads as "no pushes". Say so instead.
for rev in "$before" "$after"; do
  git cat-file -e "$rev^{commit}" 2>/dev/null || { echo "default-branch-pushes.sh: $rev is not a commit here" >&2; exit 3; }
done

git log --first-parent --format='%H %ce' "$after" --not "$before" \
  | while read -r sha committer; do
      if [ "$committer" = "$email" ]; then printf '%s\n' "$sha"; fi
    done
