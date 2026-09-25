---
name: in-jira
description: Use when a `/g-` workflow (or anything else) needs to create a Jira ticket, transition ticket state, or resolve/format a Jira ID — the Intuit-specific ticket-tracking backend behind the generic g-prepare / g-execute-plan workflow. Owns all DAST-Orch Jira MCP calls and Intuit's project/field/scrum-team conventions.
---

# in-jira — Jira operations via DAST-Orch

Intuit's ticket tracker is Jira, reached through the **DAST-Orch MCP tools**. This
skill is the single place that calls those tools so generic workflow skills
(`g-prepare`, `g-execute-plan`) never hardcode Jira or DAST-Orch directly — they
call into this skill's operations instead.

There is no `intuit-closed-loop` skill in this environment (removed by the
user — do not reference it, invoke it, or assume it exists).

## Operations

### create-ticket

Given: `projectKey`, `issueType`, `summary`, `description` (Markdown).

1. Call `mcp__DAST-Orch__get_create_field_guidance` (`projectKey`, `issueType`,
   `includeOptionalFields: true`). Do not guess option-backed fields (components,
   scrum team, etc.).
2. **Disambiguate option-backed fields against the user's history** if more than
   one pairing is plausible: search recent tickets with
   `mcp__DAST-Orch__jira_search_issues` (filter `reporter`,
   `fields: ["summary","components","scrumTeam","issuetype"]`) and ask the user
   which pairing fits. See the project-specifics reference below for a worked
   example (CPV2).
3. Call `mcp__DAST-Orch__jira_create_issue` with the resolved fields.
4. **Check the assignee** in the create response. Some components carry a
   default assignee that silently overrides the reporter. If the assignee isn't
   the requesting user, call `mcp__DAST-Orch__jira_update_issue` with
   `assignee: <user's email>` immediately — no need to ask first, this is a
   correction of a known default, not a judgment call.
5. Return the ticket key and URL.

If creation fails: surface the error verbatim, do not retry blindly.

### transition-to-in-progress

Given: `ticketId`.

1. `mcp__DAST-Orch__get_available_transitions` then `mcp__DAST-Orch__transition_issue`
   to "In Progress". Already in progress → no-op, continue.
2. **Verify the transition actually landed** — read `status`/`statusCategory`
   back (transition response or a follow-up read) and confirm "In Progress"
   before returning success. A transition call can report success while the
   issue is left in a state a downstream gate doesn't recognize.

If the call fails: stop and surface the error — don't proceed PR-first.

**"JIRA PMC check" failing on "ticket is To Do, not In Progress"**: this PR
check reads Jira state at the time it last ran, not live at PR-open time — if
the transition happened after the check's last run (or raced it), the check
can report stale state even though the ticket is now correctly "In Progress".
Fix order:
1. Confirm the ticket is actually "In Progress" per the verification step
   above. Don't retrigger the check before this is true.
2. Retrigger with a double PR-title rename:
   `gh pr edit <N> --title "<anything-else>"` then immediately
   `gh pr edit <N> --title "<original-title>"`. The rename-back must restore
   the exact original title — this forces the check to re-run against
   current state, it isn't cosmetic.
3. `gh pr checks <N>` (allow a few seconds) and confirm the check is green.

### ticket-id-format

Jira IDs match `[A-Z][A-Z0-9]+-[0-9]+` (e.g. `CPV2-15484`, `AICE-2123`).

- **Resolving one**: check the branch name, spec header, or recent commit
  messages for this pattern.
- **Formatting one into a PR title**: uppercase, no brackets, single space
  before it, at the end of the title.
- **Formatting one into a branch name**: append as `-<PROJECT-XXXX>` after the
  kebab-case summary, e.g. `feat/upvote-blockers-board-AICE-2123`.

## Reference: CPV2 / cpclient project specifics

Learned from creating CPV2-15589 ("Raise cpclient's AI-agent readiness score…").
Worked example for the disambiguation step in `create-ticket`.

- **Required fields for CPV2 `Task`**: `components` (option-backed) and
  `scrumTeam` (option-backed, 429 values org-wide) — both come from
  `get_create_field_guidance`, never guessed.
- **Component/Scrum-Team pairing depends on scope**, based on the reporter's
  (alexander_gusman@intuit.com) past CPV2 tickets:
  - `cpclient` component + `team-decepticons` scrum team — for cpclient
    **codebase** tasks (e.g. CPV2-15355 "Fix playwright issues", CPV2-15497 an
    E2E-red bug).
  - `Counterpart Portal` component + `Counterpart Portal` scrum team — for
    broader CP **product**-level work (e.g. CPV2-15484 "Cluster-Aware
    Maintenance Page", CPV2-15266 an HPA scaling investigation).
  - When ambiguous between "codebase tooling/config" and "product feature",
    ask the user which pairing applies — don't default silently.
- **Assignee gotcha**: creating a CPV2 issue with
  `components: ["Counterpart Portal"]` auto-assigned to a component-default
  assignee, not the reporter; the `cpclient` component has the same issue.
  Always check and auto-reassign per the `create-ticket` step above.

## Red flags — STOP and reset

- About to invoke an `intuit-closed-loop` skill — it does not exist; use
  DAST-Orch directly.
- About to create a Jira issue with a guessed value for an option-backed field
  instead of calling `get_create_field_guidance`.
- About to leave a ticket assigned to an unexpected default assignee instead of
  auto-reassigning to the requesting user.
- About to retrigger the JIRA PMC check before confirming the ticket state is
  actually correct.
