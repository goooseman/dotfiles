---
name: obsidian-report
description: Use when writing a report, research writeup, daily note, investigation, or any long-form markdown intended for the user's personal knowledge base / "second brain" / Obsidian vault — or when the user says to put a document "in Obsidian", "in the vault", or "via the Obsidian CLI". Covers where notes go, how to create them with the `obsidian` CLI, and the vault-native format (which differs from a repo/corporate report).
---

# Obsidian Report

Write reports **into the user's Obsidian vault** using the `obsidian` CLI, formatted in the **vault-native style** — not the formal repo-report style. A vault note is a node in a personal knowledge graph: it opens with wikilinks and tags, uses a conversational headline, and leans on callouts and dense inline links. It is NOT a numbered corporate document.

## When to use

- The user asks for a report, research summary, daily note, KT, or investigation writeup meant for their knowledge base.
- The user says "put it in Obsidian", "in the vault", "via the Obsidian CLI", or references their "second brain".
- You are moving an existing doc out of a code repo and into the vault.

**Do NOT** drop a knowledge-base note as a plain `.md` inside a git repo, and do NOT reuse a formal numbered-section report format for the vault. Reports for a repo (PR docs, design specs committed to the codebase) stay in the repo in repo format; knowledge-base notes go in the vault in vault format.

## Step 1 — Discover the vault

```bash
obsidian vaults verbose        # name + path of every known vault
obsidian folders               # top-level folder tree (learn where to file the note)
```

There is usually one vault. Note its **name** and **path** — the CLI writes into the vault; the path lets you read files back to verify.

## Step 2 — Pick the location and filename

- File into the folder that matches the topic. Common homes: `<area>/daily/` for dated writeups, `deep-researches/` for multi-source research, `<area>/projects/` for project notes. Run `obsidian folders` and match the existing structure — do not invent a new top-level folder.
- **Filename convention is per-vault — match sibling files.** Many vaults use `YYYYMMDD-kebab-title.md` (no dashes in the date) for daily notes. Check with `obsidian files folder=<dir>` and copy the dominant pattern rather than assuming.

## Step 3 — Write the content in vault-native format

**Read [report-format.md](report-format.md) and follow it exactly.** The vault format is deliberately different from a repo report — get the opening wikilink line, the tag line, and the headline right.

## Step 4 — Create the note via the CLI

The `obsidian create` command takes the body via `content=`. The docs mention `\n` for newlines, but **`create` also accepts real newlines directly** when you pass the body as a single shell variable — this is the robust path for a long report (no fragile escaping). Stage the body in a heredoc-fed file, then pass it via a variable:

```bash
# 1. Write the note body — real markdown, real newlines — to a temp file.
cat > /tmp/note.md <<'EOF'
[[intuit/indexes/cpclient]] [[intuit/indexes/intuit-projects]]

#intuit/cpclient #ai #pr-review #gbrain-created

# your conversational headline here

> [!tip] TL;DR
> one-paragraph bottom line.

## first section
...
EOF

# 2. Create the note, passing the whole file as content.
obsidian create path="intuit/daily/20260702-your-title.md" content="$(cat /tmp/note.md)"
```

Use a **quoted** heredoc delimiter (`<<'EOF'`) so backticks, `$`, and `[[ ]]` in the body are written literally instead of being expanded by the shell. Avoid hand-rolling a `\n`-escaping `sed` pipeline — the BSD `sed` on macOS rejects the `:a;N;$!ba` label form, and it's unnecessary since real newlines work.

Then **verify it landed** by reading the file back from the vault path (from `obsidian vaults verbose`):

```bash
obsidian vault info=path        # get the vault path
head -6 "<vault-path>/intuit/daily/20260702-your-title.md"
obsidian wordcount path="intuit/daily/20260702-your-title.md"
```

- Add `overwrite` to `create` only when intentionally replacing an existing note.
- To open it for the user after writing: append `open` to the `create` command.

### Alternative for very large bodies

If a single `content=` argument is too large for the command line, create a stub then fill it in chunks with `append` (same content rules — quoted-heredoc file, real newlines):

```bash
obsidian create path="intuit/daily/20260702-your-title.md" content="# placeholder"
obsidian append path="intuit/daily/20260702-your-title.md" content="$(cat /tmp/note-part2.md)"
```

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Wrote the note into the code repo instead of the vault | Create it in the vault via `obsidian create`; if it was committed, `git rm` it |
| Used a numbered corporate format (`## 1.`, `## 2.`) | Use the vault format in [report-format.md](report-format.md) — headline + callouts + `##` topic sections |
| No wikilinks / no tags at the top | Vault notes MUST open with a `[[wikilink]]` line and a `#tag` line — that is how the graph and search find them |
| Invented a new folder or filename scheme | `obsidian folders` + `obsidian files folder=<dir>` and match siblings |
| Multiline content mangled by shell expansion (backticks/`$` interpreted) | Stage the body with a **quoted** heredoc (`<<'EOF'`) and pass `content="$(cat file)"` — see Step 4 |
| Assumed the note wrote correctly | Read it back from the vault path and check the first lines + word count |

## Quick reference

| Task | Command |
|------|---------|
| List vaults + paths | `obsidian vaults verbose` |
| Vault path only | `obsidian vault info=path` |
| Top-level folders | `obsidian folders` |
| Files in a folder | `obsidian files folder=<dir>` |
| Existing tags (match conventions) | `obsidian tags counts sort=count` |
| Create note | `obsidian create path=<dir/name.md> content="...\n..."` |
| Append to note | `obsidian append path=<dir/name.md> content="...\n..."` |
| Open note | `obsidian open path=<dir/name.md>` |
| Move / rename | `obsidian move path=<old> to=<new>` |
| Delete | `obsidian delete path=<dir/name.md> [permanent]` |
| Word count | `obsidian wordcount path=<dir/name.md>` |
