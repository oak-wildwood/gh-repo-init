#!/bin/sh
# Fixtures for actions/lib/default-branch-pushes.sh. Run with: sh actions/lib/default-branch-pushes.test.sh
#
# Every git command names its throwaway repository with -C and never relies on the current
# directory, and push refuses any remote outside the temp dir, so nothing here can touch the
# checkout the test is run from or its remote.
set -eu

dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
script="$dir/default-branch-pushes.sh"

BOT=bot@example.com
GITHUB=noreply@github.com

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
remote="$tmp/remote.git"
work="$tmp/work"
other="$tmp/other"

fail=0

check() {
  name=$1
  expected=$2
  actual=$3
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    fail=1
  else
    echo "ok: $name"
  fi
}

# commit <repo> <email> <message>: an empty commit by that committer. Sets $sha.
commit() {
  GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL="$2" GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL="$2" \
    git -C "$1" commit -q --allow-empty -m "$3"
  sha=$(git -C "$1" rev-parse HEAD)
}

# push <repo> <args...>: refuses unless the repo's origin is the throwaway remote.
push() {
  repo=$1
  shift
  [ "$(git -C "$repo" remote get-url origin)" = "$remote" ] || { echo "refusing to push outside $tmp" >&2; exit 1; }
  git -C "$repo" push -q --no-verify origin "$@" 2>/dev/null
}

# A fresh bare remote with one commit on main, cloned into $work and $other. Sets $before.
fresh() {
  rm -rf "$remote" "$work" "$other"
  git init -q --bare -b main "$remote"
  git clone -q "$remote" "$work" 2>/dev/null
  commit "$work" "$GITHUB" init
  push "$work" main
  git clone -q "$remote" "$other" 2>/dev/null
  before=$sha
}

# A squash merge landing on main from another clone, committed by GitHub.
merge_elsewhere() {
  git -C "$other" pull -q origin main
  commit "$other" "$GITHUB" "squash merge"
  push "$other" main
}

# The script's output for <email>, run inside the throwaway clone.
pushes() {
  git -C "$work" fetch -q origin main
  (cd "$work" && sh "$script" "$before" "$(git -C "$work" rev-parse FETCH_HEAD)" "$1")
}

fresh
check "clean run" "" "$(pushes "$BOT")"

fresh
merge_elsewhere
check "a concurrent squash merge" "" "$(pushes "$BOT")"

fresh
git -C "$work" checkout -q -b claude/issue-1
commit "$work" "$BOT" "work"
merge_elsewhere
git -C "$work" pull -q --no-rebase --no-edit origin main
commit "$work" "$BOT" "more work"
push "$work" claude/issue-1
check "upstream commits pulled into the run's own branch" "" "$(pushes "$BOT")"

fresh
commit "$work" "$BOT" "pushed to main"
push "$work" HEAD:main
check "a push from a branch" "$sha" "$(pushes "$BOT")"

fresh
git -C "$work" checkout -q --detach
commit "$work" "$BOT" "pushed from a detached HEAD"
push "$work" HEAD:main
check "a push from a detached HEAD" "$sha" "$(pushes "$BOT")"

fresh
merge_elsewhere
git -C "$work" pull -q origin main
commit "$work" "$BOT" "pushed after a merge"
push "$work" HEAD:main
check "a GitHub merge, then a push" "$sha" "$(pushes "$BOT")"

fresh
# A PR whose branch holds the bot's commits (an earlier Nightly's), merged with a merge commit.
git -C "$other" checkout -q -b claude/issue-2
commit "$other" "$BOT" "earlier nightly work"
git -C "$other" checkout -q main
GIT_COMMITTER_EMAIL="$GITHUB" GIT_COMMITTER_NAME=t GIT_AUTHOR_EMAIL="$GITHUB" GIT_AUTHOR_NAME=t \
  git -C "$other" merge -q --no-ff --no-edit claude/issue-2
push "$other" main
check "a PR merged with a merge commit during the run" "" "$(pushes "$BOT")"

fresh
code=0
pushes "" 2>/dev/null || code=$?
check "no committer email" "2" "$code"

fresh
code=0
(cd "$work" && sh "$script" 0000000000000000000000000000000000000000 "$before" "$BOT") 2>/dev/null || code=$?
check "an unknown commit is an error, not an empty answer" "3" "$code"

exit "$fail"
