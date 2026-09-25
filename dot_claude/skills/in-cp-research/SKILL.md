---
name: in-cp-research
description: Use when investigating cpclient (Counterpart Portal, "cp-client", Checkout Portal) production/prod behavior via Wavefront metrics or Splunk logs at Intuit — pod scaling/HPA spikes, CPU, latency, errors, feature-flag load, batch payments — or when writing up a cpclient incident/root-cause report. Covers exact Splunk cluster/index/fields, Wavefront metric names, the O11Y Wavefront MCP + DAST-Orch Splunk tools and their quirks, and the report format.
---

# cpclient observability research (Wavefront + Splunk)

Playbook for investigating **cpclient** (Counterpart Portal; service `cp-client`; asset alias `Intuit.spi.icn_client.2`; asset id `6992981913707265771`) in prod via the **O11Y Wavefront MCP** and **Splunk**, both routed through **DAST-Orch** (Intuit Developer Desktop App, local `127.0.0.1:53333`). Includes the exact indexes/metrics/fields and the incident-report format.

Prod runs two regions: `sales-cpclient-usw2-prd` (west) and `sales-cpclient-use2-prd` (east), cluster `payment-prd-usw2-k8s`. **Always convert PT→UTC first** (PDT = UTC−7) and query an explicit window; pass historical windows via `end_epoch`/`earliest`+`latest`.

## Tool access (DAST-Orch)

Both are **deferred MCP tools** — load schemas with `ToolSearch("select:<name>")` before the first call or it errors. If a call returns `unauthorized (401)` / "failed to reconnect idle server", the upstream session went idle: user runs `/mcp` to reconnect, then the tool schema must be re-loaded via `ToolSearch` again.

