---
name: g-execute-plan
description: Use when the user runs /g-execute-plan or asks to take an approved spec all the way to a green PR. Orchestrates spec-driven execution via async background agents (one per task, recommended model per task type), then iterative Codex code review, ticket state, PR creation, CI pipeline watch with auto-fix, and AI-reviewer comment resolution — all in one supervised loop on the current branch. Optional argument: explicit path to the spec file.
---

# /g-execute-plan — Spec → atomic commits → green PR (supervised)

## What this skill does

A single orchestrator that drives an approved **spec** from "ready" to "PR is green and review-clean". There is NO separate plan document — the spec (per the /g-brainstorm workflow) is the implementation contract, carrying file paths, interfaces, config keys, enumerated test cases, and acceptance criteria.

1. **Derive tasks from the spec** — one task per component or coherent change, ordered by dependency (clients/helpers → integration points → config → tests → e2e verification). Record with TaskCreate.
2. **Execute each task via an async background agent** — `Agent` tool with `run_in_background: true`, model chosen per the table below. One task → one agent → one atomic commit.
3. **Codex review loop** — runs `/codex-review code` to apply post-implementation fixes as atomic commits.
4. **Ticket to In Progress** — via the configured ticket-tracking skill, if any. Mandatory before opening a PR when one is configured.
5. **Open the PR** — via the `gh` CLI. Title must be conventional-commits, ≤72 chars, with the ticket ID at the end if the workflow uses one.
6. **Watch the pipeline** — `gh pr checks --watch`. If it fails, diagnose, fix in atomic commits, push, watch again.
7. **AI-reviewer comment loop** — pull bot review comments, triage (agree → fix-and-commit, disagree → reply with reason), push, watch CI again.
8. **Stop** when the PR is green, no actionable AI-reviewer comments remain, and the user has been handed back control.

This skill **never merges and never force-pushes**. It pushes commits and reads CI/comments. Final merge is the user's call.

## Ticket backend

This skill doesn't talk to any ticket tracker directly. If a ticket-tracking
skill is configured (e.g. `in-jira` for Jira), use its `transition-to-in-progress`
operation and its ticket-ID format conventions for PR titles/branch names. If
none is configured, skip the ticket-state step entirely and drop the ticket-ID
requirement from the PR title format.

## Async agent execution model

Every implementation task is dispatched as an **async background agent** (`run_in_background: true`). The orchestrator stays thin: it sequences, verifies, and commits — agents write the code.

