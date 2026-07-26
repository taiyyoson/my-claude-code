#!/usr/bin/env bash
# Stop hook. In autopilot mode only, append a factual record of what changed.
#
# The point is that this entry is machine-generated from git, so it cannot be
# wrong about the diff even if the session's prose is optimistic. A future
# session reading WORKLOG.md gets ground truth alongside the narrative.
#
# Never blocks. Always exits 0.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/mode.sh
source "$SCRIPT_DIR/lib/mode.sh"

cat >/dev/null 2>&1 || true   # drain stdin; we don't need it

mode=$(resolve_mode)
[[ "$mode" != "autopilot" ]] && exit 0

proj="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$proj" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

stat=$(git diff --stat 2>/dev/null)
staged=$(git diff --cached --stat 2>/dev/null)
untracked=$(git ls-files --others --exclude-standard 2>/dev/null | head -20)
recent=$(git log --oneline -5 2>/dev/null)

# Nothing happened — don't write a noise entry.
if [[ -z "$stat" && -z "$staged" && -z "$untracked" ]]; then
    exit 0
fi

log="$proj/WORKLOG.md"
if [[ ! -f "$log" ]]; then
    {
        printf '# Worklog\n\n'
        printf 'Autopilot-mode session records. Entries below the header are appended\n'
        printf 'automatically from git state at the end of each session — the diff stats\n'
        printf 'and commits are ground truth, not narrative.\n'
    } > "$log"
fi

{
    printf '\n---\n\n## %s\n\n' "$(date '+%Y-%m-%d %H:%M %Z')"
    printf 'Branch: `%s`\n\n' "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

    if [[ -n "$staged" ]]; then
        printf '**Staged**\n```\n%s\n```\n\n' "$staged"
    fi
    if [[ -n "$stat" ]]; then
        printf '**Unstaged**\n```\n%s\n```\n\n' "$stat"
    fi
    if [[ -n "$untracked" ]]; then
        printf '**Untracked**\n```\n%s\n```\n\n' "$untracked"
    fi
    if [[ -n "$recent" ]]; then
        printf '**Recent commits**\n```\n%s\n```\n' "$recent"
    fi
} >> "$log"

exit 0
