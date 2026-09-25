---
name: g-prepare
description: Use when the user runs /g-prepare or wants to kick off a new piece of work — gathers a short user-facing description of what needs to be done, creates a Jira ticket with a non-technical (PM-flavored) summary and description, creates a matching feature branch, and STOPS. Hand-off point to /g-brainstorm. Does not spec, plan, or write code.
---

# /g-prepare — Stand up Jira + branch, then stop

## What this skill does

The first step of the `/g-prepare → /g-brainstorm → /g-execute-plan` workflow.

1. Conversationally gathers a **short, user-facing** description of what needs to be done.
2. Drafts a **Jira ticket** with a non-technical summary and description (outcome-oriented, not implementation detail).
3. Creates the ticket via the **DAST-Orch Jira MCP tools** and the matching feature branch via plain **git**.
4. **Stops.** Tells the user to run `/g-brainstorm` next.

It does **not** spec, plan, design, or write code. Brainstorming and spec-writing belong to `/g-brainstorm`.

## Iron rules

1. **Ticket creation goes through DAST-Orch, branch creation through git.** There is no `intuit-closed-loop` skill in this environment (removed by the user — do not reference it, invoke it, or assume it exists). Use `mcp__DAST-Orch__jira_create_issue` (call `mcp__DAST-Orch__get_create_field_guidance` first to discover required fields for the project/issue-type pair) and a plain `git checkout -b <branch> origin/<base>`.
2. **Working tree must be clean** before the branch switch. Don't fold the user's WIP into a fresh feature branch.
3. **Description must be non-technical.** No file paths, function names, frameworks, or implementation choices. If the user gives technical input, reframe it into user-facing outcomes before drafting.
4. **Show the draft before creating.** The user must approve summary + description + branch name in one preview before any external state changes.
5. **Stop after creation.** Do not chain into `/g-brainstorm`. Tell the user the next command and exit.
6. **Don't invent scope.** If the user's input is genuinely too vague to write a meaningful summary, ask one targeted question — don't pad with assumptions.
7. **Don't guess Jira field values.** Required option-backed fields (components, scrum team, etc.) vary per project. Call `get_create_field_guidance` for the target project + issue type before creating, and if the user's past tickets in that project suggest more than one plausible value, ask which one fits (see the CPV2 example below).
8. **Check the assignee after creation.** Some projects/components carry a default assignee (e.g. a component lead) that silently overrides the reporter. Read the `assignee` field back from the create response; if it isn't the requesting user, automatically reassign to the requesting user — do not ask first. This is a correction of a known component default, not a judgment call, so no prompt is needed.

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

### 2. Draft the Jira ticket

Build the draft in this shape:

```
Type:     <feat|fix|chore|docs|refactor|test|style|perf|ci|build>
Summary:  <one line, ≤80 chars, user-facing, no jargon, no Jira ID prefix>
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

Format: `<type>/<short-kebab-summary>-<PROJECT-XXXX>`

- Use the type from step 1.
- Kebab-case the summary, ≤40 chars total in the description segment.
- `<PROJECT-XXXX>` is the Jira project key (e.g. `AICE`, `CPV2`) — leave the numeric part as a literal `XXXX` placeholder in the preview; it's filled in once the ticket is created in step 5.

Example: `feat/upvote-blockers-board-AICE-XXXX`, `chore/cpclient-ai-readiness-CPV2-XXXX`

### 4. Show the preview

Print to the user:

```
Proposed Jira ticket
====================
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

### 5. Create the ticket (DAST-Orch) and branch (git)

Once the user approves:

