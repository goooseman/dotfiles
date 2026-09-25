---
name: in-weekly-update
description: Use when the user runs /in-weekly-update or asks for their weekly summary/update for their manager (typically Friday). Optional argument is an ISO week like 2026-W28; defaults to the current week.
---

# Weekly Update

Produce a **reflection** — not a bullet list — connecting the week's work to the user's tech-lead role and the Intuit engineering craft pillars, then copy it to the clipboard for the user to paste to their manager.

The manager explicitly asked for this shape (2026-08-14): reflection on how the week's progress connects to the tech-lead role and the staff-engineer tech pillars, instead of bullet points.

## Sources of truth — read BOTH

1. **The weekly note** — `intuit/weekly/<ISO-week>.md`. Current week via `date +%G-W%V` (never `%Y-%V`), or the week given as argument. The `## achievements` bullets are the **spine**: what the user considered worth recording.
2. **This week's daily notes** — `intuit/daily/` in the same vault. These supply the *reasoning and judgment* the weekly note compresses away, and they routinely contain **work that never made it into `## achievements` at all** (e.g. 2026-W33's CPV2-16000 F1T work). Include net-new items; don't limit yourself to enriching what's already listed.

Selecting this week's daily notes — do both, they disagree:
- filename prefix in range: `ls 2026MMDD*.md` for Mon–Fri of the target week
- modified in range: `find . -maxdepth 1 -name "*.md" -newermt "<Monday> 00:00"`

A note whose *filename* predates the week but was *edited* during it is usually prior-week context, not this week's work — read it, then judge. Say which notes you used.

Note missing or `## achievements` empty → tell the user exactly which note you looked for and stop. Offer the matching section of the legacy `intuit/weekly-achievements.md` only as an explicit fallback. **Never silently summarize a different week than requested.**

## The pillars

