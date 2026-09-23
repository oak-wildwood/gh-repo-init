#!/bin/sh
# Fixtures for actions/lib/find-pr-for-issue.sh. Run with: sh actions/lib/find-pr-for-issue.test.sh
set -eu

dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
script="$dir/find-pr-for-issue.sh"

fail=0

check() {
  name=$1
  issue_number=$2
  json=$3
  expected=$4

  actual=$(printf '%s' "$json" | "$script" "$issue_number")

  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    fail=1
  else
    echo "ok: $name"
  fi
}

check "no PRs" \
  "29" \
  '[]' \
  ""

check "no matching PR" \
  "29" \
  '[{"number": 5, "body": "unrelated change", "createdAt": "2026-01-01T00:00:00Z"}]' \
  ""

check "Closes directive matches" \
  "29" \
  '[{"number": 30, "body": "Closes #29\n\nSome description.", "createdAt": "2026-01-01T00:00:00Z"}]' \
  "30"

check "bare reference matches" \
  "29" \
  '[{"number": 30, "body": "Fixes the bug from #29.", "createdAt": "2026-01-01T00:00:00Z"}]' \
  "30"

check "does not match a longer number" \
  "2" \
  '[{"number": 30, "body": "Closes #29", "createdAt": "2026-01-01T00:00:00Z"}]' \
  ""

check "does not match a prefix number" \
  "29" \
  '[{"number": 30, "body": "Closes #299", "createdAt": "2026-01-01T00:00:00Z"}]' \
  ""

check "oldest of multiple matches wins" \
  "29" \
  '[
    {"number": 31, "body": "Closes #29", "createdAt": "2026-01-02T00:00:00Z"},
    {"number": 30, "body": "Closes #29", "createdAt": "2026-01-01T00:00:00Z"}
  ]' \
  "30"

check "missing body field" \
  "29" \
  '[{"number": 30, "createdAt": "2026-01-01T00:00:00Z"}]' \
  ""

if [ "$fail" -ne 0 ]; then
  echo "one or more fixtures failed"
  exit 1
fi

echo "all fixtures passed"
