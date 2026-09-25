---
name: g-brainstorm
description: Use when the user runs /g-brainstorm or wants to sharpen a vague project idea into a spec. Delegates to superpowers:brainstorming, scores spec confidence, then offers a Codex second-opinion review. The spec is the final artifact — implementation happens directly from the spec, with NO separate plan stage.
requires: superpowers@claude-plugins-official
---

This skill is a thin wrapper. Invoke `superpowers:brainstorming` via the Skill tool now.

> **Note:** If you see a deprecation warning about `superpowers:brainstorm` (old name), ignore it — this wrapper correctly routes to `superpowers:brainstorming`. If you called this as `superpowers:brainstorm` or `/brainstorm`, please switch to `/g-brainstorm` (this skill) going forward.

> **OVERRIDE — spec only, no plan:** `superpowers:brainstorming` ends by instructing you to
> invoke the writing-plans skill. **Do NOT follow that step.** This wrapper (per explicit
> user preference) makes the spec the terminal artifact: brainstorm → spec → confidence
> score → optional Codex review → implement directly from the spec. Never invoke
> `superpowers:writing-plans`, `/plan`, or any planning skill from this workflow. To make
> spec-driven implementation work, the spec must carry what a plan would have: exact file
> paths, component interfaces, config keys, enumerated test cases, and acceptance criteria.

> **OVERRIDE — never commit the spec:** `superpowers:brainstorming` instructs you to write the
> design doc into the repo and "commit the design document to git". **Do NOT commit it, and do
> NOT write it inside the target repo's working tree.** Specs and plans are working artifacts,
> not deliverables — they must never appear in a PR diff. See "Where the spec lives" below.

---

## Where the spec lives — NEVER in the repo

Write the spec **outside the target repo's git working tree**. In order of preference:

1. `<workspace-root>/.local-specs/YYYY-MM-DD-<topic>-design.md` — sibling to `repos/`, outside every
   repo checkout. Preferred: survives the session and is easy to find later.
2. The session scratchpad directory, if no workspace root applies.

Name it `YYYY-MM-DD-<ticket>-<topic>-design.md`, matching the convention the repo would have used.

**Rules:**

- **Never** `git add` / `git commit` a spec, plan, or design doc — not even "just this once", not
  even as a separate docs-only commit, not even when the repo already contains a `docs/specs/`
  directory full of them. A pre-existing convention of committed specs is not permission to add
  another; those are someone else's earlier choice.
- **Never** write the spec to a path inside the repo, even intending not to commit it — an untracked
  file inside the tree gets swept up by a later `git add -A` or shows up as noise in `git status`.
- If a spec was already committed before this rule was noticed, add a **forward revert commit**
  removing it. Do not rewrite history (no rebase/reset/amend) unless the user explicitly asks.
- When handing the spec to the user, give the **absolute path** — they cannot find it via the repo.

**Why:** committed specs bloat the PR diff, invite review comments on a working artifact that is
already settled, and go stale the moment implementation diverges from them. The code and its tests
are the deliverable; the spec is scaffolding.

---

## After superpowers:brainstorming completes

Once `superpowers:brainstorming` has finished and a spec doc has been written — **outside the repo,
uncommitted, per the override above** — evaluate the spec's confidence before moving to implementation.

### Spec Confidence Score

Score each dimension 0–0.2 (0 = missing/unclear, 0.1 = partial, 0.2 = clear and complete):

| Dimension | What to check |
|-----------|---------------|
| **Clarity** | Is the goal and scope unambiguous? Could two engineers read it and agree on what to build? |
| **Completeness** | Are all functional requirements captured? Are edge cases and error states addressed? |
| **Testability** | Does each requirement have a measurable acceptance criterion? |
| **Scope tightness** | Is there anything vague like "should feel fast" or "should be intuitive" that can't be verified? |
| **Risk coverage** | Are key risks, unknowns, and assumptions explicitly listed? |

Display the result as:

```
Spec confidence: X.X / 1.0
  Clarity:       0.2
  Completeness:  0.2
  Testability:   0.1  ← weakest
  Scope:         0.2
  Risk coverage: 0.2
```

**If score < 0.9:** Surface the weakest dimension and ask ONE targeted follow-up question before proceeding. Do not ask multiple questions at once.

**If score ≥ 0.9 (or after the user resolves the follow-up):** the spec is ready.

### Offer a Codex second-opinion review of the spec

Before implementation starts, offer the user an independent review of the spec via Codex 5.3 Extra High:

> "Spec is ready. Want a second-opinion review from Codex before we implement? Run `/codex-review spec` — it'll iterate review-and-edit on the spec doc until it's clean or you disagree with the remaining findings."

- Recommend it especially when the user is about to commit significant engineering effort against this spec, or when any of the confidence dimensions scored 0.1.
- The user may decline, accept, or defer ("after I read it again"). Respect their choice.
- If they accept: invoke the `codex-review` skill with arg `spec`. When it returns, re-evaluate the spec's confidence score and continue here.
- If they decline or defer: continue to implementation.

### Implement directly from the spec (no plan stage)

The spec is the implementation contract. Do NOT invoke `superpowers:writing-plans` or any
planning skill. Instead:

1. **Derive execution order** from the spec's component structure (dependencies first:
   clients/helpers → integration points → config → tests → e2e verification) and record it
   as a task list (TaskCreate), one task per component or coherent change.
2. **Confirm the order with the user in one short message**, then execute task by task —
   TDD per component (superpowers:test-driven-development), marking tasks in_progress /
   completed as you go.
3. **Acceptance = the spec.** Every acceptance criterion, enumerated test case, and
   verification step in the spec must be satisfied and demonstrated (run the commands, show
   the output) before the work is called done.
4. Multi-repo or multi-PR mechanics defined in the spec (e.g. a separate config-repo PR)
   are tasks like any other — include them in the task list.
