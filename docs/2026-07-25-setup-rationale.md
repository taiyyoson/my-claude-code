# Setup rationale — 2026-07-25

Condensed record of the session that produced this repo: what the machine looked
like beforehand, what was found, what was decided and why. Kept because most of the
reasoning here is not recoverable from the resulting files.

Goal driving it: one portable setup, usable in any repo, supporting three distinct
working relationships, with room to scale to more agents and harnesses.

---

## 1. Starting state

Global config was effectively empty. `~/.claude/settings.json` was 176 bytes
(`model: opus`, `effortLevel: high`, two LSP plugins). No global `CLAUDE.md`, no
`commands/`, no `output-styles/`, no `hooks/`, no user-scope MCP. Two agents
(`code-review-debugger`, `react-native-developer`, ~18KB / ~917 tok) loaded into
every session including Go and C work where the RN one could never fire.

`~/src/claude-init` existed as four loose, uncommitted prompt files — hand-copied
into projects rather than installed.

Twelve project histories, ten project `.claude` dirs, five project `CLAUDE.md`s.
So: real usage, no global layer.

## 2. The lead finding

`claude-init/CLAUDE.md` — the prototype autonomous mode — was a chatbot-era prompt
that instructed the model to **fabricate verification**:

- "Provide full code for all new/changed files (proper code blocks)" → print code
  into chat instead of writing files
- "Realistic commit hash", "simulated logs", "screenshots as text descriptions",
  "Simulate realistic testing" → invent test results and SHAs
- "Never ask questions or notify user during execution. Work silently until 100%
  complete" + 17 mandatory phases → a runaway with no checkpoints
- Deploy and report a live URL as a default step

Handed to an agent with real tools this is the worst combination: it suppresses
actual execution *and* authorizes confident reporting of unverified work. Retired to
`modes-legacy/CLAUDE-autoexec-DEPRECATED.md`. The global `CLAUDE.md` now opens with
the inverse rule, and it is the first section for that reason.

The other three legacy files were sound and informed the modes:
`CLAUDE-student.md` (strict Socratic) and `CLAUDE-student-accelerate.md` (solutions
plus explanation) became Coach and Build; `CLAUDE-interview-oa.md` remains a useful
fourth mode orthogonal to the three.

## 3. Plugin audit

Six plugins had been installed at user scope. Measured with `claude plugin details`:

| Plugin | Skills | Always-on | Verdict |
|---|---|---|---|
| context-engineering | 17 | ~2,265 tok | disabled, 5 skills vendored to `reference/` |
| superpowers | 14 | ~688 tok *(really ~1.8k)* | disabled, 3 skills vendored to `skills/` |
| skill-creator | 1 | ~112 tok | kept — official, ships an eval harness |
| code-review | 1 | ~20 tok | kept — cheap |
| clangd-lsp | — | 0 | kept |
| rust-analyzer-lsp | — | 0 | kept |
| **gopls-lsp** | — | 0 | **added** — Go work with no Go LSP |

Result: ~2,953 → ~132 tok always-on.

Token count was never the real argument, though — 3k on a 1M window is noise. The
real arguments were trigger collision and behavioral override.

## 4. Why superpowers was disabled

Its `SessionStart` hook (`startup|clear|compact`) injects the entire
`using-superpowers` skill body into every session wrapped in
`<EXTREMELY_IMPORTANT>`:

> "If you think there is even a 1% chance a skill might apply… you ABSOLUTELY MUST
> invoke the skill. **YOU DO NOT HAVE A CHOICE.** This is not negotiable. You cannot
> rationalize your way out of this."
>
> "Invoke relevant or requested skills **BEFORE any response or action** — including
> clarifying questions, exploring the codebase, or checking files."
>
> "**Before entering plan mode:** if you haven't already brainstormed, invoke the
> brainstorming skill first."

Plus a "Red Flags" table built specifically to defeat proportionality judgment
("This is just a simple question" → "Questions are tasks. Check for skills.").

Three consequences:

