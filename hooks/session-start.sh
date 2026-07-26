#!/usr/bin/env bash
# SessionStart hook. Injects the active mode's brief as additional context.
#
# This is how the mode frame actually reaches the model. User-authored
# ~/.claude/output-styles/*.md did not prove to be a working extension point in
# 2.1.220 — no plugin on disk ships one, and Anthropic's own learning-output-style
# and explanatory-output-style plugins both inject via SessionStart instead. So we
# do the same, which also means one command activates a mode rather than two.
#
# Registered for startup|clear|compact so the frame survives compaction — important
# for long autopilot runs, which are exactly when it would otherwise be lost.
#
# Never blocks. Emits nothing on any problem rather than risking a broken session.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/mode.sh
source "$SCRIPT_DIR/lib/mode.sh"

cat >/dev/null 2>&1 || true   # drain stdin

command -v jq >/dev/null 2>&1 || exit 0

mode=$(resolve_mode)
brief="$REPO/modes/$mode.md"
[[ -r "$brief" ]] || exit 0

body=$(cat "$brief" 2>/dev/null) || exit 0
[[ -z "$body" ]] && exit 0

# Display name. Written out rather than using ${mode^} — macOS ships bash 3.2,
# which has no case-modification expansion.
case "$mode" in
    coach)     title="Coach" ;;
    build)     title="Build" ;;
    autopilot) title="Autopilot" ;;
    *)         title="$mode" ;;
esac

header="The user has this repository in $title mode. The working agreement below \
applies for this session. A PreToolUse hook enforces its boundaries, so treat a \
blocked tool call as the boundary working, not as an obstacle. Run /mode to report \
the active mode; /coach, /build, or /autopilot to change it."

jq -n --arg m "$mode" --arg h "$header" --arg b "$body" '
  {
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: ("<working-mode name=\"" + $m + "\">\n" + $h + "\n\n" + $b + "\n</working-mode>")
    }
  }'

exit 0
