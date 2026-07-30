---
name: roblox-init
description: Set up a Roblox game repo for agentic development with Rojo — toolchain, project mapping, lint/format config, luau-lsp typechecking, and the CLAUDE.md that enforces the scripts-in-files boundary. Use when starting a new Roblox project, or when importing an existing Studio place into version control. Triggers on "set up a Roblox project", "new Roblox game", "sync my place to Rojo", "import from Studio".
---

# Roblox project init

Scaffolds the file-authored / Rojo-synced workflow. Two paths through this skill: a
**fresh** project, and **importing an existing place**. Establish which one first — the
import path has failure modes that destroy hand-built content, and they are not obvious.

Templates live in `templates/` beside this file. Dot-files are stored without the leading
dot (`gitignore` → `.gitignore`).

---

## 1. Establish the parameters

Ask, or infer and state what was picked:

- **Game name** and a one-line description of the core loop → `CLAUDE.md` header.
- **Namespace folder** (`{{NS}}`) — the folder under each service that holds this game's
  code, e.g. `SFT`. Keeps the game's tree separate from anything else in the place. For an
  import, this is dictated by the existing `require` paths; read them, don't choose.
- **Commit style** → the `{{COMMIT_STYLE}}` block. Check user memory for an existing
  preference before asking.

## 2. Toolchain

```bash
rokit add rojo-rbx/rojo && rokit add JohnnyMorganz/StyLua && rokit add Kampfkarren/selene
rokit install
```

Or copy `templates/rokit.toml` for the exact pinned versions this workflow was built
against. Then `rojo plugin install` — **the plugin's major version must match the CLI's**,
or connection fails in ways that look like network problems.

## 3. Copy the templates

Verbatim: `WORKFLOW.md`, `stylua.toml`, `selene.toml`, `luaurc` → `.luaurc`,
`gitignore` → `.gitignore`, `gitattributes` → `.gitattributes`, `vscode/` → `.vscode/`.

Substitute placeholders in `CLAUDE.md` and `default.project.json`:
`{{GAME_NAME}}`, `{{ONE_LINE_CORE_LOOP}}`, `{{NS}}`, `{{PROJECT_NAME}}`,
`{{COMMIT_STYLE}}`, `{{PLACE_OWNED_INSTANCES}}`.

Leave `{{PLACE_OWNED_INSTANCES}}` until after step 5 — for a fresh project it's "none yet".

Then generate the selene standard library, which is gitignored and per-machine:

```bash
selene generate-roblox-std     # writes roblox.yml
```

## 4. Source layout

```
src/server/         → ServerScriptService.{{NS}}
src/client/         → StarterPlayer.StarterPlayerScripts.{{NS}}
src/shared/         → ReplicatedStorage.{{NS}}
src/serverstorage/  → ServerStorage.{{NS}}
```

Delete the `init.server.luau` / `init.client.luau` / `Hello.luau` stubs `rojo init` leaves
behind. They serve no purpose and, once synced, come back out of any future Studio export
looking like real code.

## 5. Importing an existing place

**If there is existing Studio content, read `references/importing-an-existing-place.md`
now and follow it.** It covers, in order:

- RunContext → Rojo naming translation, and how to verify class inference
- Rojo's own hello-world stubs echoing back out of the export
- **Finding place-owned instances inside would-be-managed folders** — the step that
  destroys hand-built models if skipped
- Remotes as a `.model.json`, with classes read from call sites
- A `git mv` trap that silently flattens nested directories
- The verification order that actually catches each failure

Do not improvise this from first principles. The failure modes are silent.

## 6. Editor integration

`templates/vscode/settings.json` points luau-lsp at the sourcemap with
`autogenerate: true` and `includeNonScripts: true`.

This is the highest-leverage step in the whole setup and the easiest to skip. Without it,
`require(RS.<NS>.Config)` resolves to `any`, every `--!strict` header buys nothing outside
Studio, and field typos surface as runtime `nil` rather than editor errors.
`includeNonScripts` additionally types the remotes, so calling `:FireClient` on a
RemoteFunction becomes a red squiggle.

`autogenerate` means the extension runs the sourcemap watcher itself — no second terminal.

## 7. Verify, then commit

```bash
rojo build -o /tmp/verify.rbxlx   # project file valid, every $path resolves
stylua --check src/
selene src/
```

Then `rojo serve`, connect the plugin, and confirm against the **live place** with MCP
`search_game_tree` — that any instance flagged in step 5 survived the first sync.
`rojo build` succeeding proves nothing about the place.

Commit in reviewable steps. For an import: raw export first, then the move, then
formatting as its own commit.

---

## The boundary this exists to protect

**Scripts live in files. Everything else lives in the place.**

Authoring Luau through MCP while `rojo serve` runs means the next sync silently overwrites
it — no error, no conflict marker. Place content (models, terrain, lighting, Tool
prototypes) is the opposite: author it directly through MCP, because it has no file
representation.

`CLAUDE.md` is the enforcement mechanism — it is the only file guaranteed to be in context
every session, surviving `/clear` and compaction. Which is why this skill writes one rather
than assuming the rule will be remembered.