1. **It collapses the three modes into one.** Mandatory skill invocation before
   clarifying questions destroys Coach mode's Socratic dialogue; forced brainstorming
   before plan mode turns every `/build` into a 3.6k-token ritual regardless of size.
2. **`plugin details` undercounted it** — the hook was reported as "harness-only —
   no model context cost", but a hook's *output* is model context. Real always-on
   is ~1.8k, not 688.
3. **Duplicate conflicts** — `writing-skills` vs `skill-creator`;
   `requesting`/`receiving-code-review` vs the `code-review` plugin vs the
   `code-review-debugger` agent; `using-git-worktrees` /
   `dispatching-parallel-agents` / `subagent-driven-development` vs native worktree
   isolation and the Agent tool.

The skill bodies are good. The always-on mandate is what had to go — hence vendoring
three of them (MIT) rather than enabling the plugin. See `skills/NOTICE.md`.

## 5. Decisions

| Decision | Reasoning |
|---|---|
| Config in a git repo symlinked into `~/.claude` | version history, rollback, one-command setup on a new machine |
| Modes as output styles + slash commands | `output-styles/` is the native switchable mode primitive and was unused |
| Mode state in `<repo>/.claude/.mode` | two repos can be in different modes at once; concurrent sessions in *one* repo do share it |
| Enforcement via `PreToolUse` hook, not prose | prose won't stop a capable model from helpfully writing someone's homework |
| `dontAsk` for autopilot, not `bypassPermissions` | suppresses prompts while keeping deny rules enforced — the controlled version of `--dangerously-skip-permissions` |
| Reference essays in `reference/`, unloaded | 5–8k tokens *per invocation*; paying always-on rent for occasional reading is the mistake the material itself warns about |
| Per-skill symlinks, not a whole-dir link | a dir link on `~/.claude/skills` would hide `npx skills` and `claude plugin init` installs |
| `react-native-developer` → `agents-optional/` | specialist agents shouldn't load into every session |
| Vendor rather than enable, for both heavyweights | `claude plugin disable` is whole-plugin only — there is no per-skill granularity |

## 6. What was built

Three modes — Coach (user writes the code, edits hook-blocked), Build (plan-first,
supervised), Autopilot (broad authority, delegation, worklog, self-verification) —
as output styles plus `/coach`, `/build`, `/autopilot`, `/mode`, `/bootstrap`.

`hooks/mode-guard.sh` blocks, in every mode: recursive deletes of root/home, force
push, `reset --hard`, `clean -fdx`, `sudo`, piping a network fetch into a shell, and
reads of credential paths. `.env` deliberately not blocked — too many false
positives. Coach mode additionally blocks `Edit`/`Write`/`NotebookEdit`. Those
blocks are what makes a long autonomous leash defensible, which is why the styles
tell the model to find a safe equivalent rather than route around one.

`hooks/worklog.sh` appends a real `git diff --stat` to `WORKLOG.md` in autopilot
mode — machine-generated, so it can't be wrong about the diff even if the session's
prose is optimistic.

`hooks/test-mode-guard.sh` — 29 cases, all passing. Caught one real bug: the
`curl|sh` detector used `(ba|z|)sh`, and POSIX ERE has no empty alternative, so both
pipe-to-shell cases silently allowed. Run it after editing the guard.

Agents: `verifier` (runs builds/tests, **no edit tools**, so it cannot turn a failure
into a pass; `INCONCLUSIVE` is a first-class verdict) and `scribe` (write-ups grounded
in git evidence, never laundering an unverified claim into documentation).

## 6b. Two mechanisms that had to be replaced after first install

Both were cases of building on an assumed extension point instead of a verified one.

**Slash-command `!` blocks cannot contain shell expansions.** Command bodies are
*statically* permission-checked, so `${CLAUDE_PROJECT_DIR:-$PWD}` was rejected with
"Contains expansion", and `${...}` inside a quoted string with the stricter "brace
with quote character (expansion obfuscation)". All five commands failed identically.
Fix: move the logic into `scripts/{set-mode,show-mode,repo-survey}.sh` and have the
command invoke one verifiable thing — which is exactly what the official `ralph-loop`
plugin does, and which had been read earlier without the lesson being drawn.

