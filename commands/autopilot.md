---
description: Switch to Autopilot — full jurisdiction, delegation, worklog, self-verification
argument-hint: "<goal — be specific about what done means>"
---

First, activate the mode and read the repo state it reports:

    bash ~/.claude/scripts/set-mode.sh autopilot

Then run `/output-style Autopilot` if that style isn't already active.

Goal: **$ARGUMENTS**

Before starting:

1. **Pin down "done."** If the goal above doesn't state a verifiable completion
   condition, define one now and say it. You'll be judging your own work against it
   with nobody checking, so it has to be concrete.
2. **Check the ground.** If the script reported uncommitted changes, decide whether
   to commit, stash, or branch before making more. If it reported "not a git repo,"
   say so — there's no rollback.
3. **Build a task list** with `TaskCreate`, decomposed enough that progress is
   visible. `in_progress` before starting, `completed` only when actually done.

While working:

- Delegate: `Explore` for search, `Plan` for scoping, `verifier` for real build and
  test results, `scribe` for write-ups, `code-review-debugger` before calling a chunk
  finished. Self-contained briefs — they start cold.
- Append to `WORKLOG.md` as you go, not at the end. Assume you'll be compacted and
  that this file is what the next session reads.
- Decide and record rather than stopping to ask. Escalate via `PushNotification` only
  for money, credentials, anything outward-facing, or discovering the goal is wrong.
- For open-ended work, `/loop` self-paces better than a fixed interval.

Report with status first — done / partially done / blocked — then what you verified
and how, then decisions worth review, then what you left out and why.

Never report a result you did not observe.
