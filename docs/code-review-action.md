# Code review action: findings and recommended shape

Scoping notes for gh-repo-init#42, written after #40 and #41 each fixed a real
bug but `@review` still posted nothing. Nothing here has been verified against
a CI run yet; each claim says what it rests on.

## What the failing runs tell us

The signature is the same every time: about 8 turns, about 25 seconds, one
permission denial, `success`, no report.

- **The run never gets to the review.** A two-axis review that spawns two
  sub-agents and reads a diff on opus takes minutes, not 25 seconds. Eight
  turns is about enough to look up the base branch, diff, try to start the
  skill, get denied, and stop. The run ends at the first step that needs
  something the allowlist doesn't have.
- **"Denials abort the run" is probably wrong.** In `claude -p` and the Agent
  SDK that `claude-code-action` wraps, a denied tool call is returned to the
  model as an error, and the run carries on. `permission_denials` in the
  result message is a record, not a stop signal. What we see fits the model
  deciding it can't continue and ending its turn. `success` only means the
  loop finished normally.
- **The model's reason for stopping is thrown away.** With a `prompt` input,
  `claude-code-action` runs in agent mode and posts nothing itself. The final
  message, plus the exact tool and input that was denied, sits in the
  `execution_file` artifact. The Run Report reads only tokens and duration from
  it. Every fix so far has been a guess, but the answer has been in the
  artifact the whole time.
- **The local repro isn't the same environment.** A local `claude -p` reads the
  user's `~/.claude` settings, which may already allow tools (or pre-approve
  skills) that CI has to be granted explicitly. It also has the plugin
  installed a different way. "Same prompt and `allowedTools`" doesn't mean
  the same permissions in effect.
- **Likely culprit: `Skill` isn't in the allowlist.** The prompt says "use the
  mattpocock-skills:code-review skill", and the model loads a skill through
  the `Skill` tool. That tool isn't in `allowed_tools`. It would be the first
  gated call, and it happens at about the right turn count. This is still a
  hypothesis. The step summary added in this PR will confirm it or rule it
  out on the next run.

## Why the packaged skill is the wrong shape for CI

Adding `Skill` might get this run through, but the next unknown would stop it
in the same way:

- **We can't write its allowlist.** The skill decides which tools it needs,
  and that list changes when upstream edits the skill. A read-only allowlist
  and a third-party skill we don't control are always one release away from
  another silent denial.
- **It isn't pinned.** `plugin_marketplaces` installs
  `github.com/mattpocock/skills` at whatever is on its default branch when the
  job runs. That cuts against the pinning in `code-review.yml` (a pinned
  caller should run pinned behaviour). It also means third-party code steers
  a job that holds `pull-requests: write` and the caller's OAuth token.
- **It's written for a person at the keyboard.** It asks questions and
  expects an answer. Our prompt adds "don't ask" on top, but that's working
  around the skill rather than using it.
- **It puts deterministic work on the model.** Finding the base branch,
  producing the diff, writing a file, and posting a comment each have one
  correct outcome. Per `AGENTS.md`, those belong in the script. Right now they
  are exactly the steps using `Bash`, `Write`, and `gh pr comment`, which
  are the permissions that keep breaking.

## Recommended shape

Keep `claude-code-action`, so the execution file and Run Report plumbing stay
as they are. Change what goes on either side of it:

1. **Before Claude, in shell:** resolve the base branch, write
   `git diff origin/<base>...HEAD` and the PR title and body to files in the
   workspace, and find the linked spec issue if there is one. None of this
   needs a model.
2. **Claude, judgment only:** vendor the two-axis instructions (Standards and
   Spec) as a prompt file in `actions/code-review/`, pinned with the action.
   Credit the source. Tools: `Read,Glob,Grep`, plus `Task` if keeping the
   parallel sub-agents is worth it. Sub-agents inherit the same permission
   rules, so they get read-only access too. No `Bash`, `Write`, or `Skill`.
   The report is the final message.
3. **After Claude, in shell:** take the final `result` from the execution
   file and post it with `gh pr comment --body-file`. If it's empty, or the
   run had denials, fail the job so a silent run can't happen.

This fixes the issue in a way allowlist patches can't. The model's allowlist
becomes three read-only tools that don't depend on the project. Every write
happens in a step whose behaviour can be read in `action.yml`. A run that
doesn't produce a review turns the job red instead of green.

**Considered and rejected:**

- **Running `claude -p` directly in a step.** It works, but it drops the
  execution-file and Run Report handling that the other actions share, for
  no gain once the model has no side effects.
- **The Agent SDK.** It adds a Node or Python program to maintain in a repo
  that is shell and YAML. Worth it only if we need a custom permission
  callback, and with a read-only model we don't.
- **Broader tool access.** It treats the symptom, and it widens what a
  "read-only reviewer" can touch.

## What this PR changes

Only diagnostics. `actions/lib/explain-run.sh` writes the final message and
every permission denial (tool name and input) from the execution file to the
job's step summary. Once this ships on `v1`, the next `@review` run shows
which call was denied and what the model said about it. That confirms or
rules out the `Skill` hypothesis before anyone builds the redesign above.
