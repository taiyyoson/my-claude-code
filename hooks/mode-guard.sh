#!/usr/bin/env bash
# PreToolUse guard.
#
# Two jobs:
#   1. Block genuinely irreversible operations in every mode. These are the blocks
#      that make a long autonomous leash defensible.
#   2. Enforce the active mode's boundary — specifically, coach mode means the user
#      writes the code.
#
# Contract: read hook JSON on stdin. To block, print a deny decision and exit 0.
# To allow, print nothing and exit 0. Never exit non-zero on an unexpected input —
# a crashing guard that fails closed would wedge every session.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/mode.sh
source "$SCRIPT_DIR/lib/mode.sh"

input=$(cat 2>/dev/null || true)
[[ -z "$input" ]] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

tool=$(jq -r '.tool_name // empty' <<<"$input" 2>/dev/null) || exit 0
mode=$(resolve_mode)

deny() {
    jq -n --arg r "$1" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $r
        }
    }'
    exit 0
}

# ---------------------------------------------------------------------------
# 1. Irreversible-operation guards — all modes, no exceptions
# ---------------------------------------------------------------------------

if [[ "$tool" == "Bash" ]]; then
    cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)

    # Recursive delete targeting a root or home path. Deliberately narrow: this
    # catches `rm -rf /`, `rm -rf ~`, `rm -rf $HOME` and slight spacing variants,
    # without blocking ordinary `rm -rf ./build`.
    if [[ "$cmd" =~ rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+)+(/|~|\$HOME|\"?\$HOME\"?)[[:space:]]*$ ]]; then
        deny "Blocked: recursive delete of a root or home path. If you meant a subdirectory, name it explicitly."
    fi

    case "$cmd" in
        *"git push --force"*|*"git push -f"*|*"push --force"*)
            deny "Blocked: force push rewrites published history. If this is genuinely needed, the user should run it themselves with --force-with-lease." ;;
        *"git reset --hard"*)
            deny "Blocked: 'git reset --hard' destroys uncommitted work irrecoverably. Use 'git stash' to set changes aside, or 'git restore <path>' for specific files." ;;
        *"git clean -fdx"*|*"git clean -xfd"*)
            deny "Blocked: 'git clean -fdx' deletes ignored files too, which often means real local config. Name the paths instead." ;;
        sudo\ *|*" sudo "*|*"|sudo "*)
            deny "Blocked: sudo. Nothing in normal development work needs root; if a tool genuinely does, the user should run it themselves." ;;
    esac

    # Piping a network fetch straight into a shell — arbitrary remote code.
    if [[ "$cmd" =~ (curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(bash|zsh|sh)([[:space:]]|$) ]]; then
        deny "Blocked: piping a network fetch into a shell executes unreviewed remote code. Download to a file, read it, then run it."
    fi
fi

# Credential material. Reading these is how a leaked secret leaves the machine.
# Note .env is intentionally NOT blocked — projects legitimately need it, and
# blocking it produces constant false positives.
if [[ "$tool" == "Read" || "$tool" == "Edit" || "$tool" == "Write" || "$tool" == "NotebookEdit" ]]; then
    path=$(jq -r '.tool_input.file_path // empty' <<<"$input" 2>/dev/null)
    case "$path" in
        */.ssh/*|*/.aws/*|*/.gnupg/*|*/.netrc|*id_rsa*|*id_ed25519*|*.pem|*/.config/gh/hosts.yml)
            deny "Blocked: '$path' is credential material. If you need a value from it, ask the user to supply it directly." ;;
    esac
fi

# ---------------------------------------------------------------------------
# 2. Mode boundary
# ---------------------------------------------------------------------------

if [[ "$mode" == "coach" ]]; then
    case "$tool" in
        Edit|Write|NotebookEdit)
            deny "Coach mode: the user writes the code, not you. Describe the scaffold precisely (path, signature, types), name the 5-10 lines where the real decision lives and explain the trade-off, or hand them a failing test to make pass. Do not ask them to disable this hook. If they want you to take the keyboard, tell them once that '/build' does that." ;;
    esac
fi

exit 0
