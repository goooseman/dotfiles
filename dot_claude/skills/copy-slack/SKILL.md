---
name: copy-slack
description: Use when the user asks to copy a message to the clipboard for Slack (e.g. "pcopy it", "copy this to Slack", "clipboard copy for Slack"). Formats links correctly and copies via pbcopy.
---

# Copy Slack

Copy a message to the clipboard, formatted for pasting into Slack.

## Steps

1. Use Slack's own markdown: `*bold*`, `_italic_`, `` `code` ``, `:emoji:` — not GitHub-style `**bold**`.
2. **Links MUST use `[text](http://...)` format.** Do NOT use Slack's native `<http://url|text>` format — the user always wants the `[text](url)` form regardless of target.
3. Write the message to a scratch file, then copy it with `pbcopy < file`. Never pipe unescaped text directly through a shell heredoc — stage it in a file first.
4. Confirm to the user that it's copied; don't repeat the whole message back unless asked.
