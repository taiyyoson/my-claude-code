---
description: Switch to Autopilot — full jurisdiction, delegation, worklog, self-verification
argument-hint: "<goal — be specific about what done means>"
---

```!
mkdir -p "${CLAUDE_PROJECT_DIR:-$PWD}/.claude" && printf 'autopilot' > "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/.mode" && echo "mode -> autopilot (broad authority; irreversible-operation guards active; WORKLOG.md will be appended on stop)" && cd "${CLAUDE_PROJECT_DIR:-$PWD}" && git rev-parse --is-inside-work-tree >/dev/null 2>&1 && { echo "branch: $(git rev-parse --abbrev-ref HEAD)"; echo "tree: $(git status --porcelain | wc -l | tr -d ' ') uncommitted change(s)"; } || echo "note: not a git repo — no worklog diff, and no rollback if this goes sideways"
```

Autopilot is active. Run `/output-style Autopilot` if that style isn't loaded.

Goal: **$ARGUMENTS**

Before starting:

1. **Pin down "done."** If the goal above doesn't state a verifiable completion
   condition, define one now and state it. You will be judging your own work
   against it with nobody checking, so it has to be concrete.
2. **Check the ground.** Uncommitted changes in the tree? Decide whether to commit,
   stash, or branch before you start making more. If this isn't a git repo, say so —
   there's no rollback.
3. **Build a task list** with `TaskCreate`, decomposed enough that progress is
   visible. Mark items `in_progress` before starting, `completed` only when truly
   done.

Then work. While working:

- Delegate: `Explore` for search, `Plan` for scoping, `verifier` for real test and
  build results, `scribe` for write-ups, `code-review-debugger` before declaring a
  chunk finished. Self-contained briefs — they start cold.
- Append to `WORKLOG.md` as you go, not at the end. Assume you'll be compacted and
  that this file is what the next session reads.
- Decide and record rather than stopping to ask. Escalate via `PushNotification`
  only for money, credentials, anything outward-facing, or discovering the goal
  itself is wrong.
- For genuinely open-ended work, `/loop` self-paces better than a fixed interval.

Report at the end with status first: done / partially done / blocked. Then what you
verified and how. Then decisions worth review. Then what you left out and why.

Never report a result you did not observe.
