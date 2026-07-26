# Optional agents — not loaded globally

Agents in this directory are **not** symlinked into `~/.claude/agents/`, so they cost
nothing at session start. They live here to be enabled per project.

## Why anything is here

Every agent definition in `~/.claude/agents/` has its name and description loaded
into the context of *every* session, in every repository. That's the right trade for
an agent you use across most projects. It's the wrong trade for a specialist.

`react-native-developer.md` was loading into Go, C, and coursework sessions where it
could never fire. It is genuinely useful — in a React Native project.

## Enabling one for a project

    mkdir -p .claude/agents
    ln -s ~/src/claude-init/agents-optional/react-native-developer.md .claude/agents/

Commit the symlink if the whole team should have it; add it to `.gitignore` if it's
just for you. Either way it now loads only where it's relevant.

## Promoting one to global

Move it to `../agents/` and re-run `install.sh`. Do that when you notice you're
symlinking it into most new projects anyway.
