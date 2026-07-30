# Agentic Roblox Development Workflow

Procedural reference for running Roblox Studio development with Claude Code as the
primary authoring agent.

**Read this yourself.** For the rules the *agent* needs, see `CLAUDE.md` — that file
gets loaded into every session and should stay short.

---

## Phase 0 — Environment setup (one time per machine)

### 1. Toolchain manager

Rokit pins tool versions in `rokit.toml` so every machine gets identical builds.

**Windows (PowerShell):**
```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```

**macOS / Linux:**
```bash
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```

Restart your shell afterward so `~/.rokit/bin` lands on PATH. Verify with `rokit --version`.

Rokit is drop-in compatible with existing `aftman.toml` / `foreman.toml` files, so older
tutorials still apply.

### 2. Project tools

From the project directory:

```bash
rokit add rojo-rbx/rojo
rokit add JohnnyMorganz/StyLua
rokit add Kampfkarren/selene
rokit install
```

Commit `rokit.toml` and `rokit.lock`.

### 3. Rojo Studio plugin

The CLI is only half of Rojo — Studio needs the plugin to receive syncs.

```bash
rojo plugin install
```

Rojo ships a separate plugin per major version. **Plugin version must match CLI version** —
mismatches produce confusing connection failures that look like network problems.

### 4. Project scaffold

```bash
rojo init
```

Target layout:

```
src/
  server/     → ServerScriptService
  client/     → StarterPlayer/StarterPlayerScripts
  shared/     → ReplicatedStorage
default.project.json
rokit.toml
CLAUDE.md
WORKFLOW.md
.gitattributes
.gitignore
```

### 5. Sync + sourcemap running

Two terminals, left running during development:

```bash
rojo serve
rojo sourcemap --watch --output sourcemap.json
```

Then in Studio: **Plugins → Rojo → Connect**.

### 6. Luau LSP

Install the Luau LSP extension in your editor and point it at `sourcemap.json`. This is the
single highest-leverage step in the setup — it gives the agent real type errors on instance
paths instead of runtime `attempt to index nil` surprises. Pair with `--!strict` everywhere.

### 7. Studio beta features

**File → Beta Features.** Agentic playtest and generation features land here before GA.

### 8. Studio MCP server

- Assistant → **…** → **Manage MCP Servers**
- Enable **Studio as MCP server**
- Expand **Quick connect**, toggle on Claude Code
- Confirm the green indicator showing connected client count

If quick connect doesn't list your client, install it and restart Studio. If you need manual
JSON config, copy it from the Studio settings panel — it displays the correct config per
client and per OS. Don't hand-write paths.

Manual Windows fallback:
```json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "cmd.exe",
      "args": ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]
    }
  }
}
```

Do **not** run the client in WSL. The server binary is a Windows path on stdio; interop
buys nothing and breaks often.

### 9. Git

```bash
git init
```

`.gitattributes` on day one:
```
* text=auto eol=lf
*.rbxl binary
*.rbxm binary
*.rbxmx binary
```

`.gitignore`:
```
sourcemap.json
*.rbxl
*.rbxl.lock
```

Commit the empty scaffold. That commit is your undo button for everything that follows.

### 10. Define the Rojo/Studio boundary — the step people skip

You now have two writable surfaces: **files on disk** (Rojo → Studio) and the **live data
model** (MCP `multi_edit` → Studio).

If the agent edits a script through MCP that Rojo also manages, the next sync silently
overwrites it. Lost work, no error, no conflict marker.

**The rule: scripts live in files, everything else lives in the place.**

The split is by *what is being authored*, not by which tool is convenient:

- **All Luau → `src/`**, authored on disk. Never through MCP — with `rojo serve` running,
  the next sync overwrites it silently.
- **Terrain, models, hand-positioned UI, lighting → the `.rbxl`**, authored directly
  through MCP (or by hand, or by Studio Assistant). These have no file representation, so
  the filesystem path isn't available even in principle.

The efficiency argument for authoring scripts in Studio doesn't survive contact with the
facts: Rojo already pushes file edits into Studio in under a second. What you'd trade away
isn't speed, it's git history, `stylua`/`selene`, and sourcemap typechecking.

Place edits are *not* version-controlled — the `.rbxl` is binary and gitignored. Whatever
changes there, the agent should say so explicitly, because git won't record it.

This rule is restated in `CLAUDE.md`. Do not let it drift.

---

## Phase 1 — The per-feature loop

One feature per cycle. Resist batching.

### 1. Plan mode, always
Start in plan mode. Describe the feature, let the agent read the repo and propose an
approach before it writes anything. Reject and re-prompt if the plan is wrong — ten seconds
versus twenty minutes of unwinding.