1. **Discover required fields** — call `mcp__DAST-Orch__get_create_field_guidance` with the target `projectKey` and `issueType` (`includeOptionalFields: true`). Do not guess option-backed fields (components, scrum team, etc.) — resolve them from guidance + the disambiguation step below.
2. **Disambiguate option-backed fields against the user's history.** If a required field has multiple plausible values (e.g. a project uses different Component/Scrum-Team pairings for different kinds of work), search the user's recent tickets in that project with `mcp__DAST-Orch__jira_search_issues` (filter by `reporter`, `fields: ["summary","components","scrumTeam","issuetype"]`) and ask the user which pairing fits this ticket. See the CPV2 reference below for a concrete example.
3. **Create the issue** with `mcp__DAST-Orch__jira_create_issue` (`projectKey`, `issueType`, `summary`, `description` in Markdown, plus whatever required fields step 1–2 resolved).
4. **Check the assignee** in the create response. If it isn't the requesting user (some components carry a default assignee), automatically call `mcp__DAST-Orch__jira_update_issue` with `assignee: <user's email>` — no need to ask first, just do it and mention it happened in the handoff.
5. **Create the branch** with plain git, based on the integration branch confirmed in preflight — not the current HEAD if that wasn't the base:
   ```
   git checkout -b <type>/<kebab-summary>-<PROJECT-NNNN> origin/<base>
   ```
   Use the real ticket number now that the issue exists (from step 3's response).

Capture the resulting ticket key/URL and the actual branch name for the handoff message.

If ticket creation fails: stop, surface the error verbatim, do not retry blindly. If the branch checkout fails (e.g. dirty tree materialized after preflight), stop and surface it — do not force-checkout over uncommitted work.

#### Reference: CPV2 / cpclient project specifics

Learned from creating CPV2-15589 ("Raise cpclient's AI-agent readiness score…"):

- **Required fields for CPV2 `Task`**: `components` (option-backed) and `scrumTeam` (option-backed, 429 values org-wide) — both must come from `get_create_field_guidance`, not guessed.
- **Component/Scrum-Team pairing depends on scope**, based on the reporter's (alexander_gusman@intuit.com) past CPV2 tickets:
  - `cpclient` component + `team-decepticons` scrum team — for cpclient-**codebase** tasks (e.g. CPV2-15355 "Fix playwright issues", CPV2-15497 an E2E-red bug).
  - `Counterpart Portal` component + `Counterpart Portal` scrum team — for broader CP **product**-level work (e.g. CPV2-15484 "Cluster-Aware Maintenance Page", CPV2-15266 an HPA scaling investigation).
  - When the ticket is ambiguous between "codebase tooling/config" and "product feature", ask the user which pairing applies — don't default silently.
- **Assignee gotcha**: creating a CPV2 issue with `components: ["Counterpart Portal"]` auto-assigned the ticket to a component-default assignee ("Ido Podhajcer"), not the reporter. The `cpclient` component has the same issue (auto-assigned CPV2-15899 to "Arjun Garg"). Always check and auto-reassign to the reporter per Iron Rule 8 — no need to ask.

### 5.5. Tag a gs-managed session (best-effort, non-blocking)

If the current working directory is inside a `.gs-worktrees/<session-name>/` path
(i.e. this run was started from a session created by `gs-cr`), tag that session
with the new Jira id:

    gs-jira <session-name> <AICE-XXXX>

- Extract `<session-name>` as the path segment immediately following `.gs-worktrees/`
  in the current working directory.
- If the current directory is NOT inside a `.gs-worktrees/` path, skip this step
  entirely — do not print an error, do not attempt to guess a session name from
  the branch. This is the common case (most `/g-prepare` runs happen from the
  main checkout before any session exists) and is not a failure.
- If `gs-jira` exits non-zero (e.g. no matching session found), print its stderr
  as an FYI note but do NOT stop the skill or block handoff to step 6. Jira/branch
  creation already succeeded; session tagging is a bonus, not a precondition.

### 6. Stop and hand off

Print:

```
Created Jira AICE-XXXX  →  <jira-url>
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
| 2 | Draft non-technical Jira ticket | No |
| 3 | Draft branch name | No |
| 4 | Show preview, accept edits | No |
| 5 | DAST-Orch `jira_create_issue` + git branch | If error, yes |
| 5.5 | Best-effort `gs-jira` tag if inside a gs-cr worktree | No |
| 6 | Print handoff message | **Always yes** |

## Rationalization table

| Excuse | Reality |
|--------|---------|
| "User gave me an implementation detail, I'll just include it." | No — reframe to user-facing language. Implementation belongs in the spec, not the ticket. |
| "The description is short, I'll pad it with how-we-might-build-it." | Don't. Padding makes the ticket look complete when scope is actually unclear. Ask one question instead. |
| "The user is in a hurry, I'll skip the preview." | Always preview. External state changes (Jira, remote branch) are hard to undo. |
| "I'll create the Jira issue without checking field guidance first." | Don't guess option-backed fields (components, scrum team). Call `get_create_field_guidance` — wrong values either fail the create or land in the wrong team's queue. |
| "The create response shows a weird assignee, I'll leave it." | Check it. Component defaults silently override the reporter — auto-reassign to the requesting user, no need to ask. |
| "Working tree has unrelated WIP, I'll just switch anyway." | The user's WIP gets stranded. Tell them to commit/stash first. |
| "Current branch looks like an integration branch, I'll fork off it directly." | If it's not actually `master`/`main` (e.g. a stale release-fix branch), branch off `origin/<base>` explicitly instead of the current HEAD. |
| "The user already mentioned `/g-brainstorm` next, I'll just start it." | Stop after creation. Each `/g-` step is a deliberate user-initiated boundary. |
| "User keeps editing the draft — I'll just pick the best version and proceed." | Three rounds of edits = unclear scope. Surface that and let the user re-think, not steamroll. |

## Red flags — STOP and reset

- About to invoke an `intuit-closed-loop` skill — it does not exist in this environment; use DAST-Orch + git instead.
- About to create a Jira issue with a guessed value for an option-backed field instead of calling `get_create_field_guidance`.
- About to include code/file/framework names in the Jira description.
- About to skip the preview step.
- About to chain into `/g-brainstorm` automatically.
- About to create a ticket from a one-word description without asking a clarifying question.
- About to stash or move the user's uncommitted work.
- About to leave a ticket assigned to an unexpected default assignee instead of auto-reassigning to the requesting user.

## Common mistakes

- **Front-loading implementation in the description.** The Jira ticket is read by PMs, leads, and future you 6 months later. Keep it about outcome.
- **Branch name too long.** Kebab segment ≤40 chars; the full `<type>/<desc>-AICE-XXXX` should fit comfortably under 60. Long branch names break tooling and look ugly in PR titles.
- **Skipping the type prompt.** "feat" vs "fix" matters — it shapes the eventual conventional-commit type and the PR title `/g-execute-plan` will produce.
- **Creating the ticket before the user approves the draft.** Jira tickets are visible to others the moment they exist. Preview first.
- **Continuing into spec-writing.** This skill ends at "Created branch." The user runs `/g-brainstorm` themselves.
