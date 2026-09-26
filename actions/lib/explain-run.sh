#!/bin/sh
# Prints a Markdown explanation of how a Claude run ended: the model's
# final message and every permission denial, with the exact tool input
# that was denied. Meant for $GITHUB_STEP_SUMMARY.
#
# Usage: explain-run.sh <execution_file>
#
# <execution_file> is the claude-code-action `execution_file` output (see
# format-run-report.sh). Both fields come from its last `{"type":
# "result"}` entry. In agent mode (a `prompt` input) nothing posts the
# final message anywhere, so a run that gives up after a denial reports
# `success` and says why only inside this file — see gh-repo-init#42.
#
# Fixtures live in actions/lib/explain-run.test.sh.
set -eu

execution_file=${1:-}

if [ -z "$execution_file" ] || [ ! -s "$execution_file" ]; then
  echo "No execution file: the Claude step crashed or never ran."
  exit 0
fi

jq -r '
  [.[] | select(.type == "result")] | last
  | if . == null then
      "No result entry: the Claude step crashed before finishing."
    else
      (.permission_denials // []) as $denials
      | "### Permission denials: \($denials | length)\n"
        + ($denials | map(
            "- `\(.tool_name)`: `\(.tool_input | tojson)`"
          ) | join("\n"))
        + (if ($denials | length) > 0 then "\n" else "" end)
        + "\n### Final message\n\n"
        + (.result // "_(none)_")
    end
' "$execution_file" 2>/dev/null || echo "Execution file isn't valid JSON."
