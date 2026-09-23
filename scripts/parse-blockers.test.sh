#!/bin/sh
# Fixtures for scripts/parse-blockers.sh. Run with: sh scripts/parse-blockers.test.sh
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
script="$dir/parse-blockers.sh"

fail=0

check() {
  name=$1
  repo=$2
  body=$3
  expected=$4

  actual=$(printf '%s' "$body" | "$script" "$repo")

  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $name"
    echo "  expected: $(printf '%s' "$expected" | tr '\n' '|')"
    echo "  actual:   $(printf '%s' "$actual" | tr '\n' '|')"
    fail=1
  else
    echo "ok: $name"
  fi
}

check "no blockers" \
  "oak-wildwood/gh-repo-init" \
  "Just a plain issue body with no blockers." \
  ""

check "same-repo blocker" \
  "oak-wildwood/gh-repo-init" \
  "Blocked by #14" \
  "oak-wildwood/gh-repo-init#14"

check "cross-repo blocker" \
  "oak-wildwood/gh-repo-init" \
  "Blocked by oak-wildwood/cooperage#5" \
  "oak-wildwood/cooperage#5"

check "multiple blocker lines" \
  "oak-wildwood/gh-repo-init" \
  "Some context.

Blocked by #12
Blocked by #13

More text." \
  "oak-wildwood/gh-repo-init#12
oak-wildwood/gh-repo-init#13"

check "multiple refs on one line" \
  "oak-wildwood/gh-repo-init" \
  "Blocked by #12, #13 and oak-wildwood/cooperage#5" \
  "oak-wildwood/gh-repo-init#12
oak-wildwood/gh-repo-init#13
oak-wildwood/cooperage#5"

check "bulleted blocker" \
  "oak-wildwood/gh-repo-init" \
  "- Blocked by #7" \
  "oak-wildwood/gh-repo-init#7"

check "case insensitive" \
  "oak-wildwood/gh-repo-init" \
  "blocked by #9" \
  "oak-wildwood/gh-repo-init#9"

check "mention of blocked elsewhere is ignored" \
  "oak-wildwood/gh-repo-init" \
  "This issue is not blocked by anything, see #99 for context." \
  ""

if [ "$fail" -ne 0 ]; then
  echo "one or more fixtures failed"
  exit 1
fi

echo "all fixtures passed"
