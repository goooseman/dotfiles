---
name: g-prepare
description: Use when the user runs /g-prepare or wants to kick off a new piece of work — gathers a short user-facing description of what needs to be done, creates a tracking ticket with a non-technical (PM-flavored) summary and description, creates a matching feature branch, and STOPS. Hand-off point to /g-brainstorm. Does not spec, plan, or write code.
---

# /g-prepare — Stand up a ticket + branch, then stop

## What this skill does

The first step of the `/g-prepare → /g-brainstorm → /g-execute-plan` workflow.

1. Conversationally gathers a **short, user-facing** description of what needs to be done.
2. Drafts a **ticket** with a non-technical summary and description (outcome-oriented, not implementation detail).
3. Creates the ticket via whatever ticket-tracking skill is configured (see below), and the matching feature branch via plain **git**.
4. **Stops.** Tells the user to run `/g-brainstorm` next.

It does **not** spec, plan, design, or write code. Brainstorming and spec-writing belong to `/g-brainstorm`.

## Ticket backend

This skill doesn't talk to any ticket tracker directly. If a ticket-tracking
skill is configured (e.g. `in-jira` for Jira), invoke its `create-ticket`
operation with the drafted summary/description and use its ID-format
convention for the branch name. If no such skill is configured, skip ticket
creation entirely: draft the description for the user's own record, ask them
for a short slug to use in the branch name, and proceed straight to branch
creation.

## Iron rules

1. **Branch creation always goes through plain git.** Ticket creation goes through the configured ticket-tracking skill, if any.
2. **Working tree must be clean** before the branch switch. Don't fold the user's WIP into a fresh feature branch.
3. **Description must be non-technical.** No file paths, function names, frameworks, or implementation choices. If the user gives technical input, reframe it into user-facing outcomes before drafting.
4. **Show the draft before creating.** The user must approve summary + description + branch name in one preview before any external state changes.
5. **Stop after creation.** Do not chain into `/g-brainstorm`. Tell the user the next command and exit.
6. **Don't invent scope.** If the user's input is genuinely too vague to write a meaningful summary, ask one targeted question — don't pad with assumptions.
7. **Don't guess ticket field values.** If the configured ticket-tracking skill needs required fields resolved, let it do that resolution — don't guess on its behalf.

## Procedure

### 0. Preflight

- `git rev-parse --is-inside-work-tree` — must be a git repo.
- `git status --porcelain` — must be empty. If dirty, **stop**; tell the user to commit/stash first. Do not stash for them.
- Confirm current branch is the base (`master`/`main`) or another integration branch — not someone else's feature branch. If it's neither (e.g. a stale release-fix branch), branch off `origin/<base>` explicitly rather than off the current HEAD.

### 1. Gather user input

Ask the user, in conversational form, for:

1. **What's the problem or outcome?** (one or two sentences, user-facing)
2. **Type:** `feat` (new capability), `fix` (broken behavior), `chore` (infra/cleanup), `docs`, `refactor`, etc. If it's obvious from the description, propose one and let them confirm.
3. **Optional:** any specific constraint or context (deadline, dependent ticket, stakeholder ask).

**Don't** ask about: implementation approach, files to touch, test strategy, libraries. Those are `/g-brainstorm` and `/g-plan` territory.

If the user's description is technical (e.g. "refactor the AuthMiddleware class to use the new TokenStore"), **reframe** it before drafting:

> User said: "Refactor AuthMiddleware to use TokenStore"
> Reframed: "Move session token storage to the new compliance-approved store so we can retire the legacy middleware."

Surface the reframe to the user as part of the draft preview.

### 2. Draft the ticket

Build the draft in this shape:

```
Type:     <feat|fix|chore|docs|refactor|test|style|perf|ci|build>
Summary:  <one line, ≤80 chars, user-facing, no jargon, no ticket ID prefix>
Description:
  ## What
  <2–4 sentences describing the user-facing outcome — what changes for the user
   or stakeholder when this is done. No implementation detail.>

  ## Why
  <1–3 sentences on motivation: a constraint, a stakeholder ask, an incident,
   a gap. The "so what" of the work.>

  ## Done when
  <bullet list of 2–5 user-observable acceptance criteria. Each item must be
   verifiable from the outside, not from the code.>

  ## Out of scope (optional)
  <bullet list of things deliberately not addressed in this ticket.>
```

**Description rules:**
- No file paths, class names, function names, framework names, or library names.
- No "we will use X" or "implement in Y" language.
- "Done when" criteria are user-observable behaviors, not "tests pass" or "code reviewed".
- If the user volunteered a constraint ("must ship before the merge freeze on 2026-03-05"), include it in **Why**.

### 3. Draft the branch name

