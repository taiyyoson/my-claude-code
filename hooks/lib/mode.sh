#!/usr/bin/env bash
# Shared mode resolution. Source this; don't execute it.
#
# Precedence: project .claude/.mode  >  user ~/.claude/.mode  >  "build"
#
# Project-scoped state is deliberate: two repos can sit in different modes at the
# same time. Two concurrent sessions in the SAME repo do share it, so a background
# autopilot run and a foreground coach session in one checkout will fight. Use
# separate worktrees if you need that.

resolve_mode() {
    local proj mode=""
    proj="${CLAUDE_PROJECT_DIR:-$PWD}"

    if [[ -r "$proj/.claude/.mode" ]]; then
        mode=$(tr -d '[:space:]' < "$proj/.claude/.mode" 2>/dev/null)
    fi
    if [[ -z "$mode" && -r "$HOME/.claude/.mode" ]]; then
        mode=$(tr -d '[:space:]' < "$HOME/.claude/.mode" 2>/dev/null)
    fi

    case "$mode" in
        coach|build|autopilot) printf '%s' "$mode" ;;
        *)                     printf 'build' ;;
    esac
}
