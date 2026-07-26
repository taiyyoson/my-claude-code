---
description: Set up a repo for agentic work — project CLAUDE.md, permissions, mode
argument-hint: "[optional: what this project is]"
---

```!
PROJ="${CLAUDE_PROJECT_DIR:-$PWD}"
echo "repo: $PROJ"
cd "$PROJ" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo "git: yes ($(git rev-parse --abbrev-ref HEAD))" || echo "git: NO"
[ -f CLAUDE.md ] && echo "CLAUDE.md: exists ($(wc -l < CLAUDE.md | tr -d ' ') lines)" || echo "CLAUDE.md: missing"
[ -f .claude/settings.json ] && echo ".claude/settings.json: exists" || echo ".claude/settings.json: missing"
[ -f .claude/settings.local.json ] && echo ".claude/settings.local.json: exists" || echo ".claude/settings.local.json: missing"
echo "--- language signals ---"
ls go.mod package.json Cargo.toml pyproject.toml requirements.txt Makefile CMakeLists.txt pom.xml build.gradle 2>/dev/null || echo "(none at top level)"
```

Project context, if given: **$ARGUMENTS**

Set this repo up for agentic work. Read the signals above first, then:

1. **Project `CLAUDE.md`** — if missing, write one. Keep it *short* and specific to
   things you cannot infer from reading the code: how to build, how to run tests,
   the non-obvious architectural decisions, project-specific conventions, known
   traps. Do not restate the directory structure or explain what the language is.
   If one already exists, read it and suggest additions rather than rewriting.

2. **Project permissions** in `.claude/settings.json` — pre-allow the read-only and
   routine commands this project actually needs, so the mode guard and permission
   prompts stay out of the way. Base this on the real build system above, not
   guesswork: for Go, `go build`/`go test`/`go vet`; for Node, the actual scripts in
   `package.json`; and so on. Commit this file — it's project config, and it's the
   difference between a smooth session and twenty prompts.

3. **Mode** — set a sensible default for what this repo is for. Coursework where the
   user is learning gets `coach`. A project they're building gets `build`. Ask if
   it's genuinely unclear; otherwise pick and say which you picked.

4. **Check `.gitignore`** covers `.claude/settings.local.json` and, if this repo will
   use autopilot, decide with the user whether `WORKLOG.md` is committed or ignored.

Report what you created and what you left alone.
