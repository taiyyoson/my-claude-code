#!/usr/bin/env bash
# PreToolUse guard.
#
# Three jobs:
#   1. Block genuinely irreversible operations in every mode. These are the blocks
#      that make a long autonomous leash defensible.
#   2. Enforce the active mode's boundary — specifically, coach mode means the user
#      writes the code.
#   3. Pre-approve work that is plainly safe, so the prompts you do see mean
#      something. Settings globs cannot do this job: they match as a prefix over the
#      whole command string, so `cd x && cat y` matches no rule no matter how many
#      you add. This hook sees the parsed command and can check each segment.
#
# Contract: read hook JSON on stdin. Print a deny or allow decision and exit 0, or
# print nothing to fall through to the normal permission flow. Never exit non-zero
# on an unexpected input — a crashing guard that fails closed would wedge every
# session.
#
# Ordering is load-bearing: an "allow" decision bypasses the settings deny list, so
# every guard below must run before any allow is emitted.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/mode.sh
source "$SCRIPT_DIR/lib/mode.sh"

input=$(cat 2>/dev/null || true)
[[ -z "$input" ]] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

tool=$(jq -r '.tool_name // empty' <<<"$input" 2>/dev/null) || exit 0
mode=$(resolve_mode)

decide() { # verdict  reason
    jq -n --arg d "$1" --arg r "$2" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: $d,
            permissionDecisionReason: $r
        }
    }'
    exit 0
}

deny()  { decide deny  "$1"; }
allow() { decide allow "$1"; }

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
    path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input" 2>/dev/null)
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

# ---------------------------------------------------------------------------
# 3. Pre-approval — everything above has already had its say
# ---------------------------------------------------------------------------

# Read-only shell. A command qualifies only if every segment of it does, so one
# unrecognised word anywhere means the whole thing goes to a prompt. Falling
# through costs one prompt; a wrong allow costs a file.

readonly_word() { # first word of a segment, plus its args
    local w="$1"; shift
    case "$w" in
        cat|head|tail|ls|find|tree|wc|file|stat|du|df|basename|dirname|realpath|readlink) return 0 ;;
        rg|grep|egrep|fgrep|ag|comm|diff|sort|uniq|cut|column|fold|nl|tr|xxd|od) return 0 ;;
        echo|printf|pwd|cd|true|false|test|date|uname|whoami|hostname|nproc|id|sleep) return 0 ;;
        jq|yq|which|type|command|env|locale|tput) return 0 ;;
        # sed and awk read happily, but `sed -i` edits in place.
        sed)  [[ " $* " == *" -i "* || " $* " == *" -i."* ]] && return 1; return 0 ;;
        awk|gawk) return 0 ;;
        git)
            case "${1:-}" in
                status|diff|log|show|branch|blame|rev-parse|ls-files|ls-tree|describe|shortlog|cat-file|for-each-ref|remote|tag|reflog|whatchanged|grep) return 0 ;;
                stash)     [[ "${2:-}" == "list" || "${2:-}" == "show" ]] && return 0; return 1 ;;
                worktree)  [[ "${2:-}" == "list" ]] && return 0; return 1 ;;
                config)    [[ " $* " == *" --get"* || " $* " == *" --list"* ]] && return 0; return 1 ;;
                *) return 1 ;;
            esac ;;
        go)
            case "${1:-}" in version|env|list|doc|vet|fmt) return 0 ;; *) return 1 ;; esac ;;
        cargo)
            case "${1:-}" in check|clippy|tree|metadata) return 0 ;; *) return 1 ;; esac ;;
        gh)
            case "${2:-}" in view|list|status|diff) return 0 ;; *) return 1 ;; esac ;;
        npm)
            case "${1:-}" in ls|view|list|outdated|-v|--version) return 0 ;; *) return 1 ;; esac ;;
        node|python|python3|deno|bun|rustc|gcc|g++|clang|make|brew|claude|docker|kubectl|terraform)
            # Version and help probes only — these all have destructive subcommands.
            case " $* " in *" --version "*|*" -v "*|*" --help "*|*" -h "*|*" version "*) return 0 ;; esac
            return 1 ;;
        *) return 1 ;;
    esac
}

readonly_command() { # full command string
    local cmd="$1" seg

    # Discard redirects write nothing, and they are on the majority of real
    # commands (47 of 50 redirects in this machine's transcripts were >/dev/null
    # or 2>&1). Scrub those first so the redirect bail below stays strict about
    # the redirects that actually create a file.
    local norm
    norm=$(printf '%s' "$cmd" | sed -E 's/[0-9]*>&[0-9]+//g; s/&?[0-9]*>[[:space:]]*\/dev\/null//g') || return 1

    # Anything that can still redirect, substitute, background, or span lines is
    # out of scope for this parser. Bailing here is what makes the segment split
    # below trustworthy.
    case "$norm" in
        *'>'*|*'<'*|*'`'*|*'$('*|*$'\n'*) return 1 ;;
    esac

    norm=${norm//&&/$'\n'}
    norm=${norm//||/$'\n'}
    norm=${norm//|/$'\n'}
    norm=${norm//;/$'\n'}

    while IFS= read -r seg; do
        # shellcheck disable=SC2206  # deliberate word splitting
        local words=($seg)
        [[ ${#words[@]} -eq 0 ]] && continue
        [[ "$seg" == *"&"* ]] && return 1      # leftover single & — backgrounding
        # Strip leading VAR=value assignments.
        while [[ ${#words[@]} -gt 0 && "${words[0]}" == [A-Za-z_]*=* ]]; do
            words=("${words[@]:1}")
        done
        [[ ${#words[@]} -eq 0 ]] && continue
        readonly_word "${words[@]}" || return 1
    done <<<"$norm"

    return 0
}

if [[ "$tool" == "Bash" ]]; then
    cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)
    if [[ -n "$cmd" ]] && readonly_command "$cmd"; then
        allow "Read-only shell command; every segment is on the guard's inspection-only list."
    fi
fi

case "$tool" in
    Read|Glob|Grep|WebSearch)
        allow "Inspection-only tool. Credential paths are already denied above." ;;
esac

# Autopilot writes inside the project it was pointed at. Outside that tree — your
# dotfiles, another checkout, /etc — it still asks, because the whole basis for the
# long leash is that the blast radius equals the repo.
if [[ "$mode" == "autopilot" ]]; then
    case "$tool" in
        Edit|Write|NotebookEdit)
            proj="${CLAUDE_PROJECT_DIR:-$PWD}"
            path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input" 2>/dev/null)
            if [[ -n "$path" && "$path" != *".."* && "$path" == "$proj"/* ]]; then
                allow "Autopilot mode, path is inside the project tree."
            fi ;;
    esac
fi

exit 0
