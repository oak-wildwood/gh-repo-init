#!/bin/sh
# Fixtures for scripts/format-run-report.sh. Run with: sh scripts/format-run-report.test.sh
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
script="$dir/format-run-report.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail=0

check() {
  name=$1
  execution_file=$2
  model=$3
  conclusion=$4
  expected=$5

  actual=$("$script" "$execution_file" "$model" "$conclusion")

  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    fail=1
  else
    echo "ok: $name"
  fi
}

success_file="$tmp/success.json"
cat >"$success_file" <<'EOF'
[
  {"type": "system", "subtype": "init", "model": "claude-sonnet-5"},
  {"type": "assistant", "message": {"content": [{"type": "text", "text": "working..."}]}},
  {
    "type": "result",
    "subtype": "success",
    "is_error": false,
    "duration_ms": 192000,
    "num_turns": 8,
    "result": "done",
    "usage": {"input_tokens": 12000, "output_tokens": 3400},
    "modelUsage": {}
  }
]
EOF

check "success run" \
  "$success_file" "claude-sonnet-5" "success" \
  "Run Report: claude-sonnet-5 · 15400 tokens · 3m 12s · success"

short_file="$tmp/short.json"
cat >"$short_file" <<'EOF'
[
  {
    "type": "result",
    "duration_ms": 4500,
    "usage": {"input_tokens": 100, "output_tokens": 50}
  }
]
EOF

check "run under a minute" \
  "$short_file" "claude-haiku-4-5-20251001" "success" \
  "Run Report: claude-haiku-4-5-20251001 · 150 tokens · 4s · success"

failure_with_result="$tmp/failure.json"
cat >"$failure_with_result" <<'EOF'
[
  {
    "type": "result",
    "subtype": "error_during_execution",
    "is_error": true,
    "duration_ms": 60000,
    "usage": {"input_tokens": 500, "output_tokens": 10}
  }
]
EOF

check "failed run that still wrote a result" \
  "$failure_with_result" "claude-opus-5-5" "failure" \
  "Run Report: claude-opus-5-5 · 510 tokens · 1m 0s · failure"

check "empty path" \
  "" "claude-sonnet-5" "failure" \
  "Run Report: unavailable · failure"

check "missing file" \
  "$tmp/does-not-exist.json" "claude-sonnet-5" "failure" \
  "Run Report: unavailable · failure"

empty_file="$tmp/empty.json"
: >"$empty_file"

check "empty file" \
  "$empty_file" "claude-sonnet-5" "failure" \
  "Run Report: unavailable · failure"

no_result_file="$tmp/no-result.json"
cat >"$no_result_file" <<'EOF'
[
  {"type": "system", "subtype": "init", "model": "claude-sonnet-5"},
  {"type": "assistant", "message": {"content": [{"type": "text", "text": "crashed mid-turn"}]}}
]
EOF

check "no result entry (crash before completion)" \
  "$no_result_file" "claude-sonnet-5" "failure" \
  "Run Report: unavailable · failure"

if [ "$fail" -ne 0 ]; then
  echo "one or more fixtures failed"
  exit 1
fi

echo "all fixtures passed"
