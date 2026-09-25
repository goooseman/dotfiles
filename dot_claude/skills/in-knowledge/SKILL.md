---
name: intuit-knowledge
description: Use when working on Intuit-internal tools, systems, or processes and general institutional knowledge would help — accumulated learnings not specific to any single tool or service.
---

# Intuit Knowledge

Accumulated learnings about Intuit-internal tools, systems, and processes,
captured via the `learn` skill.

## Jira

- The internal Jira instance requires custom field `cf[10050]` (Asset ID
  tagging) on all new tickets in the **PLATFORM** project. Tickets created
  without it are auto-rejected by the triage bot — set it explicitly when
  creating PLATFORM issues.

## Slack

- Team CI/deploy notification channels (e.g. `#checkout-client-devops`) are
  often **private channels**, so `slack_search_channels` (public-only by
  default) returns "No results found" even when the channel exists. Pass
  `channel_types: "public_channel,private_channel"` to `slack_search_channels`,
  or go straight to `slack_search_public_and_private` with an `in:<channel-name>`
  filter, to find it. Once you have the channel ID, `slack_read_channel` on a
  private channel can still fail with `channel_not_found` (the read tool may
  not have the same access as search) — fall back to
  `slack_search_public_and_private` with `in:<channel-name>` plus a keyword,
  and `slack_read_thread` on specific message timestamps found that way.
- Jenkins/CI bot postings to these channels (e.g. Playwright test report bots)
  often show up with empty `Text` and no readable `From` name in
  `slack_read_channel`/search results — the actual content lives in the
  message's `Attachment` field, not `Text`. Always check `Attachment` for
  bot-posted CI summaries (test pass/fail/flaky counts, deploy notifications).

## Jenkins

- On the `sales-customerexp/cpclient/Playwright` job, **when testing a PR, pass
  `BASE_URL` pointing at that PR's dyn env** — it keeps load off the shared E2E
  cpclient servers and tests the actual PR build.
  **Get the URL from the PR's GitHub comments, not by constructing it.** The
  `svc-sbseg-ci` bot posts it once the env is up:
  ```
  🚀🧨 Dynamic environment is successfully deployed to
  https://sales-qal-cpclient-pr-<N>.paymentppdusw2.iks2.a.intuit.com/t/scs-v1-...
  ```
  Read it with:
  ```bash
  gh pr view <N> --repo sales-customerexp/cpclient --json comments \
    --jq '.comments[].body' | grep -i "Dynamic environment"
  ```
  Pass only the scheme+host as `BASE_URL` (drop the `/t/scs-v1-...` path).
  The comment doubles as proof the env is actually deployed — the "Service
  Previews" check is PR-scoped, so it does **not** re-report on later pushes and
  its absence does not mean the env is missing. Do not verify the host with
  `curl`/DNS from a laptop: these hosts are VPN-scoped and resolve only from
  inside the network, so a local failure tells you nothing.
  Updated 2026-08-14 by the repo owner: the older guidance below is obsolete.
  - *Superseded:* a 2026-07-24 note said never to pass `BASE_URL` because it
    caused many unrelated failures. Those issues have since been resolved. For a
    plain master/nightly run you still don't need it; for PR validation, use the
    dyn env.
  - Note `BASE_URL` only redirects **cpclient** traffic. Test-company creation
    (F1T / TestEasy / TDS → QBO) hits shared services regardless, so it does not
    remove that load.

### Triggering the cpclient Playwright suite (validated 2026-08-13)

Use the **`cicd-diagnostics-plugin:jenkins` skill's CLI**, not hand-rolled
`curl` + crumb calls — it auto-resolves credentials from the `gh` token, so no
`Jenkins-Crumb` dance is needed:

```bash
SK=~/.claude/plugins/cache/devassist-plugins-registry/cicd-diagnostics-plugin/<ver>/skills/jenkins
uv run --directory "$SK/tools/jenkins-client" jenkins-client job trigger \
  --job "sales-customerexp/cpclient/Playwright" \
  -c https://build.intuit.com/payments \
  --param TESTS_BRANCH=<branch>
```

- Controller is `payments`; job path is `sales-customerexp/cpclient/Playwright`.
- `jenkins-client job config --job <path> -c <controller>` dumps the real
  `<parameterDefinitions>` — check names there instead of trusting an old spec.
  Current params: `TESTS_BRANCH`, `ENV` (choice: `E2E`|`STG`), `BASE_URL`,
  `PLAYWRIGHT_MOCK_MODE`, `TESTS_PER_SHARD`, `SCS_PR_ID`, `IS_CHECKING_SCS`.
