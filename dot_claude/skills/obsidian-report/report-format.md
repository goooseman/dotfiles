# Vault-Native Report Format

The format for an Obsidian vault note is **different from a repo/corporate report**. A vault note is a node in a personal knowledge graph. Optimize for: discoverability in the graph (links + tags), fast re-reading months later (headline + TL;DR callout), and traceability (dense inline links to every source).

## Repo report vs. vault note — the difference

| | Repo report (what NOT to do in the vault) | Vault note (do this) |
|---|---|---|
| Opening | Title + metadata block (Date/Author/Branch) | `[[wikilink]]` line, then `#tag` line, then `# headline` |
| Title | Formal: "Cpclient PR Guard — Enrichment Report" | Conversational, specific: "how we keep the PR Guard ruleset fresh + measure if it helps" |
| Structure | Numbered sections `## 1.`, `## 2. Q1 —` | Unnumbered `##` topic sections; a `> [!...]` TL;DR callout up top |
| Emphasis | Prose paragraphs | Callouts, bold leads, dense inline links, emoji signposts where the vault already uses them |
| Links | Footnote-ish, "Sources" section | Inline at the point of the claim, plus `[[internal wikilinks]]` to related notes |
| Audience | A reviewer/team | Future-you, skimming |

## Required structure

```markdown
[[related-note-or-index]] [[another-index]]

#area/subarea #topic #topic2 #gbrain-created

# conversational, specific headline (lowercase is fine, match the vault)

Related indexes: [[area/indexes/foo]] · [[area/indexes/bar]]   ← optional but common

> [!tip] TL;DR
> The bottom line in 2–4 sentences. What did you find / decide / recommend? A reader
> should get the whole answer from this callout alone.

---

## first topic section

Prose with **bold leads** and inline links to sources at the claim:
finding X ([source](https://...)). Use `> [!note]` / `> [!warning]` callouts for
caveats and gotchas.

## second topic section
...

## recommendations   ← if the note is a research/decision writeup

1. Ordered, actionable, each with the "why" and a link.
```

### Line 1 — wikilinks

- Link to the vault's index/hub notes for this area and to closely related notes.
- Format: `[[note-name]]` or `[[folder/path/note-name]]` (exact path if ambiguous).
- It is fine to link a note that doesn't exist yet — that's a valid "to-write" marker in Obsidian.
- Discover candidates: `obsidian folders`, `obsidian files folder=<area>/indexes`.

### Line 3 — tags

- Space-separated `#tags`. Use **hierarchical** tags where the vault does (e.g. `#intuit/cpclient`).
- Reuse existing tags — check `obsidian tags counts sort=count` and match casing/structure. Don't spawn near-duplicates (`#pr-review` vs `#prreview`).
- Include a **provenance tag** if the vault uses one (this vault uses `#gbrain-created` for newly authored notes, `#gbrain-edited` for edits). If unsure whether the vault uses provenance tags, check the tag list before adding one.

### Headline (`# `)

- One `#` H1, conversational and specific — it should say the actual conclusion/topic, not a document type. "cpclient prod pod spikes — two June 22 HPA scale-ups" beats "Incident Report".

### TL;DR callout

- Lead with a `> [!tip] TL;DR` (or `> [!summary]`) callout so the answer is readable without scrolling.
- For multi-part findings, a bolded one-liner per part inside the callout works well.

## Callout types to use

- `> [!tip]` / `> [!summary]` — TL;DR, key takeaway
- `> [!note]` — context, method ("Investigated via …")
- `> [!warning]` / `> [!caution]` — caveats, unverified sources, gotchas
- `> [!question]` — open questions

## Links & citations

- Put the link **inline at the claim**, not in a trailing bibliography.
- Prefer real deep links (Slack permalinks, Jira/ticket URLs, doc URLs, dashboard links with the query in them).
- Use `[[wikilinks]]` for anything that is (or should be) another note in the vault; use normal `[markdown](url)` for external/web/Slack/Jira links.
- Flag unverified sources explicitly in a `> [!warning]`.

## Tone

- Write for future-you: terse, high-signal, opinionated. Bold the leads. Keep sections scannable.
- Keep contacts/people and channels as a small table or list near the end if the note is a research/decision writeup.

## Anti-patterns

- ❌ A metadata header block (`**Date:** … **Author:** … **Branch:** …`) — vault notes carry that via tags/links and file location, not a corporate header.
- ❌ Numbered top-level sections (`## 1.`, `## 2.`).
- ❌ A single trailing "Sources" section instead of inline links.
- ❌ No tags / no wikilinks (the note becomes an orphan the graph can't surface).
- ❌ Formal "Executive Summary" phrasing — use a TL;DR callout instead.
