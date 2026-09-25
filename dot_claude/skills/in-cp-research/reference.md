# cpclient query recipes (Splunk + Wavefront)

Copy-paste starting points. Splunk cluster `sbg-prod`, index `sbg-services`. Wavefront region `west` (use `east` for use2). Replace time windows. Epochs: get with `TZ=America/Los_Angeles date -r <epoch>` to verify PT.

## Splunk (via `mcp__DAST-Orch__prod-retrieve_events`)

Args shape: `{ spl: "<body, no leading 'search'>", earliest: "-30m"|"<ISO-UTC>", latest: "now", cluster: "sbg-prod", max_results: N }`. Max window 60 min. `analyze_only: true` previews cost.

**Connectivity smoke test:**
```spl
index="sbg-services" host="cpclient-appd-rollout-*" | head 5
```

**Error/warn/info volume by minute (spike shape + deploy check):**
```spl
index="sbg-services" host="cpclient-appd-rollout-*" | timechart span=1m count as n dc(applicationInfo.appImage) as images by logInfo.logLevel
```
`images`=1 per minute → no rollout in window.

**Top events/actions (what the fleet is doing):**
```spl
index="sbg-services" host="cpclient-appd-rollout-*" | stats count by event action | sort -count | head 30
```

**Inbound request latency + volume (is it a traffic spike?):**
```spl
index="sbg-services" host="cpclient-appd-rollout-*" event=profiling logInfo.logType=inbound | timechart span=1m avg(rum.executionTimeMs) as avg_ms perc90(rum.executionTimeMs) as p90_ms count as n
```

**BACKEND outbound HTTP latency (note the `cp-s*` filter = server-side only):**
```spl
index="sbg-services" host="cpclient-appd-rollout-*" event=profiling logInfo.logType=outbound network.intuitTid="cp-s*" | timechart span=1m avg(rum.executionTimeMs) as avg_ms perc90(rum.executionTimeMs) as p90_ms count as n
```
Without `cp-s*` you get FE browser RUM too (inflated, meaningless for server CPU).

**Slowest / heaviest outbound targets over a window (normalize token paths):**
```spl
index="sbg-services" host="cpclient-appd-rollout-*" event=profiling logInfo.logType=outbound | eval path=coalesce('network.requestPathFiltered',action) | stats count avg(rum.executionTimeMs) as avg_ms perc90(rum.executionTimeMs) as p90_ms sum(rum.executionTimeMs) as total_ms by path | sort -total_ms | head 15
```
Rank by `total_ms` (avg×count) not avg — low-volume slow calls mislead.

**Errors by response code for a downstream (e.g. batch unpaid invoices):**
```spl
index="sbg-services" host="cpclient-appd-rollout-*" logInfo.logLevel=error event=batchUnpaidInvoices | timechart span=1m count by network.responseCode
```

**Which realm is driving a flood (429s by realm):**
```spl
index="sbg-services" host="cpclient-appd-rollout-*" event=batchUnpaidInvoices "429" | rex field=network.requestPath "companies/(?<realm>\d+)/" | stats count by realm | sort -count
```

**Bot vs human fingerprint for a realm (no userAgent + datacenter IPs = bot):**
```spl
index="sbg-services" host="cpclient-appd-rollout-*" "<realmId>" | eval ua=coalesce('sessionInfo.deviceInfo.userAgent',"(none)") | stats count dc(sessionInfo.originatingIp) as ips by ua | sort -count
```
```spl
index="sbg-services" host="cpclient-appd-rollout-*" "<realmId>" sessionInfo.originatingIp=* | stats count dc(sessionInfo.sessionId) as sessions dc(sessionInfo.token) as tokens by sessionInfo.originatingIp | sort -count
```

**Inspect a raw event before trusting a field name:**
```spl
index="sbg-services" host="cpclient-appd-rollout-*" event=<x> | head 1 | fields _raw
```

## Wavefront (via `mcp__DAST-Orch__query_metrics`)

Args shape: `{ ts_query: "ts(...)", region: "west", end_epoch: <sec>, lookback_minutes: N, granularity: "m", summarization: "MAX"|"MEAN" }`. For raw points use `query_raw` (4h cap, recent only). Confirm a metric exists with `get_metric_detail`.

**Pod count (per-minute shape — use MAX, not MEAN, to catch churn):**
```
avg(align(60s, mean, ts(iks.namespace.app.pod.count, app=cpclient and namespace=sales-cpclient-usw2-prd and cluster=payment-prd-usw2-k8s)))
```

**Absolute CPU cores — total + hottest pod (the artifact-proof signal):**
```
sum(ts(heapster.pod.cpu.usage_rate, namespace_name=sales-cpclient-usw2-prd))
max(ts(heapster.pod.cpu.usage_rate, namespace_name=sales-cpclient-usw2-prd))
```

**CPU % — compare all-pods vs Ready-only (divergence = artifact):**
```
ts(iks.namespace.app.container.app.cpu.utilization, source=sales-cpclient-usw2-prd)
ts(iks.namespace.app.container.app.ready.only.avg.cpu.utilization, source=sales-cpclient-usw2-prd)
```

**HPA desired replicas (did HPA drive the scale, and off which metric):**
```
ts(custom.iks.kube.horizontalpodautoscaler.status.desired.replicas.gauge, namespace=sales-cpclient-usw2-prd)
```

**Memory % (GC-pressure correlate):**
```
ts(iks.namespace.app.pod.memory.utilization, source=sales-cpclient-usw2-prd)
```

## Interpreting CPU: real load vs artifact

1. Plot pod count + HPA desired.replicas + all-pods CPU% + ready-only CPU% + total cores, per-minute around the event.
2. If all-pods CPU% spikes huge (e.g. >200%, up to 5180%) but **total cores stay flat** → measurement artifact from not-Ready pods' bad denominator during churn. Not real load.
3. If total cores genuinely rise and ready-only% rises with it → real CPU. Then find *what* via Splunk (inbound volume? outbound latency? a work surge like feature-flag/render? a realm flood?).
4. HPA `scaleUp Percent:100 / stabilizationWindowSeconds:0` doubles the fleet per 15s tick — a brief crossing overshoots to `maxReplicas` (305), then CPU collapses as load spreads = the overshoot signature.