Format: `<type>/<short-kebab-summary>` — append a ticket-ID suffix per the
ticket-tracking skill's convention if one is configured (e.g. `-AICE-XXXX`,
filled in once the ticket is created in step 5), otherwise leave it off.

- Use the type from step 1.
- Kebab-case the summary, ≤40 chars total in the description segment.

Example: `feat/upvote-blockers-board-AICE-XXXX`, `chore/tidy-up-release-script`

### 4. Show the preview

Print to the user:

```
Proposed ticket
================
Type:        feat
Summary:     Let teams upvote blockers on the dashboard
Description:
  ## What
  ...
  ## Why
  ...
  ## Done when
  - ...

Proposed branch: feat/upvote-blockers-board-AICE-XXXX
                 (AICE-XXXX is filled in after the ticket is created)
```

Ask: "Looks good, or want to change anything?"

Honor edits: tweak summary/description/branch name and re-show. One round of edits is normal; if it goes past 3 rounds, the user probably needs to clarify the scope before continuing — surface that.

### 5. Create the ticket and branch

Once the user approves:

1. If a ticket-tracking skill is configured, invoke its `create-ticket`
   operation with the drafted type/summary/description. Capture the resulting
   ticket key/URL. If none is configured, skip straight to step 2.
2. **Create the branch** with plain git, based on the integration branch confirmed in preflight — not the current HEAD if that wasn't the base:
   ```
   git checkout -b <type>/<kebab-summary>[-<ticket-id>] origin/<base>
   ```
   Use the real ticket ID now that the issue exists (from step 1), if any.

Capture the actual branch name for the handoff message.

If ticket creation fails: stop, surface the error verbatim, do not retry blindly. If the branch checkout fails (e.g. dirty tree materialized after preflight), stop and surface it — do not force-checkout over uncommitted work.

### 6. Stop and hand off

Print:

```
Created ticket:         <ticket-id-or-"none">  →  <url-if-any>
Created branch:         <branch-name>
Switched to branch:     <branch-name>

Next: /g-brainstorm — to spec out the work.
```

**Stop.** Do not invoke `/g-brainstorm`. Do not start writing a spec. The user runs the next command when they're ready.

## Quick reference

| Step | Action | Stops here? |
|------|--------|-------------|
| 0 | Preflight (clean tree, in repo) | If preflight fails, yes |
| 1 | Gather user-facing description + type | No |
| 2 | Draft non-technical ticket | No |
| 3 | Draft branch name | No |
| 4 | Show preview, accept edits | No |
| 5 | Create ticket (via configured skill) + git branch | If error, yes |
| 6 | Print handoff message | **Always yes** |

## Rationalization table

| Excuse | Reality |
|--------|---------|
| "User gave me an implementation detail, I'll just include it." | No — reframe to user-facing language. Implementation belongs in the spec, not the ticket. |
| "The description is short, I'll pad it with how-we-might-build-it." | Don't. Padding makes the ticket look complete when scope is actually unclear. Ask one question instead. |
| "The user is in a hurry, I'll skip the preview." | Always preview. External state changes (ticket, remote branch) are hard to undo. |
| "The create response shows a weird assignee, I'll leave it." | That's the ticket-tracking skill's job to check — but if you're driving it directly, don't leave a wrong assignee. |
| "Working tree has unrelated WIP, I'll just switch anyway." | The user's WIP gets stranded. Tell them to commit/stash first. |
| "Current branch looks like an integration branch, I'll fork off it directly." | If it's not actually `master`/`main` (e.g. a stale release-fix branch), branch off `origin/<base>` explicitly instead of the current HEAD. |
| "The user already mentioned `/g-brainstorm` next, I'll just start it." | Stop after creation. Each `/g-` step is a deliberate user-initiated boundary. |
| "User keeps editing the draft — I'll just pick the best version and proceed." | Three rounds of edits = unclear scope. Surface that and let the user re-think, not steamroll. |

## Red flags — STOP and reset

- About to include code/file/framework names in the ticket description.
- About to skip the preview step.
- About to chain into `/g-brainstorm` automatically.
- About to create a ticket from a one-word description without asking a clarifying question.
- About to stash or move the user's uncommitted work.

## Common mistakes

- **Front-loading implementation in the description.** The ticket is read by PMs, leads, and future you 6 months later. Keep it about outcome.
- **Branch name too long.** Kebab segment ≤40 chars; the full branch name should fit comfortably under 60. Long branch names break tooling and look ugly in PR titles.
- **Skipping the type prompt.** "feat" vs "fix" matters — it shapes the eventual conventional-commit type and the PR title `/g-execute-plan` will produce.
- **Creating the ticket before the user approves the draft.** Tickets are visible to others the moment they exist. Preview first.
- **Continuing into spec-writing.** This skill ends at "Created branch." The user runs `/g-brainstorm` themselves.
