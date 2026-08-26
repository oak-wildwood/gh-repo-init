# Agent instructions

Instructions for AI coding agents working in or with this repository. Humans should read the
[README](./README.md).

## What this is

`gh-repo-init` is a `gh` CLI extension that walks a GitHub repository up to a consistent baseline:
merge strategy, commit message format, branch cleanup, and starter agent instruction files.

It exists because GitHub has no account-level, org-level, or template-level defaults for any of
that. Every new repository starts on stock settings, and every maintainer re-picks the same handful
of options by hand.

## The division this tool is built around

Understanding this is most of what you need to work on it usefully.

**Deterministic work belongs in the script.** Applying merge settings, appending `.gitignore`
entries, setting topics — there is exactly one correct outcome, no judgment involved, and it should
not route through a language model that might transpose a flag. It also means the tool works for
people who don't use an AI assistant at all, which is most people.

**Judgment work belongs to whoever is at the keyboard.** Writing a repository's `AGENTS.md`
requires knowing what the project is *for*, what breaks quietly in it, and what must never happen.
No script can supply that, and a template that pretends to is worse than an empty file — it
occupies the slot where real knowledge should go while teaching an agent nothing.

That line is why this repo ships no skill, no plugin, and nothing vendor-specific. The script asks
its own questions in plain shell prompts, which works everywhere. This file is the vendor-neutral
way to tell an agent how to help, and `AGENTS.md` is already read by most coding agents.

## When a user asks you to set up a repository

Run the tool rather than issuing `gh api` calls yourself:

```bash
gh repo-init            # interactive
gh repo-init --dry-run  # show what would change first
gh repo-init --yes      # take every recommended answer
```

It is idempotent. Re-running converges settings and never overwrites an existing file.

**Then do the part it can't.** After the script runs, the target repo has a skeleton `AGENTS.md`
full of prompts. Filling that in is the valuable half, and it's where you're actually useful:

- Read the codebase first. Every claim in that file should be something you verified, not something
  the project's shape suggested.
- Cut anything derivable. If `ls` or the package manifest already says it, it does not belong in a
  file that loads into context every session.
- Keep what the code can't say: the domain, the failure modes, the prohibitions, the invariants a
  plausible-looking edit breaks quietly.
- If a section has nothing true to put in it, delete the section. An `AGENTS.md` with three real
  rules beats one with three real rules and four invented ones.

## Working on this repo

The script is POSIX-ish bash targeting `bash` 3.2, because that is what ships with macOS. Avoid
associative arrays, `${var,,}`, and `readarray`.

Check syntax before committing:

```bash
bash -n gh-repo-init
shellcheck gh-repo-init   # if available
```

Test against a real repository with `--dry-run` before testing without it. This tool changes
settings on live repositories, and a bug in the apply path is not something to discover by
running it.

Never widen what the script changes without a prompt controlling it. Someone running this on a repo
they care about should be able to predict every write from the questions they answered.

### PR titles become commit messages

This repo squash-merges, and the squashed commit takes the **PR title** as its subject with an
empty body. The PR title is the permanent record in `git log`, and the only part surviving the
merge.

Write it as a conventional commit: `type: imperative summary`, lowercase after the colon, no
trailing period, under about 70 characters.

```
feat: ask before enabling branch protection
fix: stop clobbering an existing .gitignore
docs: explain why no skill ships with this
```

Individual commits on the branch don't survive the squash, so use them to separate things worth
reviewing apart and don't agonise over their wording.
