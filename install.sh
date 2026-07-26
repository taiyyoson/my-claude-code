#!/usr/bin/env bash
# Link this repo into ~/.claude and merge the settings fragment.
#
# Idempotent — safe to re-run after editing anything here. Backs up settings.json
# every time before touching it.
#
#   ./install.sh          install / re-sync
#   ./install.sh --dry    show what would change, touch nothing

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DRY=0
[[ "${1:-}" == "--dry" ]] && DRY=1

say()  { printf '  %s\n' "$*"; }
head_() { printf '\n%s\n' "$*"; }
run()  { if [[ $DRY -eq 1 ]]; then say "would: $*"; else "$@"; fi; }

command -v jq >/dev/null 2>&1 || { echo "error: jq is required." >&2; exit 1; }
mkdir -p "$CLAUDE_DIR"

# ---------------------------------------------------------------------------
# Whole-directory symlinks
#
# Safe because Claude Code owns none of these paths by default. If a real
# directory already exists we refuse rather than clobber it — losing someone's
# hand-written commands to an installer would be unforgivable.
# ---------------------------------------------------------------------------
head_ "Directories"
for d in output-styles commands agents scripts; do
    target="$CLAUDE_DIR/$d"
    src="$REPO/$d"
    if [[ -L "$target" ]]; then
        current="$(readlink "$target")"
        if [[ "$current" == "$src" ]]; then say "ok       $d (already linked)"; continue; fi
        say "relink   $d (was -> $current)"
        run rm "$target"
    elif [[ -d "$target" ]]; then
        if [[ -n "$(ls -A "$target" 2>/dev/null)" ]]; then
            say "SKIP     $d — real directory with contents already at $target"
            say "         move its files into $src, then re-run"
            continue
        fi
        run rmdir "$target"
        say "link     $d (replaced empty dir)"
    else
        say "link     $d"
    fi
    run ln -s "$src" "$target"
done

# ---------------------------------------------------------------------------
# Skills: link individually.
#
# A whole-directory symlink here would hide anything installed by other means —
# `npx skills` puts find-skills in ~/.claude/skills/ as its own symlink, and
# `claude plugin init` scaffolds there too. Per-item links coexist with those.
# ---------------------------------------------------------------------------
head_ "Skills (individual links, so plugin/npx-installed skills survive)"
mkdir -p "$CLAUDE_DIR/skills"
for src in "$REPO"/skills/*/; do
    [[ -d "$src" ]] || continue
    name="$(basename "$src")"
    target="$CLAUDE_DIR/skills/$name"
    src="${src%/}"
    if [[ -L "$target" && "$(readlink "$target")" == "$src" ]]; then
        say "ok       $name"
    elif [[ -e "$target" ]]; then
        say "SKIP     $name — something already exists at $target"
    else
        say "link     $name"
        run ln -s "$src" "$target"
    fi
done
if [[ -e "$CLAUDE_DIR/skills/find-skills" ]]; then
    say "ok       find-skills (installed separately, left alone)"
fi

# ---------------------------------------------------------------------------
# Global CLAUDE.md
# ---------------------------------------------------------------------------
head_ "Global CLAUDE.md"
target="$CLAUDE_DIR/CLAUDE.md"
if [[ -L "$target" && "$(readlink "$target")" == "$REPO/CLAUDE.md" ]]; then
    say "ok       already linked"
elif [[ -f "$target" && ! -L "$target" ]]; then
    say "SKIP     a real ~/.claude/CLAUDE.md exists — merge it into $REPO/CLAUDE.md, then re-run"
else
    [[ -L "$target" ]] && run rm "$target"
    say "link     CLAUDE.md"
    run ln -s "$REPO/CLAUDE.md" "$target"
fi

# ---------------------------------------------------------------------------
# Settings merge
#
# Only the keys this repo owns are touched: hooks (ours, matched by path) and the
# permissions allow/deny lists (union, deduped). Everything else in settings.json
# — model, effortLevel, enabledPlugins, statusLine — is preserved exactly.
# ---------------------------------------------------------------------------
head_ "settings.json"
settings="$CLAUDE_DIR/settings.json"
[[ -f "$settings" ]] || echo '{}' > "$settings"

if ! jq empty "$settings" 2>/dev/null; then
    echo "error: $settings is not valid JSON. Fix or move it, then re-run." >&2
    exit 1
fi

backup="$settings.bak-$(date +%Y%m%d-%H%M%S)"
if [[ $DRY -eq 0 ]]; then
    cp "$settings" "$backup"
    say "backup   $(basename "$backup")"
else
    say "would back up settings.json"
fi

merged=$(jq \
    --arg guard "$REPO/hooks/mode-guard.sh" \
    --arg worklog "$REPO/hooks/worklog.sh" \
    --slurpfile frag "$REPO/settings.fragment.json" \
'
  . as $cur
  | ($frag[0]) as $f
  # Drop any previously-installed copy of our own hooks (match on script path),
  # so re-running never stacks duplicates, then re-add at the current path.
  | .hooks.PreToolUse = (
      [ (($cur.hooks.PreToolUse // [])[]
         | select([.hooks[]?.command // "" | test("mode-guard\\.sh")] | any | not)) ]
      + [ { matcher: "*", hooks: [ { type: "command", command: ("\"" + $guard + "\"") } ] } ]
    )
  | .hooks.Stop = (
      [ (($cur.hooks.Stop // [])[]
         | select([.hooks[]?.command // "" | test("worklog\\.sh")] | any | not)) ]
      + [ { hooks: [ { type: "command", command: ("\"" + $worklog + "\"") } ] } ]
    )
  | .permissions.allow = (((.permissions.allow // []) + ($f.permissions.allow // [])) | unique)
  | .permissions.deny  = (((.permissions.deny  // []) + ($f.permissions.deny  // [])) | unique)
' "$settings")

if [[ $DRY -eq 1 ]]; then
    say "would write:"
    printf '%s\n' "$merged" | jq '{hooks, permissions}' | sed 's/^/    /'
else
    printf '%s\n' "$merged" > "$settings"
    jq empty "$settings" || { echo "merge produced invalid JSON; restoring" >&2; cp "$backup" "$settings"; exit 1; }
    say "merged   hooks + permissions"
fi

head_ "Done."
say "Restart Claude Code (or /clear) to pick up styles, commands, and agents."
say "Check with: /mode   and   /output-style"
[[ $DRY -eq 1 ]] && say "(dry run — nothing changed)"
exit 0
