# gh-repo-init

A `gh` CLI extension that walks a GitHub repository up to a consistent baseline — merge strategy,
commit message format, branch cleanup, and starter agent instruction files.

GitHub has no account-level, organization-level, or template-level defaults for any of this. Repos
created from a template don't inherit it either. So every new repository starts on stock settings,
and you re-pick the same handful of options by hand, or more likely forget to.

This asks once and applies the answers.

## Install

```bash
gh extension install oak-wildwood/gh-repo-init
```

Requires [`gh`](https://cli.github.com) and [`jq`](https://jqlang.github.io/jq/).

## Use

```bash
cd your-repo
gh repo-init
```

It reads the repo from the current directory's remote, shows you what's currently set, asks what
you want, and applies it.

```bash
gh repo-init --dry-run           # show what would change, touch nothing
gh repo-init --yes               # take the recommended answer to everything
gh repo-init --repo owner/name   # target a repo you're not standing in
gh repo-init --yes --with-code-review   # --yes, but also add the code-review action
```

`--with-code-review` exists because the code-review action's recommended answer is *no* (see
below) — `--yes` alone can never add it, so this is the only way to opt in without an interactive
terminal.

Re-running is safe. Settings converge, and existing files are never overwritten.

## What it asks about

**Merge strategy.** Squash-only, squash-plus-rebase, everything, or leave it alone. The default
keeps rebase available as an escape hatch for the occasional branch whose individual commits are
worth preserving.

**Squash commit message.** Pull request title alone, or title plus description. Title-only pairs
well with conventional commits: the PR title becomes the commit subject, so it's the permanent
record rather than a label on a discussion.

**Branch cleanup.** Whether merged branches delete themselves.

**Branch protection**, as a ruleset. Off by default, because a misconfigured rule can lock a solo
maintainer out of their own default branch. When enabled it requires a pull request but *no*
reviewers — you can't approve your own PR, so requiring one would make the branch unmergeable — and
blocks deletion and force-pushes. It asks for the name of a status check to require, since a fresh
repo has none and requiring a context that never reports leaves the branch stuck.

It also asks whether repository admins may bypass it. Worth answering deliberately: with bypass the
rule is a guardrail you can step over, and `git push` to a protected branch will succeed while
printing what looks like a rejection. Note that a ruleset-protected branch returns 404 from the
classic `/branches/*/protection` endpoint, so checking protection the old way reports "not
protected".

**Agent instruction files.** `AGENTS.md`, a `CLAUDE.md` that imports it, the Claude Code GitHub
workflow, and `.gitignore` entries for agent-local files. Each is asked about separately (defaulting
to yes for the two Claude workflows, since every recent repo has wanted them) and skipped if already
present. Like `claude-nightly.yml`, `claude.yml` is a thin caller into this repo's reusable
`.github/workflows/claude.yml`, pinned to a `@v1`-style tag so a fix there doesn't change your repo's
behaviour until you move the pin.

**A nightly cron for unattended work.** Only offered once the Claude Code GitHub workflow is
present, since it reuses that same GitHub App and `CLAUDE_CODE_OAUTH_TOKEN`. Asks for the cron
schedule (default `0 9 * * *`, ~2am Pacific — GitHub cron runs in UTC). Each night it claims the
oldest open issue labeled `claude-task` with no open blocker, runs Claude against it at the model
tier its `model:haiku` / `model:sonnet` / `model:opus` label picks (`model:fable` issues are handed
back for a local session instead), and always opens a pull request for review rather than merging
anything itself. `claude-nightly.yml` is a thin caller into this repo's reusable
`.github/workflows/nightly.yml`, pinned the same way as `claude.yml`. Its default `--allowedTools`
ships with `npm` as a placeholder — override the `allowed_tools` input for whatever the project
actually uses to install and test.

Adding the nightly cron creates the standard label set if any are missing: `claude-task`,
`claude-in-progress`, `human-task`, and the four `model:*` tier labels.

**A code-review action, on request.** Off by default — only offered once the Claude Code GitHub
workflow is present. Reviews a pull request's diff since its base branch, in the style of
[Matt Pocock's `code-review` skill](https://github.com/mattpocock/skills): a Standards axis (does
the diff follow this repo's documented conventions?) and a Spec axis (does it match what the
originating issue asked for?). The review instructions are inlined in the action rather than loaded
from the skill at run time. Claude's final message is the review, and a plain workflow step posts it
as a single PR comment, so a run that produces no review fails visibly instead of posting nothing.
Defaults to the Opus model tier, since review is exactly the judgment-heavy, subtle-bug-catching work that tier is for, and
usage stays bounded because nothing runs it automatically — trigger it with
`gh workflow run code-review.yml -f pr_number=N`, or by commenting `@review` on the PR. Read-only by
design: no `Write`/`Edit`, nothing pushes. `code-review.yml` is a thin caller into this repo's
reusable `.github/workflows/code-review.yml`, pinned the same way as `claude.yml`. `--yes` skips
this one (its recommended answer is *no*) — pass `--with-code-review` too if you want it added
non-interactively.

**A conventional-commit check on pull request titles.** Only offered when your earlier answers made
the PR title the commit subject — under a merge commit, or a message format that keeps the branch
commits, a wrong title is untidy rather than permanent, and a check nobody needs is just a red X
people learn to ignore. Fifteen lines of `grep`, no third-party action to pin.

## Why there's no skill or plugin here

The script asks its own questions in plain shell prompts, which works for everyone — whichever
assistant you use, or none.

The division it's built around: **deterministic work belongs in the script**, because applying
settings has exactly one right answer and shouldn't route through a model that might transpose a
flag. **Judgment work belongs to you**, because writing a repository's `AGENTS.md` requires knowing
what the project is for and what breaks quietly in it.

The `AGENTS.md` template reflects that. It's a skeleton of prompts rather than filled-in prose,
because a generic `AGENTS.md` is worse than none: it occupies the slot where real knowledge should
go while teaching an agent nothing. [AGENTS.md](./AGENTS.md) in this repo tells any agent how to
help you fill it in — one file, no per-vendor variants to maintain.

## License

MIT — see [LICENSE](./LICENSE).
