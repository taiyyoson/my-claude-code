# claude-init


| Putting this on Github for version control + others who might find it useful. It compiles a lot of cool existing skills and Claude Code setups into one super-up. It's my claude code setup.|


Version-controlled Claude Code configuration. This repo is the source of truth;
`~/.claude` holds symlinks into it.

    ./install.sh --dry     # show what would change
    ./install.sh           # install / re-sync (idempotent)

## Three modes

One command switches the working relationship for a repository. Mode is stored in
`<repo>/.claude/.mode`, so different projects can sit in different modes at once.

| | `/coach` | `/build` | `/autopilot` |
|---|---|---|---|
| Who writes the code | you | Claude | Claude |
| `Edit`/`Write` | **hook-blocked** | allowed | allowed |
| Planning | n/a | plan first, get agreement | decides and records |
| Delegation | none | `Explore`, `Plan`, `verifier` | full roster, worktree-isolated |
| On finishing | hints, review, failing tests | plan → diff → real test output | `WORKLOG.md` + notification |

`/mode` shows the active mode and what it permits. Default is `build`.

The behavioral frame for the active mode is injected at session start by
`hooks/session-start.sh`, so `/coach`, `/build`, or `/autopilot` is all you run — one
command, no second step.

This deliberately does *not* use `~/.claude/output-styles/`. That path did not prove
to be a working extension point in 2.1.220: no plugin on disk ships one, and
Anthropic's own `learning-output-style` and `explanatory-output-style` plugins both
inject via `SessionStart` instead. The hook is registered for `startup|clear|compact`
so the frame survives compaction — which matters most during long autopilot runs,
exactly when it would otherwise be silently lost.

## Layout

    CLAUDE.md                 global instructions — loaded every session, kept short
    modes/                    the three mode briefs, injected at session start
    commands/                 /coach /build /autopilot /mode /bootstrap
    scripts/                  set-mode, show-mode, repo-survey (called by commands)
    hooks/
      session-start.sh        SessionStart: injects the active mode's brief
      mode-guard.sh           PreToolUse: mode boundary + irreversible-op blocks
      worklog.sh              Stop: appends real git diff --stat in autopilot
      lib/mode.sh             shared mode resolution
      test-mode-guard.sh      29 cases — run after editing the guard
    agents/                   loaded globally: verifier, scribe, code-review-debugger
    agents-optional/          per-project only, no global context cost
    skills/                   vendored active skills (see NOTICE.md)
    reference/                study material, deliberately NOT auto-loaded
    modes-legacy/             earlier prompt-file experiments, kept for reference
    settings.fragment.json    permissions merged into ~/.claude/settings.json
    install.sh                symlinks + settings merge, idempotent

## What the guard blocks

In every mode, regardless: recursive deletes of root or home, `git push --force`,
`git reset --hard`, `git clean -fdx`, `sudo`, piping a network fetch into a shell,
and reads of credential material (`~/.ssh`, `~/.aws`, `~/.gnupg`, `*.pem`, `.netrc`).
`.env` is deliberately *not* blocked — too many false positives.

In coach mode additionally: `Edit`, `Write`, `NotebookEdit`.

These blocks are why autopilot can have a long leash. `permissions.deny` in
`settings.fragment.json` duplicates the worst of them as a second layer, since
`--bare` skips hooks entirely.

After changing `mode-guard.sh`, run `./hooks/test-mode-guard.sh`.

## Adding a machine

    git clone <this repo> ~/src/claude-init && cd ~/src/claude-init && ./install.sh

`install.sh` writes hook paths based on wherever the repo actually sits, so the
clone location doesn't have to match.

## Design notes

**Why vendored skills instead of plugins.** See `skills/NOTICE.md`. Short version:
the `superpowers` plugin injects a mandatory skill-invocation directive into every
session via a `SessionStart` hook, which flattens all three modes into one pipeline.
The skill bodies are good; the always-on mandate isn't.

**Why reference material isn't a skill.** See `reference/context-engineering/NOTICE.md`.
Skills cost tokens at every session start and fire on triggers. Essays you consult
occasionally should be read on demand.

**Why per-skill symlinks.** A whole-directory link on `~/.claude/skills` would hide
skills installed by `npx skills` or `claude plugin init`.

**Why the guard hook rather than only permission globs.** The hook sees full command
text, can explain *why* in a message the model actually reads, and can vary by mode.
Globs can't do any of that. Both are installed; the hook is the real one.
