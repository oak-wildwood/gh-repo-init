#!/bin/sh
# Fixtures for actions/lib/extract-final-message.sh. Run with: sh actions/lib/extract-final-message.test.sh
set -eu

dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
script="$dir/extract-final-message.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail=0

# check <name> <execution_file> <expected stdout> <expected status: ok|fail>
check() {
  name=$1
  execution_file=$2
  expected=$3
  expected_status=$4

  status=ok
  actual=$("$script" "$execution_file" 2>/dev/null) || status=fail

  if [ "$actual" != "$expected" ] || [ "$status" != "$expected_status" ]; then
    echo "FAIL: $name"
    echo "  expected ($expected_status): $expected"
    echo "  actual   ($status): $actual"
    fail=1
  else
    echo "ok: $name"
  fi
}

success_file="$tmp/success.json"
cat >"$success_file" <<'EOF'
[
  {"type": "system", "subtype": "init"},
  {"type": "assistant", "message": {"content": [{"type": "text", "text": "working..."}]}},
  {"type": "result", "subtype": "success", "is_error": false, "result": "## Standards\n\nNo findings."}
]
EOF

check "success run prints the final message" \
  "$success_file" "$(printf '## Standards\n\nNo findings.')" ok

two_results_file="$tmp/two-results.json"
cat >"$two_results_file" <<'EOF'
[
  {"type": "result", "subtype": "success", "result": "stale"},
  {"type": "result", "subtype": "success", "result": "latest"}
]
EOF

check "uses the last result entry" "$two_results_file" "latest" ok

max_turns_file="$tmp/max-turns.json"
cat >"$max_turns_file" <<'EOF'
[
  {"type": "result", "subtype": "error_max_turns", "is_error": true}
]
EOF

check "max turns is a failure" "$max_turns_file" "" fail

is_error_file="$tmp/is-error.json"
cat >"$is_error_file" <<'EOF'
[
  {"type": "result", "subtype": "success", "is_error": true, "result": "API Error: 500"}
]
EOF

check "is_error is a failure even with subtype success" "$is_error_file" "" fail

blank_file="$tmp/blank.json"
cat >"$blank_file" <<'EOF'
[
  {"type": "result", "subtype": "success", "result": "  \n "}
]
EOF

check "blank final message is a failure" "$blank_file" "" fail

no_result_file="$tmp/no-result.json"
cat >"$no_result_file" <<'EOF'
[
  {"type": "system", "subtype": "init"}
]
EOF

check "no result entry is a failure" "$no_result_file" "" fail

check "missing file is a failure" "$tmp/does-not-exist.json" "" fail
check "empty path is a failure" "" "" fail

invalid_file="$tmp/invalid.json"
printf 'not json' >"$invalid_file"
check "invalid JSON is a failure" "$invalid_file" "" fail

exit "$fail"
