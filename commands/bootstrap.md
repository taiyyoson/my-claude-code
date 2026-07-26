---
description: Set up a repo for agentic work — project CLAUDE.md, permissions, mode
argument-hint: "[optional: what this project is]"
---

Start by surveying the repo:

    bash ~/.claude/scripts/repo-survey.sh

Project context, if given: **$ARGUMENTS**

Then set it up, based on what the survey actually reported — not on assumptions:

1. **Project `CLAUDE.md`** — if missing, write one. Keep it *short* and specific to
   what you cannot infer by reading the code: how to build, how to run tests, the
   non-obvious architectural decisions, project-specific conventions, known traps. Do
   not restate the directory structure or explain what the language is. If one exists,
   read it and suggest additions rather than rewriting.

2. **Project permissions** in `.claude/settings.json` — pre-allow the read-only and
   routine commands this project actually needs, drawn from the real build system and
   script targets the survey found. For Go: `go build`/`go test`/`go vet`. For Node:
   the actual scripts in `package.json`. Commit this file — it's project config, and
   it's the difference between a smooth session and twenty prompts.

3. **Mode** — set a sensible default for what this repo is for, via
   `bash ~/.claude/scripts/set-mode.sh <mode>`. Coursework where the user is learning
   gets `coach`. A project they're building gets `build`. Ask only if genuinely
   unclear; otherwise pick and say which you picked.

4. **Check `.gitignore`** covers `.claude/settings.local.json`. `.claude/.mode` is
   already handled by the global excludes file. If this repo will use autopilot,
   decide with the user whether `WORKLOG.md` is committed or ignored.

Report what you created and what you left alone.
