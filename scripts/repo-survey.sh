#!/usr/bin/env bash
# Report what a repo looks like, for /bootstrap to act on.
#
#   repo-survey.sh [project-dir]

set -uo pipefail

proj="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
cd "$proj" 2>/dev/null || { echo "error: cannot enter $proj" >&2; exit 1; }

echo "repo: $proj"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "git:  yes ($(git rev-parse --abbrev-ref HEAD 2>/dev/null))"
    echo "      $(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') uncommitted change(s)"
    echo "      $(git log --oneline 2>/dev/null | wc -l | tr -d ' ') commit(s)"
else
    echo "git:  NO"
fi

echo
echo "--- agentic config ---"
for f in CLAUDE.md .claude/settings.json .claude/settings.local.json .gitignore WORKLOG.md; do
    if [[ -f "$f" ]]; then
        printf '%-30s exists (%s lines)\n' "$f" "$(wc -l < "$f" | tr -d ' ')"
    else
        printf '%-30s missing\n' "$f"
    fi
done

if [[ -r .claude/.mode ]]; then
    echo "mode:                          $(tr -d '[:space:]' < .claude/.mode)"
else
    echo "mode:                          unset (defaults to build)"
fi

echo
echo "--- build system signals ---"
found=0
for f in go.mod package.json Cargo.toml pyproject.toml requirements.txt setup.py \
         Makefile CMakeLists.txt pom.xml build.gradle Gemfile composer.json; do
    [[ -f "$f" ]] && { echo "  $f"; found=1; }
done
[[ $found -eq 0 ]] && echo "  (none at top level)"

echo
echo "--- test/script targets ---"
if [[ -f package.json ]] && command -v jq >/dev/null 2>&1; then
    jq -r '.scripts // {} | to_entries[] | "  npm run \(.key)"' package.json 2>/dev/null | head -12
fi
if [[ -f Makefile ]]; then
    grep -E '^[a-zA-Z0-9_.-]+:' Makefile 2>/dev/null | cut -d: -f1 | sed 's/^/  make /' | head -12
fi
