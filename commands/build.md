---
description: Switch to Build mode — plan first, you supervise, everything verified
argument-hint: "[what to build or fix]"
---

First, activate the mode:

    bash ~/.claude/scripts/set-mode.sh build

The full brief is injected automatically at session start. If you're switching
mid-session, read it now:

    cat ~/.claude/modes/build.md

Task: **$ARGUMENTS**

Proceed like this:

1. **Understand before planning.** Read the relevant code. Don't plan against
   assumptions about what's there.
2. **Plan, proportionally.** Enter plan mode for anything non-trivial and get
   agreement before editing. A small fix gets a sentence, not phases. State any
   assumption that would change the work if wrong.
3. **Implement in reviewable increments**, verifying as you go.
4. **Verify for real.** Run the build, run the tests, read the output, report what it
   actually said. Never a result you didn't observe. Never a SHA you didn't read.
   Delegate to the `verifier` agent if the surface is wide.
5. **Report**: what changed, what you verified and how, what you left alone.

Checkpoint on genuine design decisions and scope surprises. Make routine calls
yourself and mention them in passing.
