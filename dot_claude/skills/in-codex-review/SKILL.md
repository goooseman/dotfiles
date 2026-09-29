---
name: in-codex-review
description: Use when a `/g-` workflow (or anything else) wants a second-opinion review of a spec or code changes and would otherwise say "codex" or "codex-review" — the codex CLI is not permitted on this machine, so this skill routes the same review through Cursor's `agent` CLI instead. Owns the `agent` invocation and model default for that review.
---

# in-codex-review — second-opinion review via Cursor's `agent` CLI

The `codex` CLI is **not allowed on this machine**. Whenever a workflow, skill,
or the user says "codex review", "ask codex", "run codex on this", or invokes
`/codex-review`, use **this skill** instead — it runs the same kind of
adversarial second-opinion review, but through Cursor's `agent` CLI
(`/Users/agusman/.local/bin/agent`), never `codex`.

## Default model

Unless the caller specifies otherwise, use **`gpt-5.6-sol`**:

```
agent --print --mode plan --model gpt-5.6-sol "prompt here"
```

- `--mode plan` keeps the review read-only (analyze and propose, no edits) —
  equivalent in spirit to codex's `--sandbox read-only`.
- `--print` makes it a one-shot scripted call instead of an interactive
  session.
- If `gpt-5.6-sol` turns out to be invalid or unavailable in a future session
  (check with `agent --list-models` if a call errors on the model name),
  surface that to the user and ask which model to use instead — don't
  silently substitute a different one.

## Workflow

1. **Check availability**: `command -v agent` (or `agent --version`). If not
   found, tell the user the `agent` CLI isn't installed and stop — do not fall
   back to `codex`.
2. **Build the prompt** the same way you would for any second-opinion review:
   what to review (file paths, line ranges, or a description — don't paste
   whole files if `agent` can read them itself), what to focus on, and a
   specific question. `agent` runs from the current working directory and can
   read project files directly.
3. **Run it**:
   ```
   agent --print --mode plan --model gpt-5.6-sol "<prompt>"
   ```
   For a longer-running review, run in background and poll rather than
   blocking the turn.
4. **Present the result** to the user, then stop — same rule as any other
   second-opinion tool: findings are input for discussion, not an automatic
   work order. Do not apply fixes without explicit approval.

## Red flags — STOP and reset

- About to shell out to `codex` or `codex exec` for any reason — that CLI is
  disallowed here regardless of what an older skill or memory says.
- About to silently swap in a different model because `gpt-5.6-sol` errored —
  ask the user first.
- About to apply a suggested fix without the user approving it first.