### 2. Branch
```bash
git checkout -b feat/stamina
```
Cheap, and it makes step 7 free.

### 3. Author on disk
The agent edits files in `src/`. Rojo pushes to Studio automatically. It should **not** be
calling `multi_edit`.

### 4. Verify through MCP
This is where the MCP tools earn their place: `start_stop_play`, `console_output`,
`screen_capture`, `playtest_subagent`, `keyboard_input`, `character_navigation`. The agent
runs the game, drives the character, reads output, looks at the screen.

Authoring through the filesystem, verification through MCP. Never both for the same thing.

### 5. State acceptance criteria in the prompt
The loop only closes if the agent knows what "working" means.

- ✗ "add sprint"
- ✓ "add sprint; verify stamina drains while held, regenerates after 2s idle, and the bar
  UI reflects both"

Without criteria it declares victory on compilation.

### 6. Let it iterate
Two or three self-correction cycles is normal and is the entire point of the setup. Still
failing after three → stop and read the code yourself. It's stuck on a wrong mental model
and more iterations won't fix it.

### 7. Commit or reset
Working → commit with a real message.
Not working → `git reset --hard` and re-plan.

Never hand-patch a tangled agent session. The branch makes throwing it away free.

---

## Phase 2 — Keeping it working past week one

**Context hygiene.** `/clear` between features. Long sessions degrade — the agent starts
referencing code it rewrote two hours ago. `CLAUDE.md` is what survives a clear, which is
why it exists.

**Tests.** Add Jest-Lua or TestEZ early. A test the agent can run itself is worth more than
any amount of playtesting, because it's a verification signal that needs neither a Studio
session nor your eyes.

**Small diffs.** An agent that touches 14 files in a turn is one you can't review. Scope
prompts to one system at a time.

**Read the code. Weekly, minimum.** The failure mode of agentic development isn't bad code —
it's *code you don't understand*. On Roblox that surfaces six weeks later as a duplication
exploit or a DataStore race you can't debug because you never built a model of the system.

**Format and lint before commit.**
```bash
stylua src/
selene src/
```

---

## Phase 3 — Where to reach for something else

### Aesthetic judgement → Studio Assistant

Claude Code *can* build place content through MCP, and should — models, lighting, geometry,
Tool prototypes. What it can't do well is judge the result. It sees your place through
`screen_capture` and a JSON instance tree, which is a poor interface for "does this room
feel right." Assistant is in the viewport with Planning Mode and native mesh/material
generation.

Split by strength:
- **Assistant** → visual feel, layout judgement, terrain sculpting, materials
- **Claude Code** → systems, logic, data, structured place edits, anything that benefits
  from git

The line is judgement, not capability. "Build me six arena models to these dimensions" is
Claude Code. "Does this arena feel good to fight in" is Assistant, or you.

Assistant → **…** → **Manage API Keys** lets you configure your preferred model from
Anthropic, OpenAI, or Google — so you can point Studio's own Assistant at your Anthropic key
rather than maintaining two disconnected model relationships.

### Multiple Studio instances

`list_roblox_studios` and `set_active_studio` target a specific one. Usually inferred from
context.

### Escalating beyond Studio

Anything touching the *published* game — live DataStores, analytics, place publishing,
monetization config — is outside Studio's MCP surface entirely. That's Open Cloud. See the
separate Open Cloud scoping notes.

---

## Phase 4 — Working across two machines

Everything in the stack is cross-platform. Rokit pins versions, so `rokit install` on the
second machine reproduces the first exactly.

**Syncs via git:** `src/`, `rokit.toml`, `default.project.json`, `CLAUDE.md`, `WORKFLOW.md`,
`.gitattributes`.

**Per-machine, never committed:** MCP config (command paths differ by OS — re-run quick
connect rather than copying), Claude Code auth, `~/.rokit/`, `sourcemap.json`.

**The place file is the real friction.** `.rbxl` is binary, doesn't merge, and holds
everything that isn't a script. Two machines editing it independently means one side loses
work silently.

Pick one:
- **Roblox as source of truth for the place** — publish before switching machines, open from
  cloud on the other side. Git holds code, Roblox holds the place. Simplest.
- **Team Create** — overkill for solo/two-machine, but removes the "did I publish?" ritual.

Do not commit the `.rbxl` and hope. If you keep it as a backup, mark it binary in
`.gitattributes` and treat it as strictly single-writer.

---

## The compressed version

> Plan in plan mode. Author on disk. Verify through MCP. Commit per feature. Clear between
> features. **Never let the agent write scripts through both Rojo and MCP.**

That last clause separates a setup that scales from one that quietly corrupts itself in
week two.
