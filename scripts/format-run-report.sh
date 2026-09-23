#!/bin/sh
# Builds the one-line Run Report comment body for a Claude Nightly run.
#
# Usage: format-run-report.sh <execution_file> <model> <conclusion>
#
# <execution_file> is the claude-code-action `execution_file` output: a JSON
# array of the raw Claude Agent SDK messages for the run. Token counts and
# duration come from the last `{"type": "result"}` entry in that array,
# which the SDK always writes last when it gets to write anything at all.
#
# If the Claude step crashed before ever producing that file (path empty,
# file missing, or no result entry in it — this is what "the Claude step
# crashed before writing the file" looks like from here), the report is
# `Run Report: unavailable · failure` regardless of the <conclusion>
# argument, per ADR 0007 in oak-wildwood/cooperage: a run report with no
# real numbers behind it should say so, not print zeroes.
#
# Used by .github/workflows/nightly.yml's claude job. Fixtures for this
# formatting live in scripts/format-run-report.test.sh.
set -eu

execution_file=${1:-}
model=${2:-}
conclusion=${3:-}

unavailable() {
  echo "Run Report: unavailable · failure"
}

if [ -z "$execution_file" ] || [ ! -s "$execution_file" ]; then
  unavailable
  exit 0
fi

summary=$(jq -r '
  [.[] | select(.type == "result")] | last
  | if . == null then
      empty
    else
      ((.usage.input_tokens // 0) + (.usage.output_tokens // 0)) as $tokens
      | (((.duration_ms // 0) / 1000) | floor) as $total_seconds
      | ($total_seconds / 60 | floor) as $minutes
      | ($total_seconds % 60) as $seconds
      | (if $minutes > 0 then "\($minutes)m \($seconds)s" else "\($seconds)s" end) as $duration
      | "\($tokens) tokens · \($duration)"
    end
' "$execution_file" 2>/dev/null || true)

if [ -z "$summary" ]; then
  unavailable
  exit 0
fi

echo "Run Report: $model · $summary · $conclusion"
