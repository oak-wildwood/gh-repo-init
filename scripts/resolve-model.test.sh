#!/bin/sh
# Fixtures for scripts/resolve-model.sh. Run with: sh scripts/resolve-model.test.sh
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
script="$dir/resolve-model.sh"

fail=0

check() {
  name=$1
  tier=$2
  expected=$3

  actual=$("$script" "$tier")

  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    fail=1
  else
    echo "ok: $name"
  fi
}

check "haiku" "haiku" "claude-haiku-4-5-20251001"
check "opus" "opus" "claude-opus-5-5"
check "sonnet" "sonnet" "claude-sonnet-5"
check "fable" "fable" "fable"
check "unknown tier falls back to sonnet" "garbage" "claude-sonnet-5"
check "empty tier falls back to sonnet" "" "claude-sonnet-5"
check "case insensitive" "HAIKU" "claude-haiku-4-5-20251001"

if [ "$fail" -ne 0 ]; then
  echo "one or more fixtures failed"
  exit 1
fi

echo "all fixtures passed"