**Model per task type** (pass via the Agent tool's `model` param):

| Task type | Model | Examples |
|-----------|-------|----------|
| Trivial / mechanical | `haiku` | config key additions, URL swaps in locale files, renames, boilerplate file scaffolding |
| Standard well-specified implementation | `sonnet` | a new client/helper following an existing pattern the spec names, straightforward unit tests |
| Complex logic, integration, or debugging | omit (inherit session model) | cache/coalescing logic, route-handler wiring on a hot path, diagnosing a failing test |

When unsure between two tiers, pick the higher one.

**Concurrency rules:**

- Tasks that are independent AND touch disjoint files may be dispatched in parallel (multiple async agents in one message).
- Dependent tasks, or tasks touching overlapping files, run strictly one at a time: dispatch → wait for the completion notification → verify → commit → dispatch the next.
- **The orchestrator owns commits.** Agents are instructed to leave changes uncommitted; after each agent completes, the orchestrator reviews the diff, runs cheap checks (typecheck / lint on changed files), and lands exactly one atomic commit per task (via the `commit` skill, ticket ID included if the workflow uses one). This prevents interleaved commits from parallel agents.
- Each agent prompt must include: the spec path, the single task's scope ("do ONLY this task"), the relevant spec excerpts, and "do not commit; report what you changed and how you verified it".
- If an agent's result is wrong or incomplete, send a follow-up via SendMessage to the same agent (it keeps its context) rather than spawning a fresh one.

## Iron rules

These exist because each one has burned this workflow before. Violating any one breaks downstream value.

1. **Working tree must be clean at start.** The user's WIP can't be folded into task commits or fix commits.
2. **One commit per logical unit.** Per spec task during execution. Per Codex finding during review. Per AI-reviewer thread during CI cycle. No bundling.
3. **Never `--amend`, `--no-verify`, `git reset --hard`, `git push --force` (or `--force-with-lease`).** A failed hook or check is a real signal — fix it with a new commit.
4. **Ticket state and PR tooling are separate.** Ticket state changes go through the configured ticket-tracking skill (if any); PR creation and all GitHub operations use the `gh` CLI directly.
5. **PR title format is non-negotiable.** Conventional commits, scope optional, ticket ID at the end if the workflow uses one, ≤72 chars total. Example: `fix(auth): enable SSO CPV2-2123`. CI commitlint (where configured) commonly fails past 72 chars. Detail goes in the PR body, not the title.
6. **Hard caps on every loop:**
   - Spec execution: as many commits as the derived task list has tasks (no creative scope expansion beyond the spec).
   - Codex review: 5 iterations (the `codex-review` skill's own cap).
   - CI auto-fix per push: 3 attempts on the same failure mode.
   - AI-reviewer comment loop: 5 iterations.
7. **Don't ignore disagreement.** If you disagree with a Codex finding or an AI-reviewer comment, mark it disagreed with a one-line reason and reply on the PR thread. Don't silently skip.
8. **Push only after a clean local state.** Commits land, hooks pass, then push. No "push and hope CI does the lint."

## Argument

```
/g-execute-plan [path/to/spec.md]
```

- If a path is given: use that spec file.
- If no path: auto-discover. Look in `docs/superpowers/specs/` for the most recently modified `YYYY-MM-DD-*.md`. If multiple candidates exist or none exists, **stop and ask the user** — guessing the wrong spec is worse than asking.

## Required sub-skills

These MUST be invoked at the marked points; do not reimplement them.

- **codex-review** (`/codex-review code`) — for post-execution code review.
- **commit** — for commit message formatting on every commit this skill makes.
- **superpowers:verification-before-completion** — before claiming any phase is "done".
- **superpowers:test-driven-development** — passed down into agent prompts for implementation tasks that create logic (agents write the failing test first).
- **superpowers:systematic-debugging** — for non-obvious CI or test failures.

## Procedure

### 0. Preflight (once)

Run all checks before touching anything:

- `command -v gh && gh auth status` — gh CLI present and logged in.
- `command -v agent && agent status` — Cursor CLI present and logged in (codex-review needs it).
- `git rev-parse --is-inside-work-tree` — repo.
- `git status --porcelain` — must be empty. If not, **stop**; tell the user to commit/stash first. Do NOT stash for them.
- Resolve spec file (see Argument above). Read it end-to-end so you understand scope.
- If a ticket-tracking skill is configured, resolve the ticket ID per its format convention (branch name, spec header, recent commit messages). If not found, **stop and ask**. If no ticket-tracking skill is configured, skip this.
- Confirm current branch is the feature branch, not the base (`master`/`main`/`develop`). If on the base, stop.
- Resolve base branch: `git symbolic-ref --short refs/remotes/origin/HEAD` (strip `origin/`), fallback `master` then `main`.
- Capture `START_SHA="$(git rev-parse HEAD)"` for the final summary.
- **Derive the task list from the spec** (components + config + tests + any multi-repo mechanics the spec defines), record via TaskCreate with dependency order, and assign each task a model tier from the table above.
- **Show the user a one-paragraph plan-of-action** before proceeding: which spec, which ticket (if any), which base, the derived task list with model tiers, expected loops. Give them a chance to abort.

### 1. Move ticket to In Progress

If a ticket-tracking skill is configured, invoke its `transition-to-in-progress`
operation and confirm it actually landed before moving on — a transition call
can report success while the issue is left in a state a downstream gate
doesn't recognize. If that skill documents a stale-state gotcha for a specific
CI check, follow its fix order rather than guessing. If the call fails, stop
and surface the error. If no ticket-tracking skill is configured, skip this
step.

### 2. Execute the spec via async agents

For each task in dependency order (parallel only when independent + disjoint files, per the Async agent execution model above):

1. Dispatch an async background agent (`run_in_background: true`, model per the task's tier) with the spec path, the task's exact scope, relevant spec excerpts, the TDD directive for logic tasks, and "do not commit".
2. On the completion notification: review the diff against the spec, run cheap repo-local checks (typecheck, lint on changed files).
3. Land one atomic commit (via the `commit` skill, Conventional Commits, ticket ID included if the workflow uses one). Mark the task completed.
4. If the result is wrong/incomplete: SendMessage the same agent with the correction (cap: 2 follow-ups, then take over inline or stop and report).

Do not run the full test suite per task — that's a phase boundary.

When all tasks are done OR a task is blocked:
- If blocked: stop, summarize what's done and what's blocked, hand to user.
- If done: run the project's full test suite once. Failures here are bugs in the implementation — fix them as additional atomic commits before moving on.

### 3. Codex review loop

Invoke the `codex-review` skill with arg `code`. It will run its own iterate-and-fix loop (cap of 5 iterations, atomic commits, disagree-and-skip path, all per its skill). When it returns:
- Note iterations used, findings applied, findings skipped (with reasons).
- If it stopped because the cap hit and there are still actionable findings, **stop the orchestrator** and hand to the user. A non-converging review means the implementation has a deeper issue than fix-and-commit can resolve.

### 4. Final pre-PR checks

- Re-run the full test suite once. All green.
- Run every verification step the spec defines (its acceptance criteria are the definition of done) — invoke `superpowers:verification-before-completion`.
- `git log {BASE}..HEAD --oneline` — sanity-check the commit list reads cleanly. Commits should each describe one thing.
- Confirm the working tree is clean.

### 5. Open the PR

Create the PR with `gh pr create` (base = the resolved base branch). Provide:
- A PR title that follows the format below.
- A PR body that includes: short summary, link to the spec file, the ticket ID (if any), "Codex review iterations: N (M findings applied, K disagreed)", testing checklist, and a "How to verify" section. End the body with the standard Claude Code attribution line.

**PR title rules** (enforced before calling `gh pr create`):

- Format: `<type>(<scope>): <description>[ <TICKET-ID>]`
- `<type>`: one of `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `style`, `perf`, `ci`, `build`.
- `<scope>` optional, lowercase.
- `<description>` lowercase, no trailing period, present tense.
- Ticket ID (if the workflow uses one) at the **end**, uppercase, no brackets, single space before it (e.g. `CPV2-15484`).
- **Total length ≤72 chars.** Count it. If it's 73, trim the scope or the description. Detail goes in the body.

Pre-flight check before the call:

```bash
TITLE="fix(auth): enable SSO CPV2-2123"
[ "${#TITLE}" -le 72 ] || { echo "PR title too long: ${#TITLE} chars"; exit 1; }
echo "$TITLE" | grep -Eq '^(feat|fix|docs|chore|refactor|test|style|perf|ci|build)(\([a-z0-9_-]+\))?: .+( [A-Z][A-Z0-9]+-[0-9]+)?$' \
  || { echo "PR title format invalid: $TITLE"; exit 1; }
```

If a PR already exists on this branch (`gh pr view` succeeds), capture the PR number and continue from step 6.

### 6. CI pipeline watch + fix loop

For up to 3 watch iterations after each push:

1. Watch:
   ```bash
   gh pr checks "$PR_NUMBER" --watch --fail-fast
   ```
   This blocks until checks finish (or one fails fast).

2. If all green: continue to step 7.

3. If a check failed:
   - `gh pr checks "$PR_NUMBER"` — list the failing checks.
   - For each failing check, fetch logs:
     ```bash
     gh run view --log-failed --job "$JOB_ID"
     ```
     or, if it's a non-Actions check, follow the `details_url`.
   - Diagnose the actual failure (use **superpowers:systematic-debugging** if it's non-obvious — don't just retry).
   - **Distinguish**:
     - Real failure: fix in code, commit (atomic, conventional, ticket ID included if used), push. Non-trivial fixes may be dispatched to an async agent (inherit model) per the execution model above.
     - Flake (test that's known-flaky, network blip in fetch step): re-trigger only the failing check via `gh run rerun --failed --job ...`. Do NOT push an empty commit. Cap: 1 rerun per flake.
     - Infra outage: stop the loop, report to user.
   - Push: `git push` (no force).
   - Loop back to step 1.

4. After 3 push-and-watch iterations on the same failure mode, **stop**. The same failure recurring means deeper investigation is needed; hand to user.

### 7. AI-reviewer comment loop

Once CI is green, fetch PR review comments:

```bash
gh pr view "$PR_NUMBER" --json reviews,comments
gh api "repos/{owner}/{repo}/pulls/$PR_NUMBER/comments"
```

Filter for AI-bot reviewers (any login containing `bot`, `[bot]`, `coderabbit`, `cursor`, `greptile`, or other bot-style reviewers configured in this repo). Human reviewer comments are **out of scope for this skill** — flag them in the final summary so the user handles them, but do not auto-respond.

For each AI-bot comment:

1. Decide: agree / disagree / defer.
2. **Agree** → make the fix in an atomic commit. Reply on the comment thread with `gh api ... -X POST` linking to the commit SHA: "Fixed in <sha>."
3. **Disagree** → reply on the thread with a one-line reason. Do not just close the thread silently.
4. **Defer** → reply with a brief reason (e.g. "out of scope for this branch; tracking in <ticket-id>"). If you don't have a follow-up ticket, ask the user before deferring.

After processing all comments, push, then loop back to step 6 (CI watch). New commits = new pipeline run. **Cap: 5 iterations of (review comments → fix → push → CI watch).** If still not converging, stop and hand to user.

### 8. Final summary

When the loop terminates cleanly, print:

```
g-execute-plan summary
======================
Spec:        <path>
Ticket:      <ticket-id-or-"none"> (In Progress)
Branch:      <branch>  (base: <base>)
PR:          #<n> <url>  — CI: green
Commits:     <count>  (range: <START_SHA>..HEAD)
Tasks:       <count> executed via async agents (<haiku>/<sonnet>/<inherit> split)
Codex:       <iter> iterations, <applied> applied, <skipped> skipped
AI review:   <iter> iterations, <applied> applied, <skipped> skipped
Human comments outstanding: <list with author + URL>  ← user action needed
```

End with: "Ready for human review / merge. I haven't merged."

## Loop control flow

```dot
digraph g_execute_plan {
    "Preflight passes?" [shape=diamond];
    "Move ticket to In Progress" [shape=box];
    "Execute spec tasks via async agents" [shape=box];
    "Spec tasks all green?" [shape=diamond];
    "Codex review loop" [shape=box];
    "Open PR" [shape=box];
    "CI watch" [shape=box];
    "CI green?" [shape=diamond];
    "Diagnose + fix + push" [shape=box];
    "Push attempts < 3?" [shape=diamond];
    "Fetch AI-reviewer comments" [shape=box];
    "Any actionable AI comments?" [shape=diamond];
    "Triage + atomic commits + reply + push" [shape=box];
    "AI loop iter < 5?" [shape=diamond];
    "Final summary, hand to user" [shape=doublecircle];
    "Stop: blocked, hand to user" [shape=doublecircle];
    "Stop: preflight fail" [shape=doublecircle];

    "Preflight passes?" -> "Move ticket to In Progress" [label="yes"];
    "Preflight passes?" -> "Stop: preflight fail" [label="no"];
    "Move ticket to In Progress" -> "Execute spec tasks via async agents";
    "Execute spec tasks via async agents" -> "Spec tasks all green?";
    "Spec tasks all green?" -> "Stop: blocked, hand to user" [label="no"];
    "Spec tasks all green?" -> "Codex review loop" [label="yes"];
    "Codex review loop" -> "Open PR";
    "Open PR" -> "CI watch";
    "CI watch" -> "CI green?";
    "CI green?" -> "Fetch AI-reviewer comments" [label="yes"];
    "CI green?" -> "Push attempts < 3?" [label="no"];
    "Push attempts < 3?" -> "Diagnose + fix + push" [label="yes"];
    "Push attempts < 3?" -> "Stop: blocked, hand to user" [label="no"];
    "Diagnose + fix + push" -> "CI watch";
    "Fetch AI-reviewer comments" -> "Any actionable AI comments?";
    "Any actionable AI comments?" -> "Final summary, hand to user" [label="no"];
    "Any actionable AI comments?" -> "AI loop iter < 5?" [label="yes"];
    "AI loop iter < 5?" -> "Triage + atomic commits + reply + push" [label="yes"];
    "AI loop iter < 5?" -> "Stop: blocked, hand to user" [label="no"];
    "Triage + atomic commits + reply + push" -> "CI watch";
}
```

## Rationalizations, red flags, and common mistakes

These are the same failure modes seen three ways — the excuse you'd make, the
signal to stop, and how it shows up in hindsight. Internalize the rule, not
the framing.

| Rule | Rationalization to reject | Hindsight framing |
|------|---------------------------|--------------------|
| One commit per task/finding/thread, never bundled. | "Two agents finished, I'll commit both diffs together." / "Bot left 12 nits, one big fix commit." | Interleaved diffs and bundled fixes defeat `git bisect` and atomic review. |
| Every implementation task goes through an async agent. | "This task is small, I'll just do it inline." | Inline work hides progress and creeps into bundled commits. |
| Orchestrator owns all commits; agents never commit. | "The agent committed by itself, close enough." | If one did, stop, inspect, and re-land it properly (new commit; never amend/reset). |
| PR title ≤72 chars, ticket ID at the end if used. | "It's 75 chars but reads better." | Commitlint (where configured) fails past the limit — trim it. |
| Never bypass a failing hook or check. | "CI is failing, just `--no-verify` the next push." | The hook caught a real issue; bypassing pushes broken code others can see. |
| Never force-push from this skill. | "Force-push will tidy the history before review." | History stays append-only — it's the audit trail of how the PR got built. |
| Non-convergence (contradicting findings, repeated failures) means stop, not paper over. | "Codex finding 4 contradicts finding 2 — I'll just pick one." | That's the orchestrator's signal to stop and hand to the user. |
| One rerun per flake, max. | "Test is flaky, I'll just rerun until it passes." | Flaking twice means treat it as a real failure. |
| Human reviewer comments are out of scope. | "I'll just answer the human's comment too." | Auto-responding to humans is presumptuous — surface it instead. |
| Different phases get different pushes. | "I'll batch the Codex pass and the AI-reviewer pass into one push." | They're different commit framings — push between them. |
| Merge is always the user's call. | "PR is green and bot has no comments — I'll go ahead and merge." | Never. Surface readiness, don't act on it. |
| Multiple candidate specs means ask, not guess. | "I'll just pick the most recently modified spec." | Guessing the wrong spec wastes the whole run — ask. |
| 4th CI auto-fix / 6th AI-reviewer iteration never happens. | "One more loop and it'll converge." | Caps exist because non-convergence is itself the signal — stop and hand to user. |

**All of these mean: stop the orchestrator, surface state to the user, let them decide.**

## Quick reference

```bash
# Preflight
gh auth status && agent status
git status --porcelain  # must be empty
BASE="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/master)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
TICKET_ID="$(echo "$BRANCH" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+')"  # fallback: spec header, recent commits; empty if no tracker configured

# PR title check
TITLE="fix(auth): enable SSO ${TICKET_ID}"
[ "${#TITLE}" -le 72 ] && echo "$TITLE" | grep -Eq '^(feat|fix|docs|chore|refactor|test|style|perf|ci|build)(\([a-z0-9_-]+\))?: .+( [A-Z][A-Z0-9]+-[0-9]+)?$'

# CI watch
gh pr checks "$PR_NUMBER" --watch --fail-fast

# Pull AI-reviewer comments
gh api "repos/{owner}/{repo}/pulls/$PR_NUMBER/comments" \
  --jq '.[] | select(.user.login | test("bot|coderabbit|cursor|greptile"; "i"))'

# Reply on a thread
gh api "repos/{owner}/{repo}/pulls/$PR_NUMBER/comments/$COMMENT_ID/replies" \
  -X POST -f body="Fixed in $(git rev-parse HEAD)."
```
