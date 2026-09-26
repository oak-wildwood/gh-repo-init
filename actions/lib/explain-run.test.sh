#!/bin/sh
# Fixtures for actions/lib/explain-run.sh. Run with: sh actions/lib/explain-run.test.sh
set -eu

dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
script="$dir/explain-run.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail=0

check() {
  name=$1
  execution_file=$2
  expected=$3

  actual=$(sh "$script" "$execution_file")

  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    fail=1
  else
    echo "ok: $name"
  fi
}

denied_file="$tmp/denied.json"
cat >"$denied_file" <<'EOF'
[
  {"type": "system", "subtype": "init", "model": "claude-opus-5-5"},
  {
    "type": "result",
    "subtype": "success",
    "is_error": false,
    "result": "I couldn't load the skill, so I stopped.",
    "permission_denials": [
      {"tool_name": "Skill", "tool_use_id": "toolu_1", "tool_input": {"skill": "mattpocock-skills:code-review"}}
    ]
  }
]
EOF

check "success run that gave up after a denial" "$denied_file" "### Permission denials: 1
- \`Skill\`: \`{\"skill\":\"mattpocock-skills:code-review\"}\`

### Final message

I couldn't load the skill, so I stopped."

clean_file="$tmp/clean.json"
cat >"$clean_file" <<'EOF'
[
  {"type": "result", "result": "Posted the review.", "permission_denials": []}
]
EOF

check "no denials" "$clean_file" "### Permission denials: 0

### Final message

Posted the review."

no_text_file="$tmp/no-text.json"
cat >"$no_text_file" <<'EOF'
[
  {"type": "result", "subtype": "error_during_execution"}
]
EOF

check "result entry without text or denials" "$no_text_file" "### Permission denials: 0

### Final message

_(none)_"

check "empty path" "" "No execution file: the Claude step crashed or never ran."

no_result_file="$tmp/no-result.json"
cat >"$no_result_file" <<'EOF'
[
  {"type": "system", "subtype": "init", "model": "claude-sonnet-5"}
]
EOF

check "no result entry" "$no_result_file" \
  "No result entry: the Claude step crashed before finishing."

bad_file="$tmp/bad.json"
echo "not json" >"$bad_file"

check "invalid JSON" "$bad_file" "Execution file isn't valid JSON."

if [ "$fail" -ne 0 ]; then
  echo "one or more fixtures failed"
  exit 1
fi

echo "all fixtures passed"
