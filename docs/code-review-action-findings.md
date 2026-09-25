# Code-review action: findings and recommendation

Scoping writeup for #42. Three `@review` runs on cooperage#35 each posted nothing. Each came after a
fix that addressed a real bug: #40 added `Task`/`Read`/`Glob`/`Grep`, and #41 replaced a heredoc
with `Write`. Every run had the same signature: about 8 turns, about 25s, one permission denial,
conclusion `success`, and no review comment. This document explains why incremental
`allowed_tools` patches weren't converging, and what to build instead.

Each claim is marked **verified** (observed directly) or **inferred** (reasoned, not yet confirmed).

## Findings

### 1. A permission denial does not abort a claude-code-action run (verified)

The working hypothesis in #42 was that headless claude-code-action aborts on the first denial.
That hypothesis is wrong. The nightly run that produced this document uses the same
`anthropics/claude-code-action@v1`, through `actions/nightly-run`, with a restrictive
`--allowedTools`. During this run it was denied `gh api`, `WebFetch`, a compound Bash command, an
`ls` outside the working directory, and a cross-repo `gh pr view`. After each denial it received a
tool error and continued.

In headless mode a denial becomes an error result that the model sees. The run ends when the model
ends its turn. So "one denial, then nothing" means the model *chose to stop* after that denial. It
most likely concluded that it couldn't do the task and said so in its final message, and nobody
reads that message.

### 2. Nobody has read which tool was denied (verified)

The action already uploads the full Agent SDK transcript as the `run-report-<pr>-<run_id>` artifact.
The last `result` entry in that transcript has a `permission_denials` array with the tool name and
input of every denial. The transcript also records the model's final message. PR #40 quoted only
`permission_denials_count: 1`. Each fix since then has guessed at the denied tool instead of reading
it.

```bash
gh run download <run_id> -R oak-wildwood/cooperage -n run-report-35-<run_id>
jq '[.[] | select(.type == "result")] | last | {permission_denials, result}' claude-execution-output.json
```

That command costs no CI runs and no tokens. It turns the next change into a fix instead of another
guess.

### 3. Best guess at the denied tool: `Skill` (inferred)

The prompt tells the model to use the `mattpocock-skills:code-review` skill. Invoking a skill goes
through the `Skill` tool, and `Skill` is not in `allowed_tools`. A denied `Skill` call before any
real work would produce exactly this signature: a few turns spent looking for another route, one
denial, a short run, and a closing message instead of a report.

Local `claude -p` runs would not reproduce this if the local user or project settings already
allow skills. That fits "a local run with the same prompt and `allowedTools` keeps going". The
earlier denials were still real bugs (`Task`, the heredoc), but they sit *behind* this one. Once the
skill loads, those tools are what it uses.

Confirm this with finding 2 before acting on it.

### 4. The success signal is wrong by construction (verified)

Posting the review is left to the model (`gh pr comment` in the prompt). The job's success comes
from claude-code-action's conclusion, which only means the model ended its turn cleanly. "Model
gave up politely" and "model posted a review" both show up as `success`. The Run Report then says
`success` on a run that did nothing, which is what made this take three CI runs to notice.

This goes against the division in AGENTS.md: posting a known file to a known PR has one correct
outcome and belongs in the script, not the model.

### 5. The third-party skill is unpinned and designed for interactive use (verified)

`plugin_marketplaces` pulls `mattpocock/skills` from its default branch on every run. This repo
pins its own behaviour carefully (the caller runs `@v1`, and actions run from `job.workflow_sha`,
per ADR 0014). The skill's instructions, and so the tools it needs, can change under a pinned caller
without any change here. The tool list has already shifted underneath us twice (`Task`, then
`Write`).

The skill also assumes an interactive session: it asks the user for things and writes files as it
likes. The prompt has to argue against that ("do not ask", "use Write, not a heredoc").

## On the invocation-shape question

- **claude-code-action headless is fine.** Finding 1 removes the reason to leave it. Sub-agents
  through `Task` also work headless, as long as `Task` is allowed. Each sub-agent's denials go back
  to the parent the same way. The action also does the collaborator check, auth, and the
  `execution_file` output that the Run Report relies on.
- **`claude -p` directly** would reproduce all of that by hand and fix nothing that is actually
  broken.
- **The Agent SDK** (a custom script) would be a heavier build for the same outcome. It's only worth
  it if we later want programmatic control over the sub-agents, which nothing here needs.

The problem isn't the vehicle. It's (a) a packaged interactive skill run unpinned in CI and (b)
letting the model own the step that decides success.

## Recommendation

1. **Read the artifact first** (finding 2). If the denial is `Skill`, that confirms the diagnosis
   and needs no further CI runs.
2. **Move posting out of the model.** Prompt the model to make its *final message* the complete
   report and nothing else. Then add a composite-action step to `actions/code-review/action.yml`
   that extracts it:

   ```bash
   jq -r '[.[] | select(.type == "result")] | last | .result // empty' "$EXECUTION_FILE" > report.md
   [ -s report.md ] || { echo "::error::No review produced" >&2; exit 1; }
   gh pr comment "$PR_NUMBER" --body-file report.md
   ```

   The job now fails loudly when no review is produced. The model no longer needs `Write` (unscoped
   since #41) or `Bash(gh pr comment:*)`, so the reviewer becomes genuinely read-only again.
3. **Inline the two-axis review instead of invoking the packaged skill.** Put the Standards and Spec
   instructions directly into the action's prompt, written for CI (non-interactive, final message
   is the report). Credit mattpocock/skills and check its license before copying text. That pins the
   behaviour to this repo's commit like everything else and removes `Skill` and the plugin install.
   Keep the parallel sub-agents through `Task` if the separation helps review quality. An
   alternative is two jobs, one per axis, each with its own prompt, combined by a shell step. That
   gives deterministic parallelism and a failure per axis that you can see, at the cost of a little
   more YAML.
4. **Resulting `allowed_tools`:** `Read,Glob,Grep,Task` plus read-only
   `Bash(git diff:*)`, `Bash(git log:*)`, `Bash(git rev-parse:*)`, `Bash(gh pr view:*)`, and
   `Bash(gh issue view:*)`. No `Write`, no `gh pr comment`.

If the skill must stay, the minimal step is to add `Skill` to `allowed_tools`. Do it only after
finding 2 confirms that `Skill` was the denied tool. Findings 4 and 5 would still apply.

## Why this PR doesn't implement it

The `allowed_tools` default lives in `.github/workflows/code-review.yml`, and the unattended run
that wrote this may not modify `.github/workflows`. The prompt change and the posting step in
`actions/code-review/action.yml` depend on that default changing at the same time, so all of it
should land as one reviewed change.

Also worth fixing in that change: the README still describes the reviewer as "no `Write`/`Edit`",
which has been untrue since #41. Recommendation 2 makes it true again.