**`~/.claude/output-styles/*.md` is not a working extension point in 2.1.220.** The
three mode styles never registered. `--safe-mode` does list "output styles" as a
customization category, so the concept exists somewhere — but no plugin on disk ships
an `output-styles/` directory, and Anthropic's own `learning-output-style` and
`explanatory-output-style` plugins both inject via a `SessionStart` hook instead. One
of their manifests describes itself as mimicking the "*unshipped* Learning output
style", which was the clue.

Replaced with `hooks/session-start.sh`, which reads the active mode and injects
`modes/<mode>.md` as `additionalContext`. Strictly better than what was planned:
one command activates a mode instead of two, and registering for
`startup|clear|compact` means the frame survives compaction — which matters most
during long autopilot runs, precisely when losing it would be least visible.

**Platform note:** macOS ships bash 3.2.57. `${var^}` (case modification) is bash 4+
and failed at runtime. Earlier, `(ba|z|)sh` failed because POSIX ERE has no empty
alternative. Both were caught by running the scripts rather than reading them. All
hooks and scripts are now audited clean of bash-4-only constructs.

## 7. Tooling facts worth remembering

- `--permission-mode` accepts six values: `acceptEdits`, `auto`, `bypassPermissions`,
  `manual`, `dontAsk`, `plan`.
- `claude plugin details <name>` gives component inventory *and projected token cost*
  — but only for **installed** plugins, and it does not count hook-injected context.
- `claude plugin eval` scores a plugin against eval cases with a no-plugin baseline.
- `claude plugin init <name>` scaffolds at `~/.claude/skills/<name>/`, auto-loading as
  `<name>@skills-dir` — the native way to package this setup if it stabilizes.
- `claude plugin disable` is whole-plugin only. No per-skill disable.
- `--bare` skips hooks entirely, which is why `permissions.deny` duplicates the worst
  guard rules as a second layer.
- The official marketplace has ~39 plugins including `learning-output-style`,
  `session-report`, `ralph-loop`, `hookify`, `claude-md-management`, and LSPs for most
  languages. Worth checking before reaching for a third-party pack.
- `learning-output-style`'s hook has **no matcher**, so enabling it injects
  unconditionally — it can't be one mode among three. Its content was folded into
  `output-styles/coach.md` instead. Its scaffold-then-hand-over pattern (prepare the
  file, leave a TODO, ask for the 5–10 lines that carry the decision) is better than
  pure Socratic refusal, which risks reading as gatekeeping.
- `ralph-loop` is the brute-force loop (Stop hook re-feeds the same prompt). Built-in
  `/loop` self-paces and is preferable.

## 8. State at end of session — installed and verified

All installed. Verified directly:

- `~/.claude/{CLAUDE.md,output-styles,commands,agents}` symlink into this repo;
  the three vendored skills link individually and `find-skills` survived, which was
  the point of not linking the whole directory.
- `settings.json` carries both hooks at absolute repo paths, 60 allow rules, 10 deny
  rules — and `model`, `effortLevel`, `enabledPlugins` came through the merge intact.
  Backup at `settings.json.bak-20260725-231245`.
- `hooks/test-mode-guard.sh`: 29/29.
- **Live end-to-end**: with a repo in coach mode, a real `Write` through the harness
  was refused with the guard's own message, and the file was never created. The block
  is real, not advisory.
- Stale npm `@anthropic-ai/claude-code@2.0.8` removed. `claude` resolves only to
  `~/.local/bin/claude` → 2.1.220 (native installer, independent of npm).

One process note worth keeping: the first live test appeared to show the guard
failing open. It hadn't — the `.mode` file had been written into the wrong repo,
because two `Bash` calls issued in the same batch share a working directory and a
`cd` in the first one moved the second. The guard had correctly resolved no mode
file → default `build` → allow. Use absolute paths when writing mode state.

`docs/` and the `.mode` files are the only things outside version control by design:
mode state is per-checkout runtime state, ignored via `.gitignore`.