Four **Engineering Craft Skill** areas (source: `intuit/daily/20260709-fy2026-yes-form.md`, which cites the [Engineering Craft Skills Rubric](https://sites.intuit.com/home/engineering-craftskills) and the Staff Rubric Template):

- **Technical Craft** — architecture and design judgment; the decisions, especially directional ones
- **Execution Excellence** — delivery rigor, verification method, operational discipline
- **Customer-centric Outcomes** — customer/user impact, measurement, protecting signal
- **Accelerating Teams** — mentoring, design consults, cross-team findings, unblocking others

> [!important] Never pad to hit four
> Include a pillar **only when the week produced something substantive under it.** Three is normal; two is fine. Forcing all four turns the reflection into a checklist and dilutes the real work — the user rejected exactly this (2026-08-14, on a thin "Execution Excellence" entry that was really a Technical Craft detail).
>
> If a small-but-real item is the only candidate for a pillar, fold it into the pillar it actually serves rather than giving it its own header.

Related work belongs in **one thread across pillars**, not as disconnected mentions — e.g. AppFabric Next: the flag design under Technical Craft, the perf measurement and reviewer response under Customer-centric Outcomes. Name it as an accomplishment in its own right (the user caught it being referenced twice without ever being credited as shipped).

## Altitude — the hardest part to get right

Write for a manager who wants to know **what was accomplished and what judgment it took**, not the commit path.

| Include | Exclude |
|---|---|
| The problem, in one clause of plain context | Blow-by-blow PR sequencing ("one PR merged, then a fix merged") |
| The decision and *why* — especially tradeoffs and failure-mode reasoning | Intermediate bugs the user introduced and fixed before merge |
| Outcome and current state ("in, flag-gated, inert until X") | PR links and PR numbers — Jira keys only |
| Hard numbers (36–46 ms, ~68%, 110 companies, zero errors) | Function/file names, code identifiers, iteration counts |
| Cross-team impact and who was involved by name | Internal-only detail a manager can't act on |

**Every pillar paragraph must open with enough context to stand alone.** Do not lead with a conclusion about the work before naming the work — "the real decisions were directional, not cryptographic" is meaningless before the reader knows LMA is about rejecting unsigned gateway traffic. State problem → decision → outcome.

Compress hard. If a sentence survives only because it's true, cut it.

## Output contract

1. `*Weekly reflection — <Mon DD> – <Fri DD> (<ISO-week>)*`
2. One TL;DR sentence: the week's biggest outcome(s) plus the framing thought.
3. One short paragraph per earned pillar, `*Pillar Name*` bold-prefixed, em-dash, then prose.
4. `*Next week*` — forward-looking close. What state the work is actually in and what closing the gap means (release, verify, enable flags, escalate). Include leave/vacation or availability if the user mentions it.

Reflection prose in first person. No bullet lists. Keep metric phrases verbatim.

**Formatting/links: defer to the `copy-slack` skill.** It is the authority for paste formatting: Slack-native `*bold*` / `_italic_` / `` `code` `` (never `**bold**`), and **links as `[text](url)`** — Jira keys become `[KEY](https://jira.intuit.com/browse/KEY)`. Never `<url|text>`. Nested emphasis collides with the bold pillar headers, so use `_italic_` for in-paragraph emphasis.

## CLI syntax (critical)

The `obsidian` CLI takes **`key=value` arguments only**: `obsidian read path="intuit/weekly/2026-W29.md"`. Flags like `--vault` and positional paths are **silently ignored** — the CLI then returns the note currently open in the Obsidian app, with exit code 0. After every read, sanity-check that the content contains the `# week <ISO-week>` heading; if it doesn't, your command was malformed — fix the syntax, don't reason about the wrong note's content.

**If the CLI reports "unable to find Obsidian"** (app not running), read the vault directly from disk at `/Users/agusman/Obsidian/goooseman-secrets`. That is the live vault — an iCloud path of the same name also exists and is **stale**; verify by checking that `intuit/weekly/` contains the current week.

## Steps

1. Resolve the week; read the weekly note; sanity-check the heading. Take `## achievements` (strip leading `YYYY-MM-DD — ` stamps — bookkeeping, not manager content).
2. List and read this week's `intuit/daily/` notes. Extract judgment, decisions, numbers, people, cross-team findings, and any work absent from the weekly note.
3. Map material to pillars. Drop pillars the week didn't earn. Merge related work into single threads.
4. Draft per the contract and altitude table. Show the full text in chat.
5. Copy via `copy-slack`. Verify with `pbpaste | head -5` and a link-format spot check.
6. Flag to the user: any work pulled from daily notes that is **missing from `## achievements`** (they may want the weekly note to stay canonical).
7. Bookkeeping: append `- sent YYYY-MM-DD` under a `## sent` section in the weekly note (`obsidian append`; add the section if missing).

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Bullet-point summary | Manager asked for reflection prose tied to role + pillars |
| Forcing all four pillars | Include only earned pillars; fold thin items into the pillar they serve |
| Reading only the weekly note | Daily notes carry the judgment *and* unrecorded work |
| Opening a pillar with a conclusion before naming the work | Problem → decision → outcome, in that order |
| Narrating intermediate bugs or PR sequencing | Outcome + judgment only; no "then another fix merged" |
| PR links in the text | Jira keys only |
| Promo-packet length | Compress hard; the user pushed back on length repeatedly |
| `**bold**`, or `<url\|text>` links | Slack `*bold*`; links `[text](url)` — per `copy-slack` |
| `obsidian read --vault X "path"` (flag/positional form) | Silently returns the app's open note — use `path="..."` and verify the `# week` heading |
| Reading the iCloud vault copy | Live vault is `/Users/agusman/Obsidian/goooseman-secrets` |
| Summarizing last week when this week is empty, without saying so | Name the missing note; ask before falling back |
| Dropping short metric bullets ("2 A4A, 1 TPI") | Keep them — the manager tracks these |
| No verification | `pbpaste | head -5` after copying |
| Forgetting the sent marker | `- sent YYYY-MM-DD` under `## sent` |
