#!/bin/sh
# Maps a Model Tier keyword to the model ID passed to claude-code-action's
# --model flag. The one place this mapping lives — bump a model ID here and
# it reaches actions/nightly-pick (tier read from the issue's Model Tier label) and
# actions/claude (tier read from a keyword in the triggering comment/issue text)
# alike, instead of two inline tables drifting apart.
#
# Usage: resolve-model.sh <tier>
#
# <tier> is haiku, opus, sonnet or fable, case-insensitive; anything else
# (including empty) falls back to sonnet. fable isn't a real model ID — it's
# a sentinel the caller checks for. In the Nightly that means handing the
# issue back for a local session instead of running Claude in Actions;
# the @claude action doesn't offer the fable keyword at all, since a comment
# trigger is already a human asking for the run live.
#
# Used by actions/nightly-pick and actions/claude.
set -eu

tier=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')

case "$tier" in
  haiku) echo "claude-haiku-4-5-20251001" ;;
  opus) echo "claude-opus-5-5" ;;
  fable) echo "fable" ;;
  *) echo "claude-sonnet-5" ;;
esac
