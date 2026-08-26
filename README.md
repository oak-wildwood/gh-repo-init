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
```

Re-running is safe. Settings converge, and existing files are never overwritten.

## What it asks about

**Merge strategy.** Squash-only, squash-plus-rebase, everything, or leave it alone. The default
keeps rebase available as an escape hatch for the occasional branch whose individual commits are
worth preserving.

**Squash commit message.** Pull request title alone, or title plus description. Title-only pairs
well with conventional commits: the PR title becomes the commit subject, so it's the permanent
record rather than a label on a discussion.

**Branch cleanup.** Whether merged branches delete themselves.

**Branch protection.** Off by default, because it behaves differently on public and private repos
and a misconfigured rule can lock a solo maintainer out of their own default branch. When enabled,
it requires a pull request and an up-to-date branch but *no* reviewers — on a solo repo you can't
approve your own PR, so requiring one review makes the branch unmergeable.

**Agent instruction files.** `AGENTS.md`, a `CLAUDE.md` that imports it, the Claude Code GitHub
workflow, and `.gitignore` entries for agent-local files. Each is asked about separately and
skipped if already present.

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