- **Wavefront:** `mcp__DAST-Orch__query_metrics` (summary stats over a window), `mcp__DAST-Orch__query_raw` (raw points, **4h lookback cap**, recent windows only), `mcp__DAST-Orch__get_metric_detail` (sources/tags for an exact metric — use this to confirm a metric exists; `search_metrics` substring search is **broken/returns 0**, don't rely on it). Region param: `west` = intuit.wavefront.com, `east` = intuit-east.wavefront.com — pick the region matching the namespace or you get 0 series.
- **Splunk:** `mcp__DAST-Orch__prod-retrieve_events` (prod clusters) / `mcp__DAST-Orch__e2e-retrieve_events` (non-prod). Cluster **`sbg-prod`**, index **`sbg-services`**. Requires per-principal allowlist grant on the cluster (else `not_in_allow_list`). **60-minute max window** per call — split larger windows. Use `analyze_only: true` to preview cost without dispatching.

## Splunk: cpclient prod logs

Base filter: `index="sbg-services" host="cpclient-appd-rollout-*"` on cluster `sbg-prod`. Logs are structured JSON (`sourcetype=fluent`, `name="ssr"`), emitted by `reporting/Profiler.js` + `reporting/splunk/SplunkReporter.ts`.

**Key fields:**

- `event` + `action` — e.g. `event=profiling` (RUM/HTTP-client), `event=viewSale action=renderToHTML` (SSR render), `event=batchUnpaidInvoices`, `event=featureFlagsService action=variation|variationRemote`.
- `logInfo.logType` = `outbound` (HTTP-client call) / `inbound` (server received) / `contextual`.
- `logInfo.logLevel` = info/warn/error.
- **Execution time / latency: `rum.executionTimeMs`** (NOT under `network`; present on `event=profiling` logs).
- HTTP status: `network.responseCode`; target: `network.requestPath` (raw) / `network.requestPathFiltered` (token-stripped, use for grouping).
- **BE vs FE (critical — `logType=outbound` alone is NOT backend; the browser emits outbound RUM too):** `network.intuitTid` starts with **`cp-s`** = backend/server, **`cp-c`** = frontend/browser. Always filter `network.intuitTid="cp-s*"` for server-side latency. Browser events also carry `sessionInfo.deviceInfo.userAgent` (real users) — automated/bot traffic has **no** deviceInfo/userAgent.
- `applicationInfo.appImage` — deploy marker; `dc(applicationInfo.appImage)` per minute = 1 means no rollout.
- Realm is in `network.requestPath` (`companies/{realmId}/`); `sessionInfo.originatingIp` (bot check: AWS datacenter IPs = automated).

**Query gotchas:** nested-field filters (`logInfo.logType=x`) can time out on this high-volume index — narrow the window, add a selective term, or bucket to a single pod. `timechart ... by <field>` with **multiple** aggregations silently drops the agg columns and returns only counts — use one agg per `by`-split, or `stats ... by` without timechart.

See [reference.md](reference.md) for copy-paste query recipes.

## Wavefront: cpclient metrics

Filter by `namespace_name=` (heapster) or `source=`/`namespace=` (iks) + region `west`. Metric names (pod count, absolute CPU cores, CPU % all-pods/ready-only, memory %, HPA desired replicas) and copy-paste queries are in [reference.md](reference.md).

**The CPU-% churn artifact (the big one):** the all-pods `*.cpu.utilization` = `usage ÷ limit`, averaged over ALL pods incl. not-Ready ones. A starting pod's cgroup limit can read ~0 → `usage/~0` → absurd % (seen: **5180%**). It poisons the average and can drive HPA (which takes the max across metrics) to the cap. **Always confirm with absolute cores** (`heapster.pod.cpu.usage_rate`): if % explodes while total cores stay flat, it's an artifact, not load. The `ready_only` variant excludes not-Ready pods and is the safer HPA metric. (cpclient HPA `cpclient-rollout-hpa`: `minReplicas 60 / maxReplicas 305`, aggressive `scaleUp` `Percent:100/15s stabilizationWindowSeconds:0`.)

## Writing the report

Save to the Obsidian vault under `intuit/daily/YYYYMMDD-kebab-title.md` (see [report-format.md](report-format.md) for the full template). Structure:

1. **Top wikilinks + tags line**, then a one-line context blockquote (tools used, cluster/index, "All times PT; PDT = UTC−7").
2. **🔴 TL;DR for the team — 5-Whys** (one per event): a root-cause blockquote, then nested `- **Why…?**` bullets drilling down, each with **inlined stats and a clickable Wavefront/Splunk deep-link** right in the bullet, plus `*Remediation:*` sub-bullets. End with a **"What it was NOT"** eliminations line and a **Net fix** line.
3. **Full analysis**, **Remediation**, **query reference** (full SPL + epochs as link-rot fallback), **field reference**.

Build Splunk deep-links so they survive link rot — URL-encode the SPL and pin epochs:
`https://sbg.splunk.intuit.com/en-US/app/search/search?q=search%20<encoded-SPL>&display.page.search.mode=verbose&dispatch.sample_ratio=1&display.page.search.tab=visualizations&display.general.type=visualizations&earliest=<epoch>&latest=<epoch>`

## Honesty rules (learned the hard way this domain)

- **Summary stats hide spikes.** `avg`/`max` over a wide window smears the moment. Bucket per-minute (`timechart span=1m`) around the exact event, and pull raw points when you need the shape.
- **Verify field/metric names before asserting** — cpclient's logs do NOT carry latency under `network`; only `event=profiling` has `rum.executionTimeMs`. Look at one raw event (`| head 1 | fields _raw`) before aggregating on a guessed field.
- **Don't cite a doc as saying more than it does.** The IKS HPA doc (CAP-1321) _permits_ `app_cpu_utilization` and says running two CPU metrics "does not harm" — it does NOT forbid it. Justify metric changes empirically (your data + precedent), not with an invented policy.
- **Retract cleanly.** If a lead turns out contaminated (e.g. FE RUM leaking through a `logType=outbound` filter that lacked `cp-s`), state the retraction in the report rather than quietly dropping it.

## Common mistakes

- Filtering `logType=outbound` without `network.intuitTid="cp-s*"` → FE browser RUM contaminates "backend latency" (inflated by client network/CPU).
- Reading CPU **%** during a scale event and calling it real load → it's the denominator artifact; read cores.
- Wrong region (`west`/`east`) → 0 series with no error.
- One 60-min+ Splunk call → window-exceeded; split it. Idle 401 → `/mcp` reconnect + re-`ToolSearch`.
- Getting PT/UTC wrong → you analyze the wrong window (verify epochs with `date`).
