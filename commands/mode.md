---
description: Show the active mode and what it permits
---

```!
PROJ="${CLAUDE_PROJECT_DIR:-$PWD}"
MODE=""
SRC=""
if [ -r "$PROJ/.claude/.mode" ]; then MODE=$(tr -d '[:space:]' < "$PROJ/.claude/.mode"); SRC="project ($PROJ/.claude/.mode)"; fi
if [ -z "$MODE" ] && [ -r "$HOME/.claude/.mode" ]; then MODE=$(tr -d '[:space:]' < "$HOME/.claude/.mode"); SRC="user (~/.claude/.mode)"; fi
if [ -z "$MODE" ]; then MODE="build"; SRC="default (no mode file)"; fi
echo "mode:   $MODE"
echo "source: $SRC"
echo
case "$MODE" in
  coach)     echo "Edit/Write/NotebookEdit: BLOCKED — you write the code" ;;
  build)     echo "Edit/Write/NotebookEdit: allowed, plan-first expected" ;;
  autopilot) echo "Edit/Write/NotebookEdit: allowed, broad authority, worklog on stop" ;;
esac
echo "Always blocked: rm -rf of root/home, force push, reset --hard, clean -fdx, sudo, curl|sh, credential paths"
echo
echo "switch: /coach  |  /build  |  /autopilot"
```

Report the mode above to the user plainly. If they asked to *change* mode rather
than inspect it, point them at the right command rather than editing the file
yourself.
