#!/usr/bin/env bash
# Set the working mode for a repository.
#
#   set-mode.sh coach|build|autopilot [project-dir]
#
# Lives in a script rather than inline in the slash command because command `!`
# blocks are statically permission-checked and reject shell expansions. Scripts
# can use them freely.

set -uo pipefail

mode="${1:-}"
proj="${2:-${CLAUDE_PROJECT_DIR:-$PWD}}"

case "$mode" in
    coach|build|autopilot) ;;
    *)
        echo "usage: set-mode.sh coach|build|autopilot [project-dir]" >&2
        exit 2 ;;
esac

mkdir -p "$proj/.claude" || { echo "error: cannot create $proj/.claude" >&2; exit 1; }
printf '%s' "$mode" > "$proj/.claude/.mode" || { echo "error: cannot write mode file" >&2; exit 1; }

echo "mode -> $mode"
echo "repo:    $proj"

case "$mode" in
    coach)
        echo "Edit/Write/NotebookEdit are now BLOCKED in this repo." ;;
    build)
        echo "Edits allowed. Plan first for non-trivial work." ;;
    autopilot)
        echo "Edits allowed, broad authority. WORKLOG.md appended on stop." ;;
esac

echo "Irreversible-operation guards stay active in every mode."

if git -C "$proj" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "branch:  $(git -C "$proj" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    n=$(git -C "$proj" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    echo "tree:    $n uncommitted change(s)"
else
    echo "note:    not a git repo — no worklog diff and no rollback"
fi
