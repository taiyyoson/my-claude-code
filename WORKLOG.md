# Worklog

Autopilot-mode session records. Entries below the header are appended
automatically from git state at the end of each session — the diff stats
and commits are ground truth, not narrative.

---

## 2026-07-26 00:28 PDT

Branch: `main`

**Staged**
```
 output-styles/autopilot.md | 90 ------------------------------------------------------
 output-styles/build.md     | 67 ----------------------------------------
 output-styles/coach.md     | 70 ------------------------------------------
 3 files changed, 227 deletions(-)
```

**Unstaged**
```
 README.md                          | 17 +++++++++++++----
 commands/autopilot.md              |  5 ++++-
 commands/build.md                  |  5 ++++-
 commands/coach.md                  |  6 ++++--
 docs/2026-07-25-setup-rationale.md | 31 +++++++++++++++++++++++++++++++
 install.sh                         | 13 ++++++++++---
 6 files changed, 66 insertions(+), 11 deletions(-)
```

**Untracked**
```
hooks/session-start.sh
modes/autopilot.md
modes/build.md
modes/coach.md
```

**Recent commits**
```
0ba02ec fixing mode errors with scripts symlinked to ~/.claude
bf683a6 Add MIT License to the project
a79c4e2 Version-controlled Claude Code setup with three working modes
dccef04 Delete LICENSE
2cf0a79 Initial commit
```
