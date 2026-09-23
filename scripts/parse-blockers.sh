#!/bin/sh
# Extracts "Blocked by #N" / "Blocked by owner/repo#N" references from an
# issue body (read on stdin) and prints each as a qualified owner/repo#N,
# one per line. A bare "#N" is qualified against the repo passed as $1.
#
# Only lines that start with "Blocked by" (optionally after leading
# whitespace or a single markdown bullet) count — a stray mention of the
# phrase elsewhere in the body is ignored. Several refs may appear on one
# line, comma- or "and"-separated.
#
# Used by .github/workflows/nightly.yml's pick step. Fixtures for this
# parsing live in scripts/parse-blockers.test.sh.
set -eu

default_repo=$1

grep -iE '^[[:space:]]*[-*]?[[:space:]]*blocked by\b' \
  | grep -oE '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+|#[0-9]+' \
  | while IFS= read -r ref; do
      case "$ref" in
        "#"*) printf '%s%s\n' "$default_repo" "$ref" ;;
        *) printf '%s\n' "$ref" ;;
      esac
    done
