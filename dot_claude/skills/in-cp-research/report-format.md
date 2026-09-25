# cpclient incident / root-cause report format

Save to the Obsidian vault (`~/Obsidian/goooseman-secrets` — the active vault) at `intuit/daily/YYYYMMDD-kebab-title.md`. Create via obsidian-cli (`/usr/local/bin/obsidian`) `create path=... content=...` (escape newlines as `\n`), or write the file directly. Filename convention in that folder: `YYYYMMDD-kebab-title.md`, no YAML frontmatter.

Vault conventions:
- **Line 1:** space-separated `[[wikilinks]]` — concept links + project index. For cpclient use `[[intuit/indexes/cpclient]]` (NOT embedded-checkout). e.g. `[[wavefront]] [[iks]] [[hpa]] [[intuit/indexes/intuit-projects]] [[intuit/indexes/cpclient]]`
- **Line 3:** inline `#tags` — e.g. `#intuit/cpclient #observability #wavefront #iks #hpa #autoscaling #incident`
- Then `# Title`, a "Related project indexes:" line, and a context blockquote naming tools + cluster/index + "All times PT; PDT = UTC−7".

## Structure (in order)

### 1. 🔴 TL;DR for the team — one per event (the shareable part)

Header per event: `## 🔴 TL;DR for the team — Event A (~HH:MM PT) root cause (5-Whys) + fixes`. Order events chronologically.

Each block:
- **Root-cause blockquote** (`> **Event X = …**`): what scaled/broke, the one-sentence bottom line, customer impact, root issue. Plain enough for a non-oncall teammate.
- **5-Whys tree** — a top `**Why did X happen?**` line, then nested `- **Why…?**` bullets (indent each level 2 spaces) drilling into sub-causes. Cover different aspects (the metric, the workload, the autoscaler, the trigger), not necessarily exactly 5.
  - **Inline the evidence in each bullet:** the concrete numbers AND a clickable deep-link, e.g. `variationRemote 81K→**129K**/min … [Splunk: work surge by minute](<deep-link>)`. Bold the money numbers.
  - Attach `*Remediation:*` sub-bullets under the why they fix (keep them in the why section — the team wants fix-next-to-cause). Include codebase file:line where relevant.
- **"What it was NOT"** line — the ruled-out alternatives with the one-line evidence each (deploy? traffic? GC? bot? artifact?) + their links. Retract any earlier wrong lead here explicitly.
- **Net fix** line — the 2–3 highest-leverage changes, linking the Jira ticket.
- If multiple events, a one-line **"Events A vs B"** comparison.

### 2. Full analysis
Per-event detail: evidence tables (min/avg/max, per-minute trajectories), the mechanism chain, an eliminations table (candidate | finding | verdict).

### 3. Remediation (both events)
Consolidated list, grouped (workload trigger vs autoscaler amplifier). Cite codebase paths and current state (e.g. "no cache exists today at `SalesCheckoutService.ts:164`"). Back metric/config changes **empirically** (your data + prod precedents), and be precise about what platform docs actually say vs. don't.

### 4. Dashboards / query reference / field reference
- Incident-time Wavefront dashboard links.
- **Query reference** grouped per event: each finding = the full SPL/`ts()` query in a code block + a clickable deep-link + explicit `earliest/latest` epochs (so it survives link rot) + the result summary.
- **Field reference** for future queries (the `event`/`logType`/`rum.executionTimeMs`/`network.intuitTid` cp-s/cp-c facts).
- References (DevPortal doc links, support channels).

## Building deep-links (link-rot-proof)

**Splunk** — URL-encode the SPL (prefix `search `) and pin epochs:
```python
from urllib.parse import quote
base='https://sbg.splunk.intuit.com/en-US/app/search/search'
tail='&display.page.search.mode=verbose&dispatch.sample_ratio=1&display.page.search.tab=visualizations&display.general.type=visualizations'
link = base+'?q='+quote('search '+spl)+tail+f'&earliest={epoch_start}&latest={epoch_end}'
```
Always keep the raw SPL + epochs visible in the reference section too — if the link rots, the reader pastes the query and sets the window.

**Wavefront** — link the incident dashboard (`https://intuit.wavefront.com/u/<id>?t=intuit`) or a dashboard the user provides; alongside it, write the `ts()` query + region + `end_epoch`/`lookback` as text (MCP queries have no shareable URL).

## Tone
- Lead with the answer; make the TL;DR self-contained for someone who won't read the rest.
- Evidence-backed, honest about confidence and about retractions. Distinguish "proven by data" from "strongly inferred."
- Preserve any human edits already in the note (e.g. `#gbrain-edited` tag, added index links) when updating.