- **`TESTS_BRANCH` is usually the only param to set.** Playwright tests and all
  test-data/company-creation helpers live in `__tests/playwright/`, so for a
  change to the test harness, pointing `TESTS_BRANCH` at the branch is enough —
  no ephemeral env needed. An ephemeral `BASE_URL` is only for *server-side*
  changes that must be deployed to be exercised.
- **Never set `PLAYWRIGHT_MOCK_MODE=on`** when validating test-data/company
  creation — mocks bypass real downstream calls, so the run proves nothing.
- Without `--wait`, the CLI returns only `queue_item`. Resolve it to a build:
  `curl -sS -u "agusman:$(gh auth token --hostname github.intuit.com)" \
  "https://build.intuit.com/payments/queue/item/<id>/api/json"` → `.executable.number`.
- Poll `.../job/Playwright/<n>/api/json?tree=building,result` for completion.
- A green build is NOT proof the new code path ran — if a provider/fallback
  chain is involved, read the console log for which path was actually taken.
  See also: never claim a fix worked from pipeline status alone.

## sales-checkout-svc (SCS)

- `repoctl explain`'s "Protected Paths" list for this repo only covers
  `application-prd*.yml` and `bootstrap-prd*.yml` — STG/e2e/qal/dynamic
  Spring profile YAMLs (`application-stg*.yml`, etc.) are NOT protected and
  don't need elevated human-approval to edit. Confirmed via `repoctl explain`
  output during CPV2-15698. Don't assume a config file needs escalation
  without checking `repoctl explain` first — the list is shorter than it
  looks at a glance.
- For pure config-value YAML changes (e.g. adding a missing `base-url` key,
  no code path touched), `repoctl verify`'s full compile+test+coverage+flyway
  gate adds no real signal for that class of change — it's the wrong
  verification tool. Verify instead via `git diff` inspection + a YAML syntax
  parse check (`python3 -c "import yaml; yaml.safe_load(open(path))"`) +
  confirming the new key path resolves to the intended value.

## cpclient

- A local `tsc` failure of the shape "Property 'X' does not exist on type" on
  money-api-typescript-derived types (e.g. `V3CheckoutContext.tsx` referencing
  `.title`/`.description` on the `Checkout`/`CheckoutBase` type) can be a stale
  `node_modules` issue, not a real code bug. Check for a version mismatch
  between `node_modules/@money/money-api-typescript/package.json`'s
  `"version"` field and the version pinned in `package-lock.json` (and the
  `^`-range in `package.json`'s dependencies, e.g.
  `"@money/money-api-typescript": "^1.0.1034"`). If `node_modules` is behind
  (e.g. installed `1.0.1026` vs lockfile's `1.0.1034`), running `npm install`
  resyncs it and the `tsc` errors disappear — no code change needed. Always
  check this version-mismatch possibility before assuming a `tsc` failure in a
  money-api-typescript-derived file is a real pre-existing bug worth fixing or
  working around. Confirmed 2026-07-28 (CPV2-15710 session): `repoctl verify`
  failed with 4 `tsc` errors in `V3CheckoutContext.tsx:502-508` referencing PR
  #5644's money-api `1.0.1034` schema field move; `node_modules` had `1.0.1026`
  installed; `npm install` fixed it in ~2 minutes, verify passed cleanly
  afterward, confirming it was never a real regression.

## Code review

- `catch (Exception | Error ex)` is a **no-op rewrite** of
  `catch (Throwable ex)`, not a narrowing — `Throwable` has exactly two
  direct JVM subclasses (`Exception` and `Error`), so multi-catching both
  catches exactly the same set as catching `Throwable` itself. A review
  finding that claims "narrowing... no loss of coverage" is self-contradicting
  — if there's truly no loss of coverage, it isn't a narrowing. Treat that
  framing as suspect by default whenever a review proposes narrowing a
  `Throwable` catch to a multi-catch still spanning both branches.
  Separately, when a review proposes narrowing `Throwable` down to just
  `Error` (or just `Exception`), read every statement inside the try block
  to check whether anything can throw a plain `RuntimeException` not already
  covered by a sibling catch (e.g. for a checked exception type) — a sibling
  catch for one checked exception does not mean all `RuntimeException`s are
  covered elsewhere. (Evidence: CPV2-15618 review-challenge, sales-checkout-svc —
  a reviewer's "narrow to `Exception|Error`" finding was a no-op, and a
  companion "narrow to `Error`" finding on a different catch would have let
  real `RuntimeException`s from `buildHeaders`/`getAppContext`/`iedm.getClass()`
  propagate uncaught.)
