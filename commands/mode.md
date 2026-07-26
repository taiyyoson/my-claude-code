---
description: Show the active mode and what it permits
---

Run this and report the output verbatim:

    bash ~/.claude/scripts/show-mode.sh

If it prints a WARNING about `mode-guard.sh` not being registered, say so plainly —
that means nothing is enforcing the mode boundary and `install.sh` needs re-running.

If the user wanted to *change* mode rather than inspect it, point them at `/coach`,
`/build`, or `/autopilot` instead of editing the mode file yourself.
