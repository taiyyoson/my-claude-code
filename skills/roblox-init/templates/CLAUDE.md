# CLAUDE.md

Project conventions for this Roblox codebase. These rules survive `/clear` and context
compaction — follow them without being re-asked.

**Project:** {{GAME_NAME}}
**Concept:** {{ONE_LINE_CORE_LOOP}}

---

## Critical: the Rojo boundary

**Scripts live in files. Everything else lives in the place.**

The split is by *what is being authored*, not by which tool is convenient.

### Luau — files only, no exceptions

- All Luau is authored in `src/` on disk. Rojo syncs it into Studio.
- **Never** use MCP `multi_edit`, `script_read`, or any Studio-side script write to author
  or modify code. With `rojo serve` running, the next sync overwrites it silently — no
  error, no conflict marker, the work is simply gone.
- This is not a style preference. It is the one rule whose violation loses work.

### Place content — author it directly through MCP

Models, terrain, lighting, geometry, Tool prototypes, hand-placed UI: these live in the
`.rbxl` and **are yours to build**. Use `multi_edit`, `insert_asset`, `generate_mesh`,
`generate_material`, `generate_procedural_model` and friends. Don't stop and ask for
routine place work, and don't approximate place content in code to avoid touching it.

Two things still warrant checking first, because they are hard to reverse:

- Deleting or overwriting existing instances the user built by hand.
- Bulk edits across a large subtree.

Place edits are not version-controlled — the `.rbxl` is binary and gitignored. Say plainly
what you changed in the place, since git won't record it.

### Verification — always MCP

`start_stop_play`, `get_console_output`, `screen_capture`, `subagent`,
`user_keyboard_input`, `character_navigation`, `execute_luau` for one-off inspection,
`search_game_tree` / `inspect_instance` for reading the data model.

Luau through the filesystem. Place content and verification through MCP. Never both for
the same thing.

---

## Layout

```
src/server/         → ServerScriptService.{{NS}}
src/client/         → StarterPlayer.StarterPlayerScripts.{{NS}}
src/shared/         → ReplicatedStorage.{{NS}}
src/serverstorage/  → ServerStorage.{{NS}}
```

Everything sits under a `{{NS}}` folder in each service. Existing `require` paths depend on
that, so don't flatten it.

Anything in `src/shared/` is replicated to clients and is therefore **public**. Never put
secrets, server-only constants, or exploit-sensitive tuning values there.

<!-- List any instance that lives INSIDE a Rojo-managed folder but is authored in the
     place. Each one needs $ignoreUnknownInstances on its parent node in
     default.project.json, or Rojo will reconcile it away on the first sync. -->
**Not Rojo-managed — these live in the place and are edited there, through MCP:**
{{PLACE_OWNED_INSTANCES}}

---

## Luau conventions

- `--!strict` at the top of every file. No exceptions.
- Modern API only. Use `task.wait`, `task.spawn`, `task.defer`, `task.delay`. Never `wait`,
  `spawn`, or `delay`.
- No `BodyVelocity` / `BodyPosition` / `BodyGyro` — use `LinearVelocity`, `AlignPosition`,
  `AlignOrientation`.
- Every `Connect` must have a matching disconnect path. Use a Trove/Maid cleanup object for
  anything with a lifecycle.
- No unbounded `:Wait()`. Use `task.delay` timeouts or `WaitForChild(name, timeout)`.
- Prefer `:GetAttribute()` / `:SetAttribute()` over hidden value objects.
- Local variable and function names: `camelCase`. Module and type names: `PascalCase`.
  Constants: `SCREAMING_SNAKE_CASE`.

---

## Client/server boundary

- **The client is hostile.** Never trust anything it sends. Validate every RemoteEvent and
  RemoteFunction argument on the server: type, range, ownership, rate.
- Remotes live at `ReplicatedStorage.{{NS}}.Remotes`, declared in
  `src/shared/Remotes.model.json` so they are version-controlled and rebuilt on a fresh
  clone. Add new ones there, never by hand in Studio.
- Server is authoritative for all state that affects progression, currency, or inventory.
  Client may predict for responsiveness, but the server value wins.
- RemoteFunctions from client to server: avoid. A yielding exploitable call is worse than
  two events. Use RemoteEvents both directions unless there's a hard reason not to.

---

## Data persistence

- `DataStoreService` may only be accessed from `src/server/`. Never from shared or client.
- Every call wrapped in `pcall` with retry and exponential backoff. Never assume success.
- Use `UpdateAsync`, not `GetAsync` + `SetAsync` — the latter races and loses data.
- Session locking on player data. A player joining two servers must not double-write.
- Bind to `game:BindToClose` to flush pending saves on shutdown.
- Never write on every change. Batch, debounce, and respect request limits.

---

## Before declaring a task done

1. `stylua src/`
2. `selene src/` — needs `roblox.yml`, which is gitignored and regenerated per clone with
   `selene generate-roblox-std`. Without it selene silently lints against plain Lua 5.1.
3. Typecheck passes with no new errors
4. Tests pass, and new behavior has a test
5. Playtested through MCP, with the specific acceptance criteria verified — not just
   "it compiled"

If you cannot verify a criterion, say which one and why. Do not report success on
unverified behavior.

---

## Working style

- One feature per session. Do not batch unrelated changes.
- Propose a plan before writing code. Wait for approval on anything structural.
- Keep diffs small enough to review. If a change would touch more than a handful of files,
  stop and explain the scope first.
- Do not create new abstractions, folders, or dependencies without asking.
- Do not add comments explaining what the code does. Comment only *why*, and only when
  non-obvious.
- If a request is ambiguous, ask. Don't guess and build the wrong thing.

---

## Commits

{{COMMIT_STYLE}}

One logical change per commit. Never commit `.rbxl`, `sourcemap.json`, or `roblox.yml`.

---

## Out of scope for this repo

Anything touching the **published** game — live DataStore reads, analytics, place
publishing, monetization configuration — is Open Cloud, not Studio. Don't attempt it from
here. Flag it and stop.
