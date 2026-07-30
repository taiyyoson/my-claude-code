# Importing an existing Studio place into Rojo

For a game that already has content. A brand-new project skips almost all of this.

The order matters. Steps 1–3 are diagnosis and must happen **before** the first sync,
because the first sync is the one that can destroy place content.

---

## 0. Commit the raw export first

Before moving anything, get the untouched export into git. It costs one commit and it is
the only restore point that matches what Studio actually held.

Then do the migration as a second commit, so the diff reads as renames rather than a
wholesale delete-and-add.

---

## 1. Translate the naming convention

Studio exporters name files by **RunContext**. Rojo names them by **class**. They do not
agree, and getting it wrong is silent:

| Export | Rojo | Instance |
|---|---|---|
| `Foo.legacy.luau` | `Foo.server.luau` | `Script` |
| `Foo.local.luau` | `Foo.client.luau` | `LocalScript` |
| `Foo.luau` | `Foo.luau` | `ModuleScript` |

Left untranslated, every Script becomes a ModuleScript. Nothing runs, and there is no
error — a ModuleScript that is never required simply does nothing.

**Verify the classification rather than trusting the extension.** A ModuleScript must
return a value; a Script and a LocalScript do not:

```bash
for f in $(find . -name '*.luau'); do
  printf "%-50s return=%s\n" "$f" "$(tail -3 "$f" | grep -c '^return')"
done
```

The files reporting `0` are your Scripts and LocalScripts. If that set doesn't match the
set with `.legacy` / `.local` extensions, investigate before moving anything.

---

## 2. Find the Rojo hello-world echoes

If `rojo init` ran before the export, its stub scripts synced into Studio and came back
out again. They look like game code and are not:

- `ServerScriptService/Server.legacy.luau` — `print("Hello world, from server!")`
- `StarterPlayerScripts/Client.local.luau` — `print("Hello world, from client!")`
- `ReplicatedStorage/Shared/Hello.luau`

Delete these, along with the `src/*/init.*.luau` stubs that produced them.

**They also leave orphans in the place.** When the project mapping is repointed (e.g.
`Shared` → `SFT`), Rojo stops managing the old nodes but does not delete them. Two of the
three *execute*, printing hello-world on every run, which pollutes the console output you
will later rely on for playtest verification. Clean them out of the place through MCP once
the new mapping is confirmed working.

---

## 3. Find place-owned instances inside Rojo-managed folders — the dangerous step

This is the one that destroys work.

Rojo reconciles the children of instances it manages. A hand-built model living *inside* a
folder that Rojo is about to own gets removed on the first sync, silently.

Grep the source for everything it expects to find in the data model:

```bash
grep -rn 'ServerStorage\.\|ReplicatedStorage\.\|:FindFirstChild(' src/ | grep -v GetService
```

Sort each hit into one of three buckets:

- **Sibling of a managed folder** (e.g. `ServerStorage.Arenas` next to `ServerStorage.SFT`)
  — safe, Rojo never looks at it.
- **Child of a managed folder** (e.g. `ServerStorage.SFT.SwordTemplates.Classic`) — **at
  risk.** Set `"$ignoreUnknownInstances": true` on that node in `default.project.json`.
- **Under a service you don't map at all** (e.g. `StarterCharacterScripts`) — safe.

When in doubt during a migration, set the flag. The cost of setting it unnecessarily is
that scripts deleted from disk linger in the place — visible, easy to fix. The cost of
omitting it is silent destruction of hand-built content. Those are not symmetric.

Once the first sync is confirmed clean, the flag can be dropped from pure-script folders.

---

## 4. Remotes become a `.model.json`

Remotes are Instances, not scripts, so they have no file to live in. Declaring them in the
project keeps them version-controlled and rebuilds them on a fresh clone.

`src/shared/Remotes.model.json` → `ReplicatedStorage.<NS>.Remotes`:

```json
{
  "className": "Folder",
  "children": [
    { "name": "Notify", "className": "RemoteEvent" },
    { "name": "GetProfile", "className": "RemoteFunction" }
  ]
}
```

The instance name comes from the filename, not from the JSON.

**Infer each class from its call sites**, not from the name:

```bash
grep -rn 'Remotes\.[A-Za-z]*[:.]\(FireClient\|FireAllClients\|OnServerEvent\|OnServerInvoke\)' src/
```

`OnServerInvoke` / `InvokeServer` → `RemoteFunction`. Everything else → `RemoteEvent`.

---

## 5. Moving the files

**`git mv <dir> <dest>/` renames the directory when `<dest>` does not exist**, instead of
moving into it. On a batch move this silently flattens nested folders — `Modes/` and
`Shared/` vanish and their contents land one level up, which breaks
`require(script.Parent.Modes[name])` in a way that only shows at runtime.

Create every destination first, and move files individually rather than globbing
directories:

```bash
mkdir -p src/server/Modes src/client src/shared/Shared src/serverstorage
for n in FreeForAll KingOfTheHill; do
  git mv "ServerScriptService/SFT/Modes/$n.luau" "src/server/Modes/$n.luau"
done
```

Verify the result before committing: `git status --short` should show `R` (rename) lines,
and the nesting depth should match the original.

---

## 6. Verify before trusting the sync

Static checks, in order. Each one catches a different failure:

```bash
rojo build -o /tmp/verify.rbxlx        # project file valid, every $path resolves
rojo sourcemap --output sourcemap.json # then read it back
```

Read the sourcemap and confirm **class names**, not just paths — this is the real check
that the RunContext translation worked:

```bash
python3 -c "
import json
m=json.load(open('sourcemap.json'))
def walk(n,p=''):
    q=p+'.'+n['name'] if p else n['name']
    if n.get('className') in ('Script','LocalScript'): print(n['className'], q)
    for k in n.get('children',[]): walk(k,q)
for k in m.get('children',[]): walk(k)
"
```

`rojo sourcemap` omits non-script instances by default, so remotes will not appear. Add
`--include-non-scripts` to check those.

Then verify against the **live place** via MCP `search_game_tree` — confirming that the
at-risk instances from step 3 actually survived. A successful `rojo build` says nothing
about this; only reading the real data model does.

---

## 7. Format last, as its own commit

`stylua src/` over an imported codebase rewrites thousands of lines. Keep it out of the
migration commit or the renames become unreviewable.

`selene src/` needs `roblox.yml`, generated by `selene generate-roblox-std` — gitignore
it, and note the regenerate step in `CLAUDE.md`. **Without it selene lints against plain
Lua 5.1 and reports success**, which is worse than not running it.

Report lint findings in imported code; don't fix them in the migration. Stock Roblox
scripts (`Animate`) will trip `deprecated` and `unused_variable` lints and should be left
verbatim.
