#!/usr/bin/env bash
# Report the active mode and what it permits.
#
#   show-mode.sh [project-dir]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
proj="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"

mode=""
src=""
if [[ -r "$proj/.claude/.mode" ]]; then
    mode=$(tr -d '[:space:]' < "$proj/.claude/.mode" 2>/dev/null)
    src="project ($proj/.claude/.mode)"
fi
if [[ -z "$mode" && -r "$HOME/.claude/.mode" ]]; then
    mode=$(tr -d '[:space:]' < "$HOME/.claude/.mode" 2>/dev/null)
    src="user (~/.claude/.mode)"
fi
case "$mode" in
    coach|build|autopilot) ;;
    "") mode="build"; src="default (no mode file)" ;;
    *)  src="INVALID value in ${src:-mode file} — falling back"; mode="build" ;;
esac

echo "mode:   $mode"
echo "source: $src"
echo "repo:   $proj"
echo

case "$mode" in
    coach)     echo "Edit/Write/NotebookEdit:  BLOCKED — the user writes the code" ;;
    build)     echo "Edit/Write/NotebookEdit:  allowed, plan-first expected" ;;
    autopilot) echo "Edit/Write/NotebookEdit:  allowed, broad authority, worklog on stop" ;;
esac

echo "Always blocked:           rm -rf of root/home, force push, reset --hard,"
echo "                          clean -fdx, sudo, curl|sh, credential paths"
echo
echo "switch: /coach   /build   /autopilot"

# Warn loudly if the guard isn't actually wired — otherwise the modes above are
# just prose and nothing enforces them.
if command -v jq >/dev/null 2>&1 && [[ -r "$HOME/.claude/settings.json" ]]; then
    if ! jq -e '[.hooks.PreToolUse[]?.hooks[]?.command // ""
                 | test("mode-guard\\.sh")] | any' \
            "$HOME/.claude/settings.json" >/dev/null 2>&1; then
        echo
        echo "WARNING: mode-guard.sh is not registered in ~/.claude/settings.json."
        echo "         Nothing is enforcing the boundary. Run install.sh."
    fi
fi
