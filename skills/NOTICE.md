# Third-party skills

These skills are vendored from other projects, not written here.

## From `obra/superpowers` (MIT, Copyright (c) 2025 Jesse Vincent)

- `systematic-debugging/` — four-phase root cause analysis
- `test-driven-development/` — RED-GREEN-REFACTOR discipline
- `verification-before-completion/` — don't claim done without evidence

Vendored from superpowers 6.2.0 rather than installed as a plugin, deliberately.
The plugin ships a `SessionStart` hook that injects its `using-superpowers` skill
into every session wrapped in `<EXTREMELY_IMPORTANT>`, mandating skill invocation
"BEFORE any response or action — including clarifying questions" and requiring
brainstorming before plan mode. That is a global behavioral override: it collapses
coach / build / autopilot into one heavyweight pipeline and pre-empts any judgment
about proportionality. These three skill bodies are the parts worth having, and
they work fine on demand without the mandate.

Local modifications: `superpowers:`-namespaced cross-references were rewritten to
plain skill names (the namespace no longer resolves once vendored), and the
reference to the `writing-skills` skill now points at `skill-creator`, which is
the plugin actually installed here.

Upstream: https://github.com/obra/superpowers

## Updating

These are vendored copies and will not update themselves. To refresh, re-add the
marketplace, install the plugin to a temp scope, copy the skill directories, then
re-apply the modifications above. Check upstream occasionally rather than never —
`systematic-debugging` in particular is actively developed.
