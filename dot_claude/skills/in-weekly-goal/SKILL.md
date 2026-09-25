---
name: in-weekly-goal
description: Use when the user runs /in-weekly-goal or asks to record an achievement, win, or progress item for their weekly manager update. Takes the achievement text as argument; without an argument, the achievement is derived from the current session's work.
---

# Weekly Goal

Record one achievement into the current week's manager-update note in the Obsidian vault (`goooseman-secrets`).

## Canonical location

- Note path: `intuit/weekly/<ISO-week>.md` — e.g. `intuit/weekly/2026-W29.md`
- Compute the week with `date +%G-W%V`. NEVER `%Y-%V` — `%Y` mispairs with ISO weeks around New Year.
- The legacy single-file note `intuit/weekly-achievements.md` is **history only** (weeks before 2026-W29). Never append new entries there, even though vault search will surface it.

## Steps

1. **Resolve the achievement text.**
   - With an argument: use the user's wording (light copyedit fine).
   - Without: draft 1–2 outcome-focused sentences from what was actually accomplished in this session and **write it directly — do not ask for confirmation** (user preference, 2026-08-05). Only pause to ask if something is genuinely ambiguous (e.g. unclear which of several work streams to record); they'll request edits after seeing the result.
2. **Enrich.** Add links you can infer from context: PR URLs, Jira keys as `[CPV2-XXXXX](https://jira.intuit.com/browse/CPV2-XXXXX)`. Bold the key phrase of the bullet (matches the user's established style).
3. **Ensure the note exists:** `obsidian read path="intuit/weekly/<week>.md"`. If missing, create it from the template below (creating the note auto-creates the folder).
4. **Append the entry** as `- YYYY-MM-DD — <achievement>` under `## achievements`, using the safe content pattern: stage the text in a file via a **quoted** heredoc (`<<'EOF'`), then `obsidian append path="..." content="$(cat file)"` — unquoted content mangles backticks and `$`.
5. **Verify and report.** Read the note back; confirm the line landed. Tell the user the note path and the exact line added.

## New-note template

```
[[intuit/indexes/intuit-projects]]

#intuit/weekly #gbrain-created

# week <ISO-week> — manager update

## achievements
```

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Appending to legacy `intuit/weekly-achievements.md` (vault search finds it first) | New entries go only to `intuit/weekly/<week>.md` |
| `date +%Y-W%V` | `%G` is the ISO year that pairs with `%V` |
| Bare bullet with no date | Every entry starts `- YYYY-MM-DD — ` |
| Prompting to confirm the draft in no-argument mode | Write directly; only ask when genuinely ambiguous |
| Unquoted heredoc/content | `<<'EOF'` + `content="$(cat file)"` |
| `obsidian read --vault X "path"` (flag/positional form) | Silently returns the app's currently-open note with exit 0 — use `path="..."` key=value form and verify the `# week` heading in what you read |
