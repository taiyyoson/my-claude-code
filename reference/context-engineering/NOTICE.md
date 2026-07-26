# Context engineering reference material

Vendored from `muratcankoylan/Agent-Skills-for-Context-Engineering`
(MIT, Copyright (c) 2025 Context Engineering Agent Skills Contributors).

Upstream: https://github.com/muratcankoylan/Agent-Skills-for-Context-Engineering

## Why these live in `reference/` and not `skills/`

This directory is **not** symlinked into `~/.claude/skills/`, so nothing here
loads or auto-triggers. That is intentional.

The full plugin ships 17 skills costing ~2,265 tokens always-on, and each
individual skill costs ~5–8k tokens *per invocation* — they are essays, not
workflows. Paying always-on rent for reference material you consult occasionally
is exactly the mistake the material itself warns about. Two or three firing
spuriously burns ~20k tokens on background reading.

So: read these deliberately when studying the topic, not by trigger.

    Read ~/src/claude-init/reference/context-engineering/context-fundamentals/SKILL.md

## What was kept

| Skill | Use it for |
|---|---|
| `context-fundamentals` | the baseline mental model — attention budget, what belongs in context |
| `context-compression` | long-running sessions, what to summarize and what to drop |
| `multi-agent-patterns` | context isolation across delegated agents; when to fan out |
| `harness-engineering` | designing autonomous loops and their stopping conditions |
| `memory-systems` | cross-session persistence, semantic recall |

## What was dropped, and why

`advanced-evaluation`, `bdi-mental-states`, `context-degradation`,
`context-optimization`, `evaluation`, `filesystem-context`, `hosted-agents`,
`latent-briefing`, `long-horizon-prompting`, `project-development`,
`self-improvement-loops`, `tool-design`.

Mostly research-oriented or overlapping with the five above. Nothing stops you
adding one back — re-enable the plugin with
`claude plugin enable context-engineering@context-engineering-marketplace`
and copy what you want. The marketplace stays registered.
