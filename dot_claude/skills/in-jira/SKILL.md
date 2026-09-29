---
name: in-jira
description: Use when a `/g-` workflow (or anything else) needs to create a Jira ticket, transition ticket state, or resolve/format a Jira ID — the Intuit-specific ticket-tracking backend behind the generic g-prepare / g-execute-plan workflow. Owns all Jira MCP calls (currently the "claude.ai Atlassian" connector) and Intuit's project/field/scrum-team conventions.
---

# in-jira — Jira operations via the claude.ai Atlassian MCP connector

Intuit's ticket tracker is Jira, reached through the **"claude.ai Atlassian" MCP
connector** (`mcp__claude_ai_Atlassian__*` tools), backed by
`https://intuit-prod.atlassian.net`. This skill is the single place that calls
those tools so generic workflow skills (`g-prepare`, `g-execute-plan`) never
hardcode Jira directly — they call into this skill's operations instead.

**As of 2026-09, this is a per-session claude.ai connector, not a DAST-Orch
tool.** Earlier revisions of this skill assumed Jira was reached through
DAST-Orch (`mcp__DAST-Orch__jira_*` / `get_create_field_guidance` /
`transition_issue`, etc.) — those tool names do **not** exist in this
environment; DAST-Orch (when connected) only exposes Splunk/Wavefront
observability tools, not Jira. If a future environment restores Jira access via
DAST-Orch or another connector, update this skill's tool names accordingly —
don't assume the DAST-Orch names below are still current without checking
`ToolSearch` first.

**Authenticating the connector**: `mcp__claude_ai_Atlassian__authenticate` only
prints an instruction — it does NOT start browser OAuth itself in this harness.
The working flow is: tell the user to run `/mcp`, select **"claude.ai
Atlassian"** from the list (not just open/dismiss the dialog), and complete the
OAuth prompt that appears. Confirm success by re-running `ToolSearch` for
`mcp__claude_ai_Atlassian__*` — a fresh set of real tool names (getJiraIssue,
createJiraIssue, etc.) appearing means auth landed. Being logged into Atlassian
in claude.ai's own web settings does **not** carry over to this CLI session —
it needs its own `/mcp` authorization pass.

There is no `intuit-closed-loop` skill in this environment (removed by the
user — do not reference it, invoke it, or assume it exists).

## Resolving `cloudId`

Every `mcp__claude_ai_Atlassian__*` call needs a `cloudId`. Get it once per
session with `mcp__claude_ai_Atlassian__getAccessibleAtlassianResources` (no
params) — for Intuit this returns `f8519793-3215-4b8b-9f9a-3c66dd15afc5`
(`intuit-prod.atlassian.net`) twice, once per OAuth scope grant (Confluence
read/write, Jira read/write) — same id both times, harmless duplication. Reuse
that id for the rest of the session rather than re-resolving per call.

## Operations

### create-ticket

Given: `projectKey`, `issueType`, `summary`, `description` (Markdown).

1. Call `mcp__claude_ai_Atlassian__getJiraProjectIssueTypesMetadata`
   (`cloudId`, `projectIdOrKey`) to resolve the issue type **id** matching
   `issueType`'s name (e.g. "Task" → id `10071` for CPV2) — `createJiraIssue`
   takes `issueTypeName` directly, but you need the id for the next step. Note:
   this connector doesn't have a "chore" issue type — map `chore` → **Task**.
2. Call `mcp__claude_ai_Atlassian__getJiraIssueTypeMetaWithFields` (`cloudId`,
   `projectIdOrKey`, `issueTypeId`, `requiredFieldsOnly: true`) to find
   required option-backed fields (components, scrum team, etc.). Do not guess
   these values. **This call's output is large (100K+ chars) and gets saved to
   a tool-results file instead of returned inline** — grep that file for
   `"required": true` to find the field block boundaries, then `Read` just
   those line ranges rather than the whole file; don't try to read it in one
   shot.
3. **Disambiguate option-backed fields against the user's history** if more
   than one pairing is plausible — see the project-specifics reference below
   for the CPV2 worked example (component + scrum team pairing depends on
   whether the ticket is codebase/tooling work vs. product-level work). Ask
   the user which pairing fits when ambiguous — don't default silently.
