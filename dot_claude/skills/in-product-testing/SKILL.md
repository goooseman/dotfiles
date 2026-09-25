---
name: in-product-testing
description: Use when an Intuit product change (QBO AppFabric plugin, cpclient/Counterpart Portal, or similar) needs verifying in a real browser via Playwright MCP — smoke-testing a widget/drawer/trowser, pointing a shell at a locally-served bundle, or any "does it actually render" question. Requires Playwright MCP.
---

# Intuit Product Testing — validate local changes via Playwright MCP

## Overview

Shared playbook for browser-testing a locally-running Intuit product with Playwright MCP: start the local server, handle the local-dev TLS trust step, log in if required, point the shell/app at local code, and visually verify. Product-specific steps live in their own section below — read the section for the product you're testing, plus the shared Prerequisites and Common mistakes sections.

## Prerequisites (all products)

- **Playwright MCP connected** (`browser_navigate` etc. callable — load via ToolSearch). If missing, tell the user: `claude mcp add -s user playwright -- npx @playwright/mcp@latest`, then restart the session.
- **Verify required local config/env files exist before serving — do not create or fabricate them.** Local dev servers commonly refuse to start (or fail confusingly) without checked-in or environment-specific files (e.g. cpclient's `server/.env`, `server/config/forcedLocalConfig.json`). If a required file is missing, stop and ask the user rather than guessing values or copying one from another environment (e.g. `.env.test`) — wrong values here are a worse failure mode than a blocked start.
- **Expect a local TLS "not secure" browser warning and treat it as normal, not a failure.** Several of these dev servers run HTTPS with a dev/local certificate that the OS/browser will not trust by default (e.g. cpclient's `tls/cert.pem` / `tls/key.pem`, checked into the repo). Two ways to proceed:
  - Ask the user to click through the browser's interstitial ("Advanced" → "Proceed to localhost (unsafe)") the first time a new profile/browser hits it, since accepting a self-signed/dev cert is a trust decision the user should make, not something to silently bypass.
  - Or launch Playwright with `--ignore-https-errors` (or pass `ignoreHTTPSErrors` in the MCP browser config) to skip the interstitial entirely for automated runs.
  Don't treat the "not secure" warning itself, or a `NET::ERR_CERT_AUTHORITY_INVALID`-style page, as evidence the server is broken — check whether the page content behind it loaded correctly first.
- **Always ask the user to accept the cert exception themselves rather than trying to script around it.** If `browser_navigate` throws `net::ERR_CERT_AUTHORITY_INVALID`, the MCP's tracked page/context doesn't expose a `ignoreHTTPSErrors` toggle directly — don't spend time working around this with `browser_run_code_unsafe` tricks (e.g. spinning up a second browser context), since the MCP's tab/page tracking only follows the original context and a second one becomes invisible to `browser_navigate`/`browser_tabs`. Just tell the user the cert needs accepting and ask them to click through it in their own session (confirmed as the working, expected flow 2026-08-04).

---

## QBO (AppFabric plugin)

Serve the local plugin bundle, log into QBO e2e with Playwright, override the plugin's `config.json` source to localhost, open the plugin's playground URL, and visually verify. Works in any repo whose `package.json` has `"serve": "plugin-cli serve"`. **Plugin ID = the `name` field in the repo's `package.json`.**

### Prerequisites
- One-time machine setup done: `yarn verify-dev-setup` (installs the `plugin-localhost.intuitcdn.net` `/etc/hosts` entry + TLS cert; `plugin-cli serve` fails its host validation without it). If this hasn't been run, the local server will fail host validation — run it and ask the user before proceeding if you're unsure it's been done.

### Steps

1. **Serve the plugin locally — without opening a browser**

   ```bash
   yarn serve --no-open   # plugin-cli serve supports -o/--[no-]open
   ```

   Run in the background and keep it running for the whole test session (webpack rebuilds on edit). Wait for webpack's "compiled successfully".

   Config URL: `https://plugin-localhost.intuitcdn.net:<port>/config.json`. Default port is **34212**, but the CLI walks to the next free port in `[port, port+1000]` — **parse the actual port from the serve output**, don't assume.

2. **Log into QBO e2e**

   1. `browser_navigate` → `https://app.e2e.qbo.intuit.com/app/invoices`
   2. Sign in with the shared e2e test account: user `cp_team_iamtestpass`, password `CpRocks1!`. Dismiss any OTP / "remind me later" interstitials.
   3. Company picker: choose the company whose name contains **"Territory"** — match by name, not position (it's currently third). If zero or several match, stop and ask the user which company.
   4. Logged in = the QBO left-nav shell renders. **Note the final origin** (`app.e2e.qbo.intuit.com` vs `e2e.qbo.intuit.com` — login may redirect between them): the override in step 3 is per-origin localStorage, so steps 3 and 4 must run on that same origin.

3. **Override the plugin to localhost**

   Non-interactive adaptation of the team bookmarklet (original prompt-based version lives in the Obsidian vault: `obsidian read path="intuit/daily/20260715-cpclient-donations-crm-brand-kit-picker.md"`). Inline the two values and run on the **logged-in QBO page, same origin as the validation URL**, via `browser_evaluate`. On QBO the `window.qbo` branch is the one expected to fire; the others cover QBSE and the newer ecosystem shell:

   ```js
   () => {
     const pluginId = 'PLUGIN_ID'; // package.json "name"
     const configUrl = 'CONFIG_URL'; // from step 1, ends in /config.json
     if (window.qbo) {
       const pss = new (require('qbo-ui-libs-plugins/services/PluginStorageService'))();
       const config = { pluginId, description: '', configUrl, hasLayers: pluginId !== 'qbo-ui' };
       pss.updatePlugin(pluginId, config) || pss.storePlugin(config);
     } else if (window.__shellInternal) {
       const save = JSON.parse(localStorage.ecosystem_plugins || '{"plugins":[]}');
       const existing = save.plugins.find((c) => c.id === pluginId);
       if (existing) existing.configUrl = configUrl;
       else save.plugins.push({ id: pluginId, description: '', configUrl, hasLayers: true });
       localStorage.ecosystem_plugins = JSON.stringify(save);
     } else if (window.qbse) {
       localStorage[`qbse.${pluginId}.url`] = configUrl.replace(/\/config\.json$/, '');
     }
     location.reload();
   }
   ```

   UI fallback if the evaluate path misbehaves: `https://e2e.qbo.intuit.com/app/pluginDevTool` → "new local plugin" → JSON `{ "id": "<pluginId>", "description": "", "configUrl": "<configUrl>", "hasLayers": true }` → refresh.

4. **Open the validation page and verify**

   - Check the repo README for a documented test URL first; otherwise default to `https://e2e.qbo.intuit.com/app/<pluginId>/playground` (append `?widgetId=<id>` to open a specific widget).
   - Example — `paymentlinks-forms-ui`: `/app/paymentlinks-forms-ui/playground` renders the payment-links/donations playground with Trowser buttons; `?widgetId=trowser-form` opens the form trowser directly. **Success = the form renders inside the trowser** (take a `browser_snapshot`/screenshot).
   - **Confirm the LOCAL bundle is actually live**: `browser_network_requests` must show hits to `plugin-localhost.intuitcdn.net:<port>`. If not, you're looking at the CDN release, not local code. Strongest proof: edit a visible string, wait for the webpack rebuild, reload, see the change.

5. **Reset when done**

   Same shape as step 3, removal branches:

   ```js
   () => {
     const pluginId = 'PLUGIN_ID';
     if (window.qbo) {
       const pss = new (require('qbo-ui-libs-plugins/services/PluginStorageService'))();
       pss._storePlugins(pss.loadPlugins().filter((c) => c.pluginId !== pluginId));
     } else if (window.__shellInternal) {
       const save = JSON.parse(localStorage.ecosystem_plugins || '{"plugins":[]}');
       save.plugins = save.plugins.filter((c) => c.id !== pluginId);
       localStorage.ecosystem_plugins = JSON.stringify(save);
     } else if (window.qbse) {
       delete localStorage[`qbse.${pluginId}.url`];
     }
     location.reload();
   }
   ```

### QBO-specific mistakes

| Mistake | Fix |
|---------|-----|
| Assuming port 34212 | The CLI walks to a free port — parse it from the serve output |
| Plain `yarn serve` | Opens the user's default browser outside Playwright's control — always `--no-open` |
| Running the override before login/company selection | The override lives in per-origin localStorage — run it on the logged-in QBO page, then reload |
| Override on one host, playground on the other | `app.e2e.qbo.intuit.com` and `e2e.qbo.intuit.com` are different origins — run steps 3 and 4 on the same one |
| Declaring success without checking the network tab | No `plugin-localhost` requests = you tested the CDN release, not local code |
| Killing `yarn serve` mid-session | The shell fetches config/bundles on every reload — keep serve running until testing is done |
| TLS error on `plugin-localhost.intuitcdn.net` | Run `yarn verify-dev-setup` to install the cert, or launch Playwright with `--ignore-https-errors` |
| "Verify it's you" sign-in screen ignores ALL clicks / never advances (clicking "Enter password" fires an `identityBrowserInitializeVerifierWithCredential` FIDO2 init, then nothing) | The SPA awaits `navigator.credentials.get()` even on the password path, so a never-resolving stub wedges the flow permanently. Stub it to REJECT like a user cancel instead — on a FRESH full page load (a pending get() from before the stub still wedges), run `browser_evaluate`: `() => { navigator.credentials.get = () => Promise.reject(new DOMException('The operation either timed out or was not allowed.', 'NotAllowedError')); if (window.PublicKeyCredential) { PublicKeyCredential.isConditionalMediationAvailable = () => Promise.resolve(false); PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable = () => Promise.resolve(false); } }` — then account choice → "Enter password" clicks work normally (verified live 2026-07-21; the old never-resolving-Promise stub failed live the same day) |

---

## cpclient (Counterpart Portal)

Start the local HTTPS dev server and drive it directly with Playwright — there is no config-override/shell-injection step like QBO's; cpclient serves its own UI straight from `localhost`.

### Steps

1. **Verify required local files exist before starting** — do not generate or copy these from `.env.test` or elsewhere:
   - `server/.env` (dev-mode env values: `NODE_ENV`, `NODE_CONFIG_ENV`, `PORTAL`, `CP_ILB`, etc.)
   - `server/config/forcedLocalConfig.json` (local config overrides; an empty `{}` is valid)

   If either is missing, stop and ask the user — `checkForEnvironmentVariables.js` throws a "missing environment variable/s" error on start if required vars aren't present, which is a signal to check these files, not to invent values.

2. **If the change adds a new `config.endpoints.*` (or other dynamic-config-sourced) field and its companion `cpclient-config` PR isn't merged yet**, add the field to `server/config/forcedLocalConfig.json` under the same nested path the real dynamic config would use (e.g. `{ "network": { "endpoints": { "myNewField": "..." } } }` — check `server/renderers/redesign.js`'s `getConfig('network').endpoints` destructure to confirm the path). This file is deep-merged over the real fetched E2E dynamic config (`server/config/index.js`), not a substitute for it — **cpclient's local dev server fetches the real E2E dynamic config over the network, it does NOT read from `server/config/test.json`** (that file is only a `NODE_ENV=test`/Jest fallback, never served to a locally-running browser session). Direct edits to repo files go through `code-builder` per this workspace's write-boundary rules, even for a throwaway local-only test value — revert to `{}` when done testing. (Confirmed 2026-08-04, PR #5690/CPV2-15365 verification.)

3. **Start the dev server — plain, no env var prefixing**

   ```bash
   npm run server-dev
   ```

   Do **not** prefix with `NODE_CONFIG_ENV=test`, `APP_ENV=e2e`, or similar overrides borrowed from CI/test configs — those are for the automated test pipeline, not manual/local browser testing, and can cause confusing build or runtime failures. If e2e-specific behavior is needed (e.g. dispatcher URL, maintenance flags), set it via `server/config/forcedLocalConfig.json` instead.

   This runs a Next.js build first, then starts the Express/SSR server (`server/index.ts`). Run in the background. **Boot is genuinely slow (observed 3-5+ min end to end)** — after the Next.js build finishes, nodemon starts `server/index.ts`, which logs IDPS SDK init, then goes silent for a couple minutes while it fetches the real dynamic config and IXP flags from live `*-e2e.api.intuit.com` endpoints. Silence here is normal, not a hang — confirm the process is still alive and has open sockets to `config-e2e.api.intuit.com`/`ixp-ff-e2e.api.intuit.com`/`experimentconfig-e2e.api.intuit.com` (via `lsof -p <pid> -i`) before concluding it's stuck. Only treat it as actually crashed if nodemon prints `app crashed` or the process exits.

   **Checking the listening port**: `lsof -i :8443` may show the connection under the name **`pcsync-https`** (macOS's `/etc/services` name for port 8443) instead of the numeric port — don't conclude the server isn't listening just because you don't see `8443` literally in the output. Confirm with `curl -sk -o /dev/null -w "%{http_code}" https://localhost:8443/` instead (a `302` from a bare `/` request is expected — see step 5).

4. **Open the app**

   Use `https://localhost.intuit.com:8443` as the hostname, **not** bare `https://localhost:8443`. (Admin/health endpoints run on `8490`.) This is real HTTPS via a checked-in dev cert — expect the browser's "not secure" warning per the shared Prerequisites section above. **Always ask the user to click through/accept the cert exception themselves** rather than trying to bypass it via Playwright code — see the shared Prerequisites note above.

   Root `/` redirects out to `quickbooks.intuit.com` (it needs a real sale/invoice context and has none at the bare root) — this is expected, not a broken server. To exercise a real payable/checkout page, you need an actual invoice URL — ask the user for one; there is no synthetic/fixture route. The path shape is `/t/scs-v1-<long-hex-token>?locale=EN_US` (a real E2E share-link token minted server-side elsewhere, e.g. via `connect-e2e.api.intuit.com/t/scs-v1-...`). Take the *same* token/path from a working hosted E2E link and replay it against `localhost.intuit.com:8443` — the token itself is environment-portable.

5. **Local feature-flag override**

   Append `?ff-<flagName>=true` (or `=false`) to the URL — this is a real, request-scoped server-side override (`server/helpers/FeatureFlagsService.js`'s `getOverwrittenFlags`), not a mock. It does NOT persist across navigations/reloads that don't include the param — each request re-evaluates from scratch, so don't assume a flag stays off/on after a follow-up navigation without the param. Conversely, a flag can appear "on" with no query param at all if it's already enabled via real IXP treatment for that session/company — check `window.__NEXT_REDUX_STORE__.getState().featureFlags['<flagName>']` via `browser_run_code_unsafe` to see the actual resolved value rather than assuming the query param is the only source of truth.

6. **Login**

   No general-purpose manual-login test account is documented in the repo. If the flow under test requires an authenticated session, ask the user which account/credentials to use rather than guessing — the only credentials checked into the repo (`__tests/playwright/fixtures/dataCreators/__fixtures__/playwrightE2eCredentials.ts`) are scoped to specific automated payment-provider test scenarios (PayPal, QBO Autopay, PBB Adyen), not a general CP login.

7. **Verify**

   Navigate to the specific page/flow under test and confirm the change renders/behaves as expected (`browser_snapshot` / screenshot, `browser_console_messages`, `browser_network_requests`). Since there's no CDN-vs-local ambiguity here (you're always hitting your own `localhost:8443`), the main risk is stale build output — if a change doesn't show up, confirm the dev server actually rebuilt (watch its terminal output) before assuming the change is broken. For a feature gated by a flag, verify **both** the on and off paths explicitly (e.g. an injected `<script>` tag present/absent, a Redux-state boolean) rather than checking only the path you expect to have changed — don't assume the off-path is unaffected without checking, and don't assume a console error is a cpclient bug before checking whether it traces to a known, separately-tracked external/platform dependency (e.g. a companion backend PR or platform-side capability registration not yet live) rather than the code under test.

### cpclient-specific mistakes

| Mistake | Fix |
|---------|-----|
| Prefixing `npm run server-dev` with env vars (`NODE_CONFIG_ENV=test`, `APP_ENV=e2e`, etc.) | Run it plain. Use `server/config/forcedLocalConfig.json` for local overrides instead |
| Assuming `server/.env` or `forcedLocalConfig.json` will be auto-created if missing | They're checked-in/expected-present files, not generated on demand — stop and ask the user if either is missing rather than fabricating values |
| Editing `server/config/test.json` to test a new config field locally | The local dev server never reads `test.json` — it fetches the real E2E dynamic config. Use `server/config/forcedLocalConfig.json` instead |
| Treating the HTTPS "not secure" warning on `localhost:8443` as a broken server | Expected — it's a real dev cert the browser doesn't trust by default. Ask the user to click through it (don't try to script around it) |
| Using bare `https://localhost:8443` | Use `https://localhost.intuit.com:8443` — some CORS/cookie/redirect behavior is host-specific |
| Concluding the server is stuck/hung during the silent post-IDPS-init boot window | This is normal — it's fetching real dynamic config + IXP flags from live E2E endpoints. Check for open sockets to `*-e2e.api.intuit.com` via `lsof -p <pid> -i` before assuming a hang; only trust an actual `app crashed` nodemon message or process exit as a real failure |
| Concluding `lsof -i :8443` shows nothing = server not listening | macOS may report the port under the service name `pcsync-https` instead of `8443` — confirm with `curl` instead |
| Testing a real payable page by hitting bare `/` | Root redirects out (needs sale/invoice context). Get a real `/t/scs-v1-...` token URL from the user or an existing hosted E2E link |
| Assuming a shared login/test account exists for manual testing | Not documented in-repo — ask the user which credentials to use for the flow being tested |
| Declaring a change verified without confirming the dev server rebuilt | Watch the `server-dev` terminal output for the rebuild to complete before reloading and checking |
| Assuming a `?ff-X=true` override persists across reloads, or that a flag is off just because you didn't pass the param | It's per-request only; also flags can already be on via real IXP treatment — check the actual Redux `featureFlags` state, don't assume from the URL alone |
| Treating every browser console error as a regression from the change under test | Cross-check against the design doc / known dependencies first — some failures are expected, already-tracked external/platform gaps (e.g. a capability not yet registered on a separate platform team's side), not cpclient bugs |
