#!/bin/sh
# Prints the final assistant message of a Claude run — the `result` field
# of the last `{"type": "result"}` entry in claude-code-action's
# `execution_file` output — so a later workflow step can act on it
# deterministically instead of trusting the model to do the side effect
# itself (see actions/code-review, gh-repo-init#42).
#
# Usage: extract-final-message.sh <execution_file>
#
# Exits non-zero with a reason on stderr, printing nothing on stdout, when
# there is no usable message: file empty or missing, no result entry, a
# result that isn't `subtype: success` (max turns, an error), or a blank
# `result`. A run that ends without saying anything is a failure, not an
# empty review.
set -eu

execution_file=${1:-}

if [ -z "$execution_file" ] || [ ! -s "$execution_file" ]; then
  echo "no execution file — the Claude step never wrote one" >&2
  exit 1
fi

last=$(jq -c '[.[] | select(.type == "result")] | last' "$execution_file" 2>/dev/null) || {
  echo "execution file isn't valid JSON" >&2
  exit 1
}

if [ -z "$last" ] || [ "$last" = "null" ]; then
  echo "execution file has no result entry — the run ended before finishing" >&2
  exit 1
fi

subtype=$(printf '%s' "$last" | jq -r '.subtype // "missing"')
if [ "$subtype" != "success" ] || [ "$(printf '%s' "$last" | jq -r '.is_error // false')" = "true" ]; then
  echo "run ended with result subtype '$subtype', not a finished answer" >&2
  exit 1
fi

message=$(printf '%s' "$last" | jq -r '.result // ""')
if [ -z "$(printf '%s' "$message" | tr -d '[:space:]')" ]; then
  echo "run finished but its final message is empty" >&2
  exit 1
fi

printf '%s\n' "$message"