4. Call `mcp__claude_ai_Atlassian__createJiraIssue` with `cloudId`,
   `projectKey`, `issueTypeName`, `summary`, `description`, and
   `additional_fields` for anything option-backed (e.g.
   `{"components": [{"id": "38356"}], "customfield_10143": {"id": "14530"}}` —
   pass option **ids**, not names, once resolved from step 2's metadata).
5. **Check the assignee** in the create response. Some components carry a
   default assignee that silently overrides the reporter (confirmed
   repeatedly on CPV2's `cpclient` and `Counterpart Portal` components — see
   the reference section). If the assignee isn't the requesting user, call
   `mcp__claude_ai_Atlassian__editJiraIssue` with
   `fields: {"assignee": {"accountId": "<user's accountId>"}}` immediately —
   no need to ask first, this is a correction of a known default, not a
   judgment call. Resolve the accountId once via
   `mcp__claude_ai_Atlassian__lookupJiraAccountId` (`cloudId`, `searchString`)
   or from a prior `getJiraIssue`/`createJiraIssue` response on that user, and
   reuse it — don't re-look-it-up every ticket.
6. **Linking dependent tickets**: use
   `mcp__claude_ai_Atlassian__createIssueLink` with `type: "Depends On"`
   (id `10041` for CPV2's project; call
   `mcp__claude_ai_Atlassian__getIssueLinkTypes` once per project if unsure of
   the exact id/name). For "A depends on B": `inwardIssue: B`,
   `outwardIssue: A` (the tool's own inward/outward semantics are
   counter-intuitive — it documents inward as "the issue that blocks" for
   Blocks-type links, so double-check with `getIssueLinkTypes`'s
   `inward`/`outward` label text for the specific link type before calling).
7. Return the ticket key and URL (`webUrl` in the response).

If creation fails: surface the error verbatim, do not retry blindly.

### transition-to-in-progress

Given: `ticketId`.

1. `mcp__claude_ai_Atlassian__getTransitionsForJiraIssue` then
   `mcp__claude_ai_Atlassian__transitionJiraIssue` to "In Progress". Already in
   progress → no-op, continue.
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

`cloudId` for CPV2 (and every other Intuit project on `intuit-prod.atlassian.net`):
`f8519793-3215-4b8b-9f9a-3c66dd15afc5`.

Learned from creating CPV2-15589 ("Raise cpclient's AI-agent readiness score…")
and reconfirmed creating CPV2-16656/CPV2-16657 (splunk-obs-as-code migration
tickets, 2026-09-25) via the claude.ai Atlassian connector. Worked example for
the disambiguation step in `create-ticket`.

- **Required fields for CPV2 `Task`** (issue type id `10071`): `components`
  (field key `components`, option-backed) and Scrum Team (field key
  `customfield_10143`, option-backed, ~429 values org-wide) — both resolved
  from `getJiraIssueTypeMetaWithFields`, never guessed. CPV2 has no "chore"
  type — `Task` is the closest fit and is what `/g-prepare`'s `chore` type
  should map to for this project.
- **Component/Scrum-Team pairing depends on scope**, based on the reporter's
  (alexander_gusman@intuit.com) past CPV2 tickets:
  - `cpclient` component (id `38356`) + `team-decepticons` scrum team (option
    id `14530`) — for cpclient **codebase/tooling** tasks (e.g. CPV2-15355
    "Fix playwright issues", CPV2-15497 an E2E-red bug, CPV2-16656/CPV2-16657
    the splunk-obs-as-code repo automation work).
  - `Counterpart Portal` component + `Counterpart Portal` scrum team — for
    broader CP **product**-level work (e.g. CPV2-15484 "Cluster-Aware
    Maintenance Page", CPV2-15266 an HPA scaling investigation).
  - When ambiguous between "codebase tooling/config" and "product feature",
    ask the user which pairing applies — don't default silently.
- **Assignee gotcha, confirmed twice more**: creating a CPV2 issue with
  `components: [{"id": "38356"}]` (cpclient) auto-assigned to a
  component-default assignee (seen: Arjun Garg) on **both** CPV2-16656 and
  CPV2-16657, not the reporter; the `Counterpart Portal` component has the
  same issue. This is not a one-off — always check `assignee` in the create
  response for this project and auto-reassign per the `create-ticket` step
  above; treat it as the default outcome to correct, not an edge case.
- **Link type for ticket dependencies**: "Depends On" is link type id `10041`
  in this project (`inward: "is depended on"`, `outward: "depends on"`). For
  "B depends on A" (A must finish first): call `createIssueLink` with
  `inwardIssue: A`, `outwardIssue: B`, `type: "Depends On"`.

## Red flags — STOP and reset

- About to invoke an `intuit-closed-loop` skill — it does not exist.
- About to call any `mcp__DAST-Orch__jira_*` or `get_create_field_guidance`
  tool name — those don't exist in this environment; Jira goes through
  `mcp__claude_ai_Atlassian__*` instead (see top of this file). If DAST-Orch
  Jira tools ever do appear in a `ToolSearch`, the environment has changed —
  update this skill rather than assuming the names below are stale.
- About to create a Jira issue with a guessed value for an option-backed field
  instead of calling `getJiraIssueTypeMetaWithFields`.
- About to leave a ticket assigned to an unexpected default assignee instead of
  auto-reassigning to the requesting user — expect this to happen on CPV2
  `cpclient`/`Counterpart Portal` components specifically, not just as a
  hypothetical.
- About to retrigger the JIRA PMC check before confirming the ticket state is
  actually correct.
- About to call `mcp__claude_ai_Atlassian__authenticate` expecting it to start
  OAuth directly — it only tells the user to run `/mcp` themselves; direct the
  user there instead of retrying the tool call.
