# Forever Unit Frames — Raid plan R1: foundation (registries, raid profiles, raid size)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The settings machinery can hold more than one settings domain; the raid frames get their own registry, a per-character profile with one scope per raid size (10/20/40) stored in the account-wide SavedVariables, copy/reset/export/import of a size, and a size detector that fires `RAID_SIZE_CHANGED` — all without changing anything the unit frames save, show or do.

**Architecture:** `Core/Registry.lua` turns the body of today's `Core/Settings.lua` (definition list, defaults, `AppliesTo`, `Validate`, preset) into a factory `ns.NewRegistry(scopes, prefix)` and adds `Sanitise` (moved from `Core/Storage.lua`). `Core/Config.lua` and `Core/Codec.lua` become factories too (`ns.NewConfig(registry, event, notCopied)`, `ns.NewCodec(registry)`); `ns.Settings`, `ns.Config`, `ns.Codec` are the unit-frame instances with the same API as before. New folder `Raid/`: `Settings.lua` (registry with scopes `general`, `r10`, `r20`, `r40`), `Profiles.lua` (`ns.RaidConfig`, `ns.RaidCodec`, attach/copy/export/import), `Size.lua` (detector). `Core/Boot.lua` attaches the raid profile at login.

**Tech Stack:** Lua 5.1, WoW: Forever API (Interface 16001, build 1.60.1.70205), offline tests with `lua5.1` + `tests/mock.lua` (`tests/run`).

Spec: `docs/specs/2026-10-06-raid-frames-design.md` (part 1, §3 Architecture). Raid plan order: **R1 Foundation (this plan)** → R2 Headers, layout and cell → R3 Indicators, icons and states → R4 Options window, locales, wiki, release. R2–R4 are written once R1 has landed, against the code as it then is.

Base: `main` at `e76b2e1` ("Raid frames design, part 1 (core)"); `tests/run` there: `18646 passed, 0 failed`. Every task below was replayed in order on a scratch worktree of that commit; the totals under "Expected" are what `tests/run` printed there.

## Global Constraints

- Everything in English: UI strings, file names, identifiers, comments. This plan adds no user-facing string.
- Target client: WoW: Forever, `## Interface: 16001`. Client facts only from the Forever UI source (the `forever` branch, `Blizzard_APIDocumentationGenerated/` for signatures); the ones used are in the table below.
- The unit frames must not notice the refactor: every existing setting key, code, scope letter, default and the encoded string format stay exactly as they are. `tests/run` must stay green after every task without editing an existing test.
- Setting codes are permanent once released. Raid codes live in the raid registry and only have to be unique there.
- No secret-value maths: nothing in this plan reads a unit value. `GetInstanceInfo`, `GetNumGroupMembers`, `UnitFullName("player")`, `GetNormalizedRealmName` are not secret.
- `ns.On` throws on an unknown event name: only the five events verified below are registered.
- The mock stays faithful: new stand-ins return what the documented signature returns, nothing more permissive.
- Public repository: no local paths, host names, character names or anything about the author's machine in files or commit messages. Test names are neutral (`Tester`, `Testrealm`, `Healer`, `Newbie`).
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
- Do not push. Every task ends with `tests/run` green and one commit (`git add` only the files the task lists).

## Client facts this plan relies on (build 1.60.1.70205)

Paths below `Interface/AddOns/`; `Doc/` = `Blizzard_APIDocumentationGenerated/`.

| Fact | Source |
|---|---|
| `GetInstanceInfo() -> name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, lfgDungeonID, hasWorldTier`, no secret flags | `Doc/InstanceDocumentation.lua` |
| `UnitFullName(unit) -> unitName, unitServer`; `GetNormalizedRealmName() -> result` | `Doc/UnitDocumentation.lua`, `Doc/PlayerScriptDocumentation.lua` |
| `GetNumGroupMembers()` exists (used by Blizzard's raid UI and by `Elements/ThreatBar.lua`) | `Blizzard_RaidUI`, `Blizzard_CompactRaidFrames` |
| Events `PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)`, `ZONE_CHANGED_NEW_AREA()`, `PLAYER_DIFFICULTY_CHANGED()`, `INSTANCE_GROUP_SIZE_CHANGED()`, `GROUP_ROSTER_UPDATE()` exist | `Doc/*Documentation.lua` (event tables) |
| Raid instance sizes on Forever: 10, 20, 40 (difficulty IDs 243, 242, 9) | `Mainline/DifficultyUtil_Base.lua` |

## Design decisions

- **Registries.** A registry owns its definition list, scopes and scope letters. The unit-frame registry keeps its seven scopes and letters. The raid registry has `general` (letter `g`, per character: on/off, size mode, raid view in party, hide Blizzard raid frames) and `r10`, `r20`, `r40` (letters `a`, `b`, `c`, one profile per size; frame-scope settings). Raid settings never use `inherit`.
- **One config per registry.** `ns.NewConfig(registry, event, notCopied)` returns the same API `ns.Config` has today, closed over its own profile, its own derived scopes and its own change event. Unit frames: `CONFIG_CHANGED`, `notCopied = { x, y, enabled }` (as today). Raid: `RAID_CONFIG_CHANGED`, nothing excluded — copying a size takes its position too, only one size shows at a time.
- **Copy from another profile.** `Config.CopyScopeFrom(source, from, to)` copies a scope of any profile (another character's, a decoded import) with the source's own `general` for inherited values; `CopyScope(from, to)` is that with the profile in use.
- **Raid storage.** `ForeverUnitFramesDB.raid["Name-Realm"]` is the profile table itself (sanitised at login), so a change is in SavedVariables at once; no save queue, no providers, no macro backup. The unit-frame save only ever writes `db.profile` and `db.version`, so the two never touch.
- **Export of a size** is the raid codec limited to that size's scope (`1;bX12`). Import takes the first size found and replaces the whole target size; a string with no size entries means "all defaults" and resets the target.
- **Size rule.** Fixed mode wins. AUTO: in a raid instance with `maxPlayers > 0` its size, else `GetNumGroupMembers()`; both bucketed `<= 10 → 10`, `<= 20 → 20`, else `40`. Solo and party are 10.
- **Boot order.** The raid profile is attached last in the `PLAYER_LOGIN` handler, after everything the unit frames build, so nothing of the unit frames can depend on it.

---

### Task 1: Settings registry factory

**Files:**
- Create: `Core/Registry.lua`
- Modify: `Core/Settings.lua:1-107` (the header up to and including `Settings.Validate`)
- Modify: `Core/Storage.lua` (remove the local `sanitise`, use `ns.Settings.Sanitise`)
- Modify: `ForeverUnitFrames.toc` (load `Core\Registry.lua` before `Core\Settings.lua`)
- Test: `tests/test_registry.lua`

**Interfaces:**
- Produces: `ns.NewRegistry(scopes, prefix) -> R` with `R.SCOPES`, `R.PREFIX`, `R.TEXT_MAX` (64), `R.Validate(def, v)`, `R.Define(def)`, `R.Get(key)`, `R.ByCode(code)`, `R.All()`, `R.Default(def, scope)`, `R.AppliesTo(def, scope)`, `R.ApplyPreset(preset)`, `R.Sanitise(profile) -> clean` (every scope present, unknown keys/scopes dropped, values validated). `ns.Settings` is the unit-frame registry with exactly today's API.

- [ ] **Step 1: Write the failing test**

Create `tests/test_registry.lua`:

```lua
-- Settings registries (Core/Registry.lua): each has its own definitions,
-- scopes and code space; the unit-frame settings are one of them.
local ns = H.LoadAddon()

local A = ns.NewRegistry({ "general", "one" }, { general = "g", one = "a" })
local B = ns.NewRegistry({ "general", "two" }, { general = "g", two = "b" })
A.Define({ key = "size", code = "S", scope = "frame", type = "int", min = 1, max = 9, default = 4 })
B.Define({ key = "size", code = "S", scope = "general", type = "bool", default = true })

H.check("same key, own definition A", A.Get("size").type, "int")
H.check("same key, own definition B", B.Get("size").type, "bool")
H.check("same code, own definition", B.ByCode("S").type, "bool")
H.check("A lists only its own", #A.All(), 1)
H.checkError("duplicate code inside one registry", function()
    A.Define({ key = "other", code = "S", scope = "frame", type = "bool", default = false })
end)
H.check("scopes kept", A.SCOPES[2], "one")
H.check("prefix kept", B.PREFIX.two, "b")
H.check("validate clamps", A.Validate(A.Get("size"), 12), 9)
H.checkTrue("frame setting applies to a frame scope", A.AppliesTo(A.Get("size"), "one"))
H.check("frame setting not on general", A.AppliesTo(A.Get("size"), "general"), false)

-- Sanitise keeps known settings on scopes they apply to, validated.
local clean = A.Sanitise({ general = { size = 3 }, one = { size = 40, nope = 1 }, stray = { size = 2 } })
H.check("sanitise: wrong scope dropped", clean.general.size, nil)
H.check("sanitise: clamped", clean.one.size, 9)
H.check("sanitise: unknown key dropped", clean.one.nope, nil)
H.check("sanitise: unknown scope dropped", clean.stray, nil)
H.checkTrue("sanitise: every scope present", type(clean.general) == "table" and type(clean.one) == "table")

-- The unit-frame registry is one of them and unchanged.
local S = ns.Settings
H.check("unit frames: scopes", table.concat(S.SCOPES, ","), "general,player,target,targettarget,pet,focus,party")
H.check("unit frames: party prefix", S.PREFIX.party, "y")
H.check("unit frames: width code", S.Get("width").code, "W")
H.check("unit frames: text max", S.TEXT_MAX, 64)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run registry`
Expected: `ERROR test_registry.lua:...: attempt to call field 'NewRegistry' (a nil value)`, `0 passed, 1 failed`

- [ ] **Step 3: Create `Core/Registry.lua`**

```lua
local _, ns = ...

-- A settings registry: one list of setting definitions, the scopes they
-- live in and the letter each scope is written with. The unit frames have
-- one (Core/Settings.lua), the raid frames another (Raid/Settings.lua).
-- Codes only have to be unique within a registry: every saved or exported
-- string belongs to exactly one.

local function inList(values, v)
    for i = 1, #values do if values[i] == v then return true end end
    return false
end

-- The longest free text a setting takes (a spell name, or its ID).
local TEXT_MAX = 64

local function validate(def, v)
    local t = def.type
    if t == "int" then
        if type(v) ~= "number" then return nil end
        if v ~= v or v == math.huge or v == -math.huge then return nil end
        v = math.floor(v + 0.5)
        if def.min and v < def.min then v = def.min end
        if def.max and v > def.max then v = def.max end
        return v
    elseif t == "bool" then
        if type(v) ~= "boolean" then return nil end
        return v
    elseif t == "enum" then
        if not inList(def.values, v) then return nil end
        return v
    elseif t == "color" then
        if type(v) ~= "table" then return nil end
        for i = 1, 4 do
            local c = v[i]
            if type(c) ~= "number" or c < 0 or c > 1 then return nil end
        end
        return { v[1], v[2], v[3], v[4] }
    elseif t == "media" then
        if type(v) ~= "string" or v == "" then return nil end
        return v
    elseif t == "text" then
        -- Free text, trimmed; empty is allowed. def.maxLetters caps it.
        if type(v) ~= "string" then return nil end
        v = v:match("^%s*(.-)%s*$")
        if #v > (def.maxLetters or TEXT_MAX) then return nil end
        return v
    end
    return nil
end

-- scopes: ordered list, "general" first; prefix: scope -> one lower-case
-- letter, unique within the registry.
function ns.NewRegistry(scopes, prefix)
    local R = { SCOPES = scopes, PREFIX = prefix, TEXT_MAX = TEXT_MAX, Validate = validate }
    local list, byKey, byCode = {}, {}, {}

    function R.Define(def)
        assert(not byKey[def.key], "duplicate key " .. def.key)
        assert(not byCode[def.code], "duplicate code " .. def.code)
        list[#list + 1] = def
        byKey[def.key] = def
        byCode[def.code] = def
    end

    function R.Get(key) return byKey[key] end
    function R.ByCode(code) return byCode[code] end
    function R.All() return list end

    function R.Default(def, scope)
        local d = def.default
        if type(d) == "table" and d._ ~= nil then
            local v = d[scope]
            if v == nil then v = d._ end
            return v
        end
        return d
    end

    -- def.only (optional) limits a frame setting to some frames, e.g.
    -- { party = true } for the party layout.
    function R.AppliesTo(def, scope)
        if scope == "general" then return def.scope ~= "frame" end
        if def.scope == "general" then return false end
        if def.only then return def.only[scope] == true end
        return true
    end

    -- A shipped look on top of the plain defaults: preset[scope][key] =
    -- value. A general value becomes the setting's base default, a frame
    -- value that frame's own default.
    function R.ApplyPreset(preset)
        for scope, values in pairs(preset) do
            for key, value in pairs(values) do
                local def = assert(byKey[key], "preset: unknown setting " .. key)
                assert(R.AppliesTo(def, scope), "preset: " .. key .. " does not apply to " .. scope)
                assert(validate(def, value) == value or def.type == "color", "preset: invalid " .. key)
                local d = def.default
                if type(d) ~= "table" or d._ == nil then d = { _ = d } end
                if scope == "general" then d._ = value else d[scope] = value end
                def.default = d
            end
        end
    end

    -- Only known scopes and settings that apply to them survive, each with
    -- a value that passes validation: a hand-edited or outdated
    -- SavedVariables file must never reach Config or the codec.
    function R.Sanitise(profile)
        local clean = {}
        for _, scope in ipairs(scopes) do
            clean[scope] = {}
            local values = profile[scope]
            if type(values) == "table" then
                for key, v in pairs(values) do
                    local def = byKey[key]
                    if def and R.AppliesTo(def, scope) then
                        clean[scope][key] = validate(def, v)
                    end
                end
            end
        end
        return clean
    end

    return R
end
```

- [ ] **Step 4: Make `Core/Settings.lua` use it**

Replace everything from line 1 up to (not including) the line `-- Definitions -----...` (today: the module header, `Settings.SCOPES`, `Settings.PREFIX`, the local `list, byKey, byCode`, `Define`, `Get`, `ByCode`, `All`, `Default`, `ApplyPreset`, `AppliesTo`, `inList`, `TEXT_MAX`, `Validate`) with:

```lua
local _, ns = ...

-- The one list of every unit-frame setting. Config, Codec, the options
-- window and the tests all read from here. A setting's `code` is written
-- into saved and exported strings: once released it must never change or
-- be reused. The registry itself is Core/Registry.lua.
local Settings = ns.NewRegistry(
    { "general", "player", "target", "targettarget", "pet", "focus", "party" },
    { general = "g", player = "p", target = "t", targettarget = "o", pet = "e", focus = "f", party = "y" })
ns.Settings = Settings
```

followed by one blank line, so the file continues with `-- Definitions -----...` unchanged. Nothing below that line changes.

- [ ] **Step 5: Use the registry's `Sanitise` in `Core/Storage.lua`**

Delete the comment block and function that start with `-- Only known scopes and settings that apply to them survive` and end before `local function from(name, isProvider, profile)`. In `Storage.Load` change

```lua
        return from("SavedVariables", false, sanitise(db.profile))
```

to

```lua
        return from("SavedVariables", false, ns.Settings.Sanitise(db.profile))
```

- [ ] **Step 6: Load the registry first**

In `ForeverUnitFrames.toc`, between `Core\Secrets.lua` and `Core\Settings.lua`, add the line:

```
Core\Registry.lua
```

- [ ] **Step 7: Run the tests**

Run: `tests/run registry` → `19 passed, 0 failed`
Run: `tests/run` → Expected: `18665 passed, 0 failed`

- [ ] **Step 8: Commit**

```bash
git add Core/Registry.lua Core/Settings.lua Core/Storage.lua ForeverUnitFrames.toc tests/test_registry.lua
git commit -m "Settings registry as a factory, one per settings domain

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Config factory with copy from another profile

**Files:**
- Modify: `Core/Config.lua` (whole file)
- Test: `tests/test_config_factory.lua`

**Interfaces:**
- Consumes: `ns.NewRegistry` (Task 1).
- Produces: `ns.NewConfig(registry, event, notCopied) -> C` with today's API (`Use`, `Profile`, `Derive`, `Get`, `IsOverridden`, `Set`, `ResetScope`, `ResetAll`, `ClearOverride`, `ClearFrameOverrides`, `CopyScope(from, to)`, `Import`) plus `CopyScopeFrom(source, from, to)`; every change fires `event` with `(scope, key)` (`nil` for "several"). `ns.Config = ns.NewConfig(ns.Settings, "CONFIG_CHANGED", { x = true, y = true, enabled = true })`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_config_factory.lua`:

```lua
-- ns.NewConfig (Core/Config.lua): one profile per registry, its own change
-- event, its own list of keys a copy leaves alone, and copying from a
-- profile that is not the one in use.
local ns = H.LoadAddon()

local R = ns.NewRegistry({ "general", "a", "b" }, { general = "g", a = "a", b = "b" })
R.Define({ key = "mode", code = "M", scope = "general", type = "bool", default = false })
R.Define({ key = "font", code = "F", scope = "inherit", type = "int", min = 1, max = 30, default = 12 })
R.Define({ key = "width", code = "W", scope = "frame", type = "int", min = 1, max = 500, default = { a = 80, _ = 60 } })
R.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -99, max = 99, default = 0 })

local events = {}
ns.Listen("TEST_CONFIG_CHANGED", function(scope, key) events[#events + 1] = tostring(scope) .. ":" .. tostring(key) end)
local unitEvents = 0
ns.Listen("CONFIG_CHANGED", function() unitEvents = unitEvents + 1 end)

local C = ns.NewConfig(R, "TEST_CONFIG_CHANGED", {})
C.Use({})
H.checkTrue("scopes made", type(C.Profile().a) == "table" and type(C.Profile().b) == "table")
H.check("frame default", C.Get("a", "width"), 80)
H.check("base default", C.Get("b", "width"), 60)
H.checkTrue("set", C.Set("a", "width", 120))
H.check("own event", events[#events], "a:width")
H.check("unit-frame event untouched", unitEvents, 0)
C.Set("general", "font", 14)
H.check("inherits general", C.Get("b", "font"), 14)

-- Nothing is left out of a copy when notCopied is empty: x travels too.
C.Set("a", "x", 7)
C.CopyScope("a", "b")
H.check("copy: width", C.Get("b", "width"), 120)
H.check("copy: x copied", C.Get("b", "x"), 7)
H.check("copy: event", events[#events], "b:nil")

-- Copy from another profile (another character, a decoded import): its
-- own general counts for inherited settings, ours does not.
local other = { general = { font = 20 }, a = { width = 200 }, b = {} }
C.CopyScopeFrom(other, "a", "b")
H.check("from other: width", C.Get("b", "width"), 200)
H.check("from other: inherited value of the source", C.Get("b", "font"), 20)
H.check("from other: source default x", C.Get("b", "x"), 0)
H.check("from other: stored as override only", C.Profile().b.x, nil)
H.check("from other: source untouched", other.b.width, nil)
C.CopyScopeFrom({ general = {} }, "a", "b")
H.check("source without that scope: nothing", C.Get("b", "width"), 200)
C.CopyScopeFrom(other, "a", "nope")
H.check("unknown target scope: nothing", C.Profile().nope, nil)

-- Two configs keep two profiles.
local D = ns.NewConfig(R, "TEST_CONFIG_CHANGED", {})
D.Use({})
H.check("second config: own profile", D.Get("a", "width"), 80)
H.check("first config unchanged", C.Get("a", "width"), 120)

-- The unit frames keep their rules: position and enabled are not copied.
local UF = ns.Config
UF.Use({})
UF.Set("player", "x", 33)
UF.Set("player", "width", 250)
UF.CopyScope("player", "target")
H.check("unit frames: width copied", UF.Get("target", "width"), 250)
H.check("unit frames: x not copied", UF.Get("target", "x"), 300)
H.checkTrue("unit frames: event", unitEvents > 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run config_factory`
Expected: `ERROR test_config_factory.lua:...: attempt to call field 'NewConfig' (a nil value)`

- [ ] **Step 3: Replace `Core/Config.lua`**

The rules are today's; what changes is that they are closed over a registry, an event name and a `notCopied` set, and that `Get`/copy read through `valueIn(p, scope, def)` / `fallbackIn(p, scope, def)` so a copy can read a profile that is not the one in use.

```lua
local _, ns = ...

-- Profile access. A profile holds overrides only; everything else comes
-- from inheritance (frame -> general) and the defaults of its registry.
-- ns.NewConfig makes one per settings registry: ns.Config for the unit
-- frames (below), ns.RaidConfig for the raid frames (Raid/Profiles.lua).
-- `event` is the internal event fired on every change; `notCopied` lists
-- the keys CopyScope leaves with the target.

local function sameValue(a, b)
    if type(a) == "table" and type(b) == "table" then
        for i = 1, 4 do if a[i] ~= b[i] then return false end end
        return true
    end
    return a == b
end

local function copyValue(v)
    if type(v) == "table" then return { v[1], v[2], v[3], v[4] } end
    return v
end

function ns.NewConfig(Settings, event, notCopied)
    local Config = {}
    local profile

    local function ensureScopes(p)
        for _, scope in ipairs(Settings.SCOPES) do
            if type(p[scope]) ~= "table" then p[scope] = {} end
        end
    end

    function Config.Use(p)
        profile = p
        ensureScopes(profile)
    end

    function Config.Profile()
        return profile
    end

    local function hasFrameDefaults(def)
        local d = def.default
        if type(d) ~= "table" or d._ == nil then return false end
        for k in pairs(d) do
            if k ~= "_" then return true end
        end
        return false
    end

    -- What a scope of profile p gets when it has no override of its own.
    local function fallbackIn(p, scope, def)
        if scope ~= "general" and def.scope == "inherit" then
            local g = p.general and p.general[def.key]
            if g ~= nil then return g end
            -- The frame's own default, if it has one (preset), else the base.
            return Settings.Default(def, scope)
        end
        return Settings.Default(def, scope)
    end

    local function valueIn(p, scope, def)
        local own = p[scope] and p[scope][def.key]
        if own ~= nil then return own end
        return fallbackIn(p, scope, def)
    end

    -- Derived scopes have no profile and no options page of their own: a
    -- resolver fixes some settings, everything else is the base scope's
    -- (party pets follow the party frame, Units/PartyPets.lua). Setting a
    -- value on a derived scope is refused.
    local derived = {}

    function Config.Derive(scope, base, resolve)
        derived[scope] = { base = base, resolve = resolve }
    end

    function Config.Get(scope, key)
        local def = assert(Settings.Get(key), "unknown setting " .. tostring(key))
        local d = derived[scope]
        if d then
            local v = d.resolve(key)
            if v ~= nil then return v end
            return Config.Get(d.base, key)
        end
        return valueIn(profile, scope, def)
    end

    function Config.IsOverridden(scope, key)
        return profile[scope] ~= nil and profile[scope][key] ~= nil
    end

    function Config.Set(scope, key, value)
        local def = Settings.Get(key)
        if not def or not profile[scope] or not Settings.AppliesTo(def, scope) then return false end
        local v = Settings.Validate(def, value)
        if v == nil then return false end
        -- A general value equal to the base default is still kept when some
        -- frame has a default of its own: it is what those frames follow.
        if sameValue(v, fallbackIn(profile, scope, def)) and not (scope == "general" and hasFrameDefaults(def)) then
            profile[scope][key] = nil
        else
            profile[scope][key] = v
        end
        ns.Fire(event, scope, key)
        return true
    end

    function Config.ResetScope(scope)
        profile[scope] = {}
        ns.Fire(event, scope, nil)
    end

    function Config.ResetAll()
        for _, scope in ipairs(Settings.SCOPES) do profile[scope] = {} end
        ns.Fire(event, nil, nil)
    end

    function Config.ClearOverride(scope, key)
        if not profile[scope] then return end
        profile[scope][key] = nil
        ns.Fire(event, scope, key)
    end

    -- Removes the given keys from every frame scope, so each frame falls
    -- back to General again. General itself keeps its values. One event
    -- for everything.
    function Config.ClearFrameOverrides(keys)
        for _, scope in ipairs(Settings.SCOPES) do
            if scope ~= "general" then
                for _, key in ipairs(keys) do profile[scope][key] = nil end
            end
        end
        ns.Fire(event, nil, nil)
    end

    -- Copying reproduces the source scope's look as it is shown, including
    -- the per-frame defaults it does not override; `source` is a profile,
    -- this one or another (another character's raid profile, a decoded
    -- import). Keys in notCopied stay with the target. Each value is stored
    -- the way Set stores it, as an override only where it differs from the
    -- target's own fallback, so the target ends up a full copy.
    function Config.CopyScopeFrom(source, from, to)
        if type(source) ~= "table" or type(source[from]) ~= "table" or not profile[to] then return end
        if source == profile and from == to then return end
        local target = profile[to]
        for _, def in ipairs(Settings.All()) do
            local key = def.key
            if not notCopied[key] and Settings.AppliesTo(def, to) and Settings.AppliesTo(def, from) then
                local v = valueIn(source, from, def)
                if sameValue(v, fallbackIn(profile, to, def)) then
                    target[key] = nil
                else
                    target[key] = copyValue(v)
                end
            end
        end
        ns.Fire(event, to, nil)
    end

    function Config.CopyScope(from, to)
        Config.CopyScopeFrom(profile, from, to)
    end

    -- Personal settings (the language) stay the reader's own: a shared
    -- profile must not switch the UI to its author's language.
    function Config.Import(p)
        local personal, kept = {}, {}
        for _, def in ipairs(Settings.All()) do
            if def.personal then
                personal[#personal + 1] = def.key
                kept[def.key] = profile.general[def.key]
            end
        end
        for _, scope in ipairs(Settings.SCOPES) do
            profile[scope] = type(p[scope]) == "table" and p[scope] or {}
        end
        for _, key in ipairs(personal) do profile.general[key] = kept[key] end
        ns.Fire(event, nil, nil)
    end

    return Config
end

-- The unit frames. Position and whether a frame is shown at all stay with
-- the target of a copy: copying must not stack two frames or switch one
-- on or off.
ns.Config = ns.NewConfig(ns.Settings, "CONFIG_CHANGED", { x = true, y = true, enabled = true })
```

- [ ] **Step 4: Run the tests**

Run: `tests/run config_factory` → `22 passed, 0 failed`
Run: `tests/run` → Expected: `18687 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Config.lua tests/test_config_factory.lua
git commit -m "Config as a factory; copy a scope from another profile

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Codec factory, encoding a subset of scopes

**Files:**
- Modify: `Core/Codec.lua` (whole file; the body moves into the factory, indented one level)
- Test: `tests/test_codec_factory.lua`

**Interfaces:**
- Consumes: `ns.NewRegistry` (Task 1).
- Produces: `ns.NewCodec(registry) -> Codec` with `Codec.VERSION` (1), `Codec.Encode(profile, scopes?)` (`scopes` limits the output to those scopes, in that order), `Codec.Decode(str) -> profile, nil, rejected | nil, errorKey` (unchanged rules). `ns.Codec = ns.NewCodec(ns.Settings)`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_codec_factory.lua`:

```lua
-- ns.NewCodec (Core/Codec.lua): a codec per registry, and encoding only
-- some scopes (one raid size for an export).
local ns = H.LoadAddon()

local R = ns.NewRegistry({ "general", "a", "b" }, { general = "g", a = "a", b = "b" })
R.Define({ key = "mode", code = "M", scope = "general", type = "bool", default = false })
R.Define({ key = "width", code = "W", scope = "frame", type = "int", min = 1, max = 500, default = 60 })

local Codec = ns.NewCodec(R)
local profile = { general = { mode = true }, a = { width = 90 }, b = { width = 120 } }
H.check("whole profile", Codec.Encode(profile), "1;gM1;aW90;bW120")
H.check("only scope b", Codec.Encode(profile, { "b" }), "1;bW120")
H.check("version", Codec.VERSION, 1)

local back = assert(Codec.Decode("1;gM1;bW120"))
H.check("decode general", back.general.mode, true)
H.check("decode b", back.b.width, 120)
H.checkTrue("decode: every scope present", type(back.a) == "table")
-- A unit-frame string means nothing here: its scopes and codes are not ours.
local foreign = assert(Codec.Decode("1;pW250;yW90"))
H.check("foreign scope ignored", foreign.a.width, nil)

-- The unit-frame codec is unchanged.
H.check("unit frames", ns.Codec.Encode({ player = { width = 250 } }), "1;pW250")
H.check("unit frames decode", ns.Codec.Decode("1;pW250").player.width, 250)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run codec_factory`
Expected: `ERROR test_codec_factory.lua:...: attempt to call field 'NewCodec' (a nil value)`

- [ ] **Step 3: Replace `Core/Codec.lua`**

```lua
local _, ns = ...

-- Compact text form of a profile: only overrides, each as
-- <scope letter><CODE><value>, joined by ";" behind a format version.
-- Used for export/import, storage providers and reading the old macro
-- backup. ns.NewCodec makes one per settings registry: ns.Codec for the
-- unit frames (below), ns.RaidCodec for the raid frames.
local VERSION = 1

-- Trailing whitespace is escaped too: the import field trims the string it
-- is given (and the old macro backup is trimmed on read), which must never
-- shorten a value.
local function hexEscape(c) return ("%%%02X"):format(c:byte()) end
local function escape(s)
    s = s:gsub("%%", "%%25"):gsub(";", "%%3B")
    return (s:gsub("%s+$", function(ws) return (ws:gsub(".", hexEscape)) end))
end
local function unescape(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function hexByte(c) return ("%02x"):format(math.floor(c * 255 + 0.5)) end

function ns.NewCodec(Settings)
    local Codec = { VERSION = VERSION }

    local scopeByPrefix = {}
    for scope, prefix in pairs(Settings.PREFIX) do scopeByPrefix[prefix] = scope end

    local function encodeValue(def, v)
        local t = def.type
        if t == "int" then return ("%d"):format(v) end
        if t == "bool" then return v and "1" or "0" end
        if t == "enum" then
            for i, name in ipairs(def.values) do if name == v then return tostring(i) end end
        end
        if t == "color" then return "#" .. hexByte(v[1]) .. hexByte(v[2]) .. hexByte(v[3]) .. hexByte(v[4]) end
        if t == "media" or t == "text" then return "'" .. escape(v) end
        return nil
    end

    local function decodeValue(def, raw)
        local t = def.type
        if t == "int" then
            local n = raw:match("^%-?%d+$") and tonumber(raw)
            return n and Settings.Validate(def, n)
        end
        if t == "bool" then
            if raw == "1" then return true elseif raw == "0" then return false end
            return nil
        end
        if t == "enum" then
            local i = raw:match("^%d+$") and tonumber(raw)
            return i and def.values[i]
        end
        if t == "color" then
            local r, g, b, a = raw:match("^#(%x%x)(%x%x)(%x%x)(%x%x)$")
            if not r then return nil end
            return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, tonumber(a, 16) / 255 }
        end
        if t == "media" then
            local name = raw:match("^'(.+)$")
            return name and unescape(name)
        end
        if t == "text" then
            local text = raw:match("^'(.*)$")
            return text and Settings.Validate(def, unescape(text))
        end
        return nil
    end

    -- `scopes` (optional) limits the string to those scopes, e.g. one raid
    -- size for an export.
    function Codec.Encode(profile, scopes)
        local parts = { tostring(Codec.VERSION) }
        for _, scope in ipairs(scopes or Settings.SCOPES) do
            local entries = {}
            for key, v in pairs(profile[scope] or {}) do
                local def = Settings.Get(key)
                local text = def and encodeValue(def, v)
                if text then entries[#entries + 1] = { def.code, text } end
            end
            table.sort(entries, function(a, b) return a[1] < b[1] end)
            for _, e in ipairs(entries) do
                parts[#parts + 1] = Settings.PREFIX[scope] .. e[1] .. e[2]
            end
        end
        return table.concat(parts, ";")
    end

    -- Returns profile, nil, rejected; or nil, errorKey. `rejected` counts the
    -- entries that could not be read and were dropped. Forward compatibility
    -- decides what counts:
    -- * An unknown scope or code, a setting on a scope it does not apply to,
    --   or an enum index past the known values is what a newer version may
    --   write. It is skipped and NOT counted: this version cannot use it.
    -- * A known code whose value does not parse for its type, or an entry that
    --   is not <scope><CODE><value> at all (empty ones aside), is data this
    --   version should have understood. It IS counted, so callers can refuse
    --   to write the loss back.
    -- No value format starts with an upper-case letter, so a two-letter code
    -- that only resolves to its first letter is an unknown code, not a bad value.
    function Codec.Decode(str)
        if type(str) ~= "string" or str == "" then return nil, "CODEC_EMPTY" end
        local version = str:match("^(%d+)")
        if not version then return nil, "CODEC_FORMAT" end
        if tonumber(version) ~= Codec.VERSION then return nil, "CODEC_VERSION" end
        local profile = {}
        for _, scope in ipairs(Settings.SCOPES) do profile[scope] = {} end
        local rejected = 0
        local first = true
        for entry in (str .. ";"):gmatch("([^;]*);") do
            local prefix, code, raw = entry:match("^(%l)(%u%u?)(.*)$")
            if first then
                -- The version number; anything glued to it is not an entry.
                first = false
                if entry ~= version then rejected = rejected + 1 end
            elseif not prefix then
                -- An empty entry (";;", a trailing ";") carries nothing to lose.
                if entry ~= "" then rejected = rejected + 1 end
            else
                -- Two-letter codes: prefer the longest code that exists.
                local def = Settings.ByCode(code)
                local shortened = false
                if not def and #code == 2 then
                    def = Settings.ByCode(code:sub(1, 1))
                    raw = code:sub(2) .. raw
                    shortened = true
                end
                local scope = scopeByPrefix[prefix]
                if def and scope and profile[scope] and Settings.AppliesTo(def, scope) then
                    local v = decodeValue(def, raw)
                    if v ~= nil then
                        profile[scope][def.key] = v
                    elseif not shortened and not (def.type == "enum" and raw:match("^%d+$")) then
                        rejected = rejected + 1
                    end
                end
            end
        end
        return profile, nil, rejected
    end

    return Codec
end

ns.Codec = ns.NewCodec(ns.Settings)
```

- [ ] **Step 4: Run the tests**

Run: `tests/run codec` → `40 passed, 0 failed` (the existing `test_codec.lua` included)
Run: `tests/run` → Expected: `18696 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Codec.lua tests/test_codec_factory.lua
git commit -m "Codec as a factory; encode only some scopes

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Raid registry and per-character raid profiles

**Files:**
- Create: `Raid/Settings.lua`
- Create: `Raid/Profiles.lua`
- Modify: `ForeverUnitFrames.toc` (after `Core\Storage.lua`)
- Modify: `tests/mock.lua` (after `function M.SetRaid`)
- Test: `tests/test_raid_profiles.lua`

**Interfaces:**
- Consumes: `ns.NewRegistry`, `ns.NewConfig`, `ns.NewCodec` (Tasks 1–3).
- Produces:
  - `ns.Raid` with `Raid.SIZES = { 10, 20, 40 }`, `Raid.Scope(size) -> "r10" | "r20" | "r40"`.
  - `ns.RaidSettings` (registry; settings `enabled` E, `sizeMode` SM `AUTO|10|20|40`, `showInParty` SP, `hideBlizzard` HB on `general`; `x` X, `y` Y per size).
  - `ns.RaidConfig` (event `RAID_CONFIG_CHANGED`), `ns.RaidCodec`.
  - `ns.RaidProfiles`: `CharKey() -> "Name-Realm"`, `Attach(db)`, `Characters() -> { key, ... }` (others, sorted), `CopySize(fromSize, toSize)`, `CopyFromCharacter(key, fromSize, toSize) -> bool`, `ResetSize(size)`, `Export(size) -> string`, `Import(str, size) -> true | nil, errorKey`.
  - Mock: `M.instance = { type =, maxPlayers = }`, `M.raidMembers`, `M.playerName`, `M.realm`, `M.fullNameRealm`; globals `GetInstanceInfo`, `GetNumGroupMembers`, `UnitFullName`, `GetNormalizedRealmName`.

- [ ] **Step 1: Extend the mock**

In `tests/mock.lua`, directly after the `function M.SetRaid(on) ... end` block inside `M.Reset`, insert:

```lua
    -- Instance and group size (Raid/Size.lua). M.instance holds what
    -- GetInstanceInfo reports as instanceType and maxPlayers; in a raid
    -- GetNumGroupMembers is M.raidMembers, in a party the party plus you.
    M.instance = { type = "none", maxPlayers = 0 }
    M.raidMembers = 0
    _G.GetInstanceInfo = function()
        return "Instance", M.instance.type, 0, "", M.instance.maxPlayers, 0, false, 0, 0, nil, false
    end
    _G.GetNumGroupMembers = function()
        if M.inRaid then return M.raidMembers end
        if #M.group > 0 then return #M.group + 1 end
        return 0
    end
    -- The player's name and realm (Raid/Profiles.lua: one raid profile per
    -- character). UnitFullName may leave the realm out early in the login.
    M.playerName, M.realm, M.fullNameRealm = "Tester", "Testrealm", true
    _G.UnitFullName = function(unit)
        if unit ~= "player" then return nil end
        return M.playerName, M.fullNameRealm and M.realm or nil
    end
    _G.GetNormalizedRealmName = function() return M.realm end
```

Run: `tests/run` → Expected: `18696 passed, 0 failed` (`Elements/ThreatBar.lua` now sees `GetNumGroupMembers`; with `M.raidMembers = 0` nothing changes).

- [ ] **Step 2: Write the failing test**

Create `tests/test_raid_profiles.lua`:

```lua
-- Raid settings and profiles (Raid/Settings.lua, Raid/Profiles.lua): one
-- profile per character with a scope per raid size, copying between sizes
-- and characters, export and import of one size.
local M = H.M
local ns = H.LoadAddon()
local Raid, RS, RC, P = ns.Raid, ns.RaidSettings, ns.RaidConfig, ns.RaidProfiles

H.check("sizes", table.concat(Raid.SIZES, ","), "10,20,40")
H.check("scope of a size", Raid.Scope(20), "r20")
H.check("scopes", table.concat(RS.SCOPES, ","), "general,r10,r20,r40")
H.check("size mode code", RS.Get("sizeMode").code, "SM")
H.check("x is per size", RS.AppliesTo(RS.Get("x"), "general"), false)
H.check("size mode is per character", RS.AppliesTo(RS.Get("sizeMode"), "r10"), false)

-- The character key.
H.check("char key", P.CharKey(), "Tester-Testrealm")
M.fullNameRealm = false
H.check("char key without realm from UnitFullName", P.CharKey(), "Tester-Testrealm")
M.fullNameRealm = true

-- Attach: this character's saved profile, cleaned; others stay as they are.
local db = { raid = {
    ["Tester-Testrealm"] = { general = { sizeMode = "20", bogus = 1 }, r10 = { x = 99999 } },
    ["Healer-Testrealm"] = { r20 = { x = -100, y = 40 } },
    ["Broken-Testrealm"] = "not a table",
} }
P.Attach(db)
H.check("own profile in use", RC.Get("general", "sizeMode"), "20")
H.check("unknown key dropped", db.raid["Tester-Testrealm"].general.bogus, nil)
H.check("value clamped", RC.Get("r10", "x"), 4000)
H.checkTrue("saved table is the one in use", RC.Profile() == db.raid["Tester-Testrealm"])
H.check("other characters, sorted, valid only", table.concat(P.Characters(), ","), "Healer-Testrealm")

-- A new character gets an empty profile in the store.
local fresh = {}
M.playerName = "Newbie"
P.Attach(fresh)
H.checkTrue("new character stored", type(fresh.raid["Newbie-Testrealm"]) == "table")
H.check("defaults", RC.Get("general", "sizeMode"), "AUTO")
M.playerName = "Tester"
P.Attach(db)

-- Changes go straight into SavedVariables and fire the raid event only.
local raidEvents, unitEvents = 0, 0
ns.Listen("RAID_CONFIG_CHANGED", function() raidEvents = raidEvents + 1 end)
ns.Listen("CONFIG_CHANGED", function() unitEvents = unitEvents + 1 end)
RC.Set("r10", "x", -250)
H.check("saved at once", db.raid["Tester-Testrealm"].r10.x, -250)
H.check("raid event", raidEvents, 1)
H.check("no unit-frame event", unitEvents, 0)

-- Copy between sizes: everything, position included.
P.CopySize(10, 40)
H.check("copy size: x", RC.Get("r40", "x"), -250)
P.ResetSize(40)
H.check("reset size", RC.Get("r40", "x"), -600)

-- Copy from another character.
H.checkTrue("copy from character", P.CopyFromCharacter("Healer-Testrealm", 20, 10))
H.check("copied x", RC.Get("r10", "x"), -100)
H.check("copied y", RC.Get("r10", "y"), 40)
H.check("source untouched", db.raid["Healer-Testrealm"].r10, nil)
H.check("unknown character", P.CopyFromCharacter("Nobody-Testrealm", 20, 10), false)
H.check("not from yourself", P.CopyFromCharacter("Tester-Testrealm", 20, 10), false)

-- Export one size, import it on another.
RC.Set("r20", "x", 12)
local s = P.Export(20)
H.check("export holds one size", s, "1;bX12")
H.checkTrue("import", P.Import(s, 40))
H.check("imported on 40", RC.Get("r40", "x"), 12)
RC.Set("r40", "y", 77)
H.checkTrue("import replaces the whole size", P.Import(s, 40))
H.check("y back to default", RC.Get("r40", "y"), 150)
H.checkTrue("defaults-only string resets", P.Import("1", 40))
H.check("reset by import", RC.Get("r40", "x"), -600)
local ok, err = P.Import("garbage", 40)
H.check("bad string refused", ok, nil)
H.check("bad string error", err, "CODEC_FORMAT")
H.check("general not exported", P.Export(10):match(";g"), nil)
```

- [ ] **Step 3: Run test to verify it fails**

Run: `tests/run raid_profiles`
Expected: `ERROR test_raid_profiles.lua:...: attempt to index local 'Raid' (a nil value)`

- [ ] **Step 4: Create `Raid/Settings.lua`**

```lua
local _, ns = ...

-- Every raid-frame setting, in a registry of its own (Core/Registry.lua).
-- "general" holds what applies to the character as a whole; r10, r20 and
-- r40 are one profile per raid size. Codes are permanent, as in
-- Core/Settings.lua, but only unique within this registry.
local Raid = {}
ns.Raid = Raid

Raid.SIZES = { 10, 20, 40 }

-- The scope that holds the profile of a raid size.
function Raid.Scope(size) return "r" .. size end

local RaidSettings = ns.NewRegistry(
    { "general", "r10", "r20", "r40" },
    { general = "g", r10 = "a", r20 = "b", r40 = "c" })
ns.RaidSettings = RaidSettings

-- Character-wide ----------------------------------------------------------------
RaidSettings.Define({ key = "enabled", code = "E", scope = "general", type = "bool", default = true })
-- Which size profile shows (Raid/Size.lua): AUTO follows the raid
-- instance, elsewhere the member count; a number fixes it. Stored by
-- index: append only.
RaidSettings.Define({ key = "sizeMode", code = "SM", scope = "general", type = "enum",
    values = { "AUTO", "10", "20", "40" }, default = "AUTO" })
-- A 5-player group in the raid view (10-player profile), party frames hidden.
RaidSettings.Define({ key = "showInParty", code = "SP", scope = "general", type = "bool", default = false })
-- Blizzard's raid frames hidden while ours are on.
RaidSettings.Define({ key = "hideBlizzard", code = "HB", scope = "general", type = "bool", default = true })

-- Per size ------------------------------------------------------------------------
-- Position of the panel's top left corner, relative to the screen centre.
RaidSettings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000, default = -600 })
RaidSettings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000, default = 150 })
```

The panel position defaults are a starting point; R2 may move them (defaults are not permanent, codes are).

- [ ] **Step 5: Create `Raid/Profiles.lua`**

```lua
local _, ns = ...

-- Raid profiles, one set per character, kept in the account-wide
-- SavedVariables: ForeverUnitFramesDB.raid["Name-Realm"] = { general = {},
-- r10 = {}, r20 = {}, r40 = {} }, overrides only, like the unit-frame
-- profile. Having every character in one table is what lets one copy
-- another's sizes. The table in use is the saved one itself: every change
-- is in SavedVariables at once, nothing has to be flushed.
local Profiles = {}
ns.RaidProfiles = Profiles

local Raid, RaidSettings = ns.Raid, ns.RaidSettings
local RaidConfig = ns.NewConfig(RaidSettings, "RAID_CONFIG_CHANGED", {})
ns.RaidConfig = RaidConfig
local RaidCodec = ns.NewCodec(RaidSettings)
ns.RaidCodec = RaidCodec

local store     -- ForeverUnitFramesDB.raid
local charKey   -- this character's key in it

-- "Name-Realm". UnitFullName can leave the realm out early in the login;
-- the normalised realm name stands in.
function Profiles.CharKey()
    local name, realm = UnitFullName("player")
    if not realm or realm == "" then realm = GetNormalizedRealmName() end
    return name .. "-" .. realm
end

-- At PLAYER_LOGIN: this character's profile, cleaned, becomes the one in use.
function Profiles.Attach(db)
    if type(db.raid) ~= "table" then db.raid = {} end
    store = db.raid
    charKey = Profiles.CharKey()
    local own = store[charKey]
    local profile = RaidSettings.Sanitise(type(own) == "table" and own or {})
    store[charKey] = profile
    RaidConfig.Use(profile)
end

-- The other characters that have a raid profile, sorted.
function Profiles.Characters()
    local keys = {}
    for key, p in pairs(store or {}) do
        if key ~= charKey and type(p) == "table" then keys[#keys + 1] = key end
    end
    table.sort(keys)
    return keys
end

function Profiles.CopySize(fromSize, toSize)
    RaidConfig.CopyScope(Raid.Scope(fromSize), Raid.Scope(toSize))
end

-- Another character's size onto one of ours. False if there is no such
-- character.
function Profiles.CopyFromCharacter(key, fromSize, toSize)
    local source = store and store[key]
    if key == charKey or type(source) ~= "table" then return false end
    RaidConfig.CopyScopeFrom(RaidSettings.Sanitise(source), Raid.Scope(fromSize), Raid.Scope(toSize))
    return true
end

function Profiles.ResetSize(size)
    RaidConfig.ResetScope(Raid.Scope(size))
end

-- One size as a string; the size itself is written as the scope letter.
function Profiles.Export(size)
    return RaidCodec.Encode(RaidConfig.Profile(), { Raid.Scope(size) })
end

-- Puts an exported size on `size`, replacing everything that size had.
-- The first size found in the string counts (an export holds one); a
-- string with none is a size left at the defaults. Returns true, or nil
-- and the codec's error key.
function Profiles.Import(str, size)
    local decoded, err = RaidCodec.Decode(str)
    if not decoded then return nil, err end
    local target = Raid.Scope(size)
    for _, s in ipairs(Raid.SIZES) do
        local scope = Raid.Scope(s)
        if next(decoded[scope]) then
            RaidConfig.CopyScopeFrom(decoded, scope, target)
            return true
        end
    end
    RaidConfig.ResetScope(target)
    return true
end
```

- [ ] **Step 6: Load both after the storage**

In `ForeverUnitFrames.toc`, directly after `Core\Storage.lua`, add:

```
Raid\Settings.lua
Raid\Profiles.lua
```

- [ ] **Step 7: Run the tests**

Run: `tests/run raid_profiles` → `36 passed, 0 failed`
Run: `tests/run` → Expected: `18732 passed, 0 failed`

- [ ] **Step 8: Commit**

```bash
git add Raid/Settings.lua Raid/Profiles.lua ForeverUnitFrames.toc tests/mock.lua tests/test_raid_profiles.lua
git commit -m "Raid settings and per-character profiles per raid size

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Raid size detection

**Files:**
- Create: `Raid/Size.lua`
- Modify: `ForeverUnitFrames.toc` (after `Raid\Profiles.lua`)
- Test: `tests/test_raid_size.lua`

**Interfaces:**
- Consumes: `ns.RaidConfig` (Task 4), mock globals from Task 4.
- Produces: `ns.RaidSize` with `Detect(mode, instanceType, maxPlayers, members) -> 10|20|40` (pure), `Current() -> size | nil`, `Update() -> size | nil` (nil before a raid profile is attached); internal event `RAID_SIZE_CHANGED(size)` on every change. R2 builds and re-lays the panel on this event.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_size.lua`:

```lua
-- Raid size (Raid/Size.lua): fixed mode, raid instance, member count; the
-- change event and what triggers a new look.
local M = H.M
local ns = H.LoadAddon()
local Size, RC = ns.RaidSize, ns.RaidConfig

-- Pure rule.
H.check("fixed 20", Size.Detect("20", "raid", 40, 3), 20)
H.check("fixed 40 outside", Size.Detect("40", "none", 0, 0), 40)
H.check("raid instance 10", Size.Detect("AUTO", "raid", 10, 25), 10)
H.check("raid instance 20, not full", Size.Detect("AUTO", "raid", 20, 6), 20)
H.check("raid instance 40", Size.Detect("AUTO", "raid", 40, 12), 40)
H.check("dungeon: by members", Size.Detect("AUTO", "party", 5, 5), 10)
H.check("outside, 10", Size.Detect("AUTO", "none", 0, 10), 10)
H.check("outside, 11", Size.Detect("AUTO", "none", 0, 11), 20)
H.check("outside, 21", Size.Detect("AUTO", "none", 0, 21), 40)
H.check("solo", Size.Detect("AUTO", "none", 0, 0), 10)
H.check("raid without maxPlayers: by members", Size.Detect("AUTO", "raid", 0, 18), 20)

-- Nothing before the profile is attached.
H.check("no profile yet", Size.Update(), nil)
H.check("no current yet", Size.Current(), nil)

local sizes = {}
ns.Listen("RAID_SIZE_CHANGED", function(size) sizes[#sizes + 1] = size end)
ns.RaidProfiles.Attach({})
H.check("first update", Size.Update(), 10)
H.check("first update fires", sizes[1], 10)
Size.Update()
H.check("no change, no event", #sizes, 1)

-- The client events.
M.inRaid, M.raidMembers = true, 15
M.FireEvent("GROUP_ROSTER_UPDATE")
H.check("roster: 15 members", Size.Current(), 20)
M.instance = { type = "raid", maxPlayers = 40 }
M.FireEvent("PLAYER_ENTERING_WORLD", false, false)
H.check("entering a 40 raid", Size.Current(), 40)
M.instance = { type = "raid", maxPlayers = 10 }
M.FireEvent("ZONE_CHANGED_NEW_AREA")
H.check("zone change", Size.Current(), 10)
M.instance = { type = "raid", maxPlayers = 20 }
M.FireEvent("PLAYER_DIFFICULTY_CHANGED")
H.check("difficulty change", Size.Current(), 20)
M.instance = { type = "raid", maxPlayers = 40 }
M.FireEvent("INSTANCE_GROUP_SIZE_CHANGED")
H.check("group size change", Size.Current(), 40)
H.check("events fired", table.concat(sizes, ","), "10,20,40,10,20,40")

-- The setting.
RC.Set("general", "sizeMode", "10")
H.check("fixed by setting", Size.Current(), 10)
RC.Set("general", "sizeMode", "AUTO")
H.check("back to auto", Size.Current(), 40)
RC.Set("general", "sizeMode", "20")
RC.ResetAll()
H.check("reset: auto again", Size.Current(), 40)
RC.Set("r10", "x", 5)
H.check("other settings: no new size", sizes[#sizes], 40)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run raid_size`
Expected: `ERROR test_raid_size.lua:...: attempt to index local 'Size' (a nil value)`

- [ ] **Step 3: Create `Raid/Size.lua`**

```lua
local _, ns = ...

-- Which size profile is active: 10, 20 or 40. A fixed sizeMode wins.
-- AUTO: inside a raid instance its size (GetInstanceInfo's maxPlayers,
-- never secret), so a raid that is not full yet already gets its layout;
-- elsewhere the member count. A 5-player group is 10. RAID_SIZE_CHANGED
-- (size) fires when it changes.
local Size = {}
ns.RaidSize = Size

local function bucket(n)
    if n <= 10 then return 10 elseif n <= 20 then return 20 end
    return 40
end

-- Pure. mode: the sizeMode setting; instanceType and maxPlayers as
-- GetInstanceInfo returns them; members: GetNumGroupMembers().
function Size.Detect(mode, instanceType, maxPlayers, members)
    if mode ~= "AUTO" then return tonumber(mode) end
    if instanceType == "raid" and type(maxPlayers) == "number" and maxPlayers > 0 then
        return bucket(maxPlayers)
    end
    return bucket(members or 0)
end

local current

-- The active size; nil before the raid profile is attached.
function Size.Current()
    return current
end

function Size.Update()
    if not ns.RaidConfig.Profile() then return nil end
    local _, instanceType, _, _, maxPlayers = GetInstanceInfo()
    local size = Size.Detect(ns.RaidConfig.Get("general", "sizeMode"), instanceType, maxPlayers, GetNumGroupMembers())
    if size ~= current then
        current = size
        ns.Fire("RAID_SIZE_CHANGED", size)
    end
    return size
end

local EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_DIFFICULTY_CHANGED",
    "INSTANCE_GROUP_SIZE_CHANGED", "GROUP_ROSTER_UPDATE" }
for _, event in ipairs(EVENTS) do
    ns.On(event, function() Size.Update() end)
end

-- sizeMode changed, or everything at once (a reset or an import).
ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if scope == nil or (scope == "general" and (key == nil or key == "sizeMode")) then Size.Update() end
end)
```

- [ ] **Step 4: Load it**

In `ForeverUnitFrames.toc`, directly after `Raid\Profiles.lua`, add:

```
Raid\Size.lua
```

- [ ] **Step 5: Run the tests**

Run: `tests/run raid_size` → `26 passed, 0 failed`
Run: `tests/run` → Expected: `18758 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add Raid/Size.lua ForeverUnitFrames.toc tests/test_raid_size.lua
git commit -m "Raid size from the instance or the member count

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Attach the raid profile at login

**Files:**
- Modify: `Core/Boot.lua` (end of the `PLAYER_LOGIN` handler)
- Test: `tests/test_raid_boot.lua`

**Interfaces:**
- Consumes: `ns.RaidProfiles.Attach`, `ns.RaidSize.Update` (Tasks 4–5).
- Produces: after `PLAYER_LOGIN`, `ns.RaidConfig.Profile()` is `ForeverUnitFramesDB.raid["Name-Realm"]` and `ns.RaidSize.Current()` is set.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_boot.lua`:

```lua
-- Raid profiles at login (Core/Boot.lua): attached to this character in
-- the account-wide SavedVariables, size known, unit-frame profile untouched.
local M = H.M
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = { profile = { player = { width = 290 } } }

M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
H.check("no raid profile before login", ns.RaidConfig.Profile(), nil)
M.FireEvent("PLAYER_LOGIN")
H.checkTrue("raid profile in SavedVariables", ForeverUnitFramesDB.raid["Tester-Testrealm"] == ns.RaidConfig.Profile())
H.check("size known", ns.RaidSize.Current(), 10)
H.check("unit frames untouched", ns.Config.Get("player", "width"), 290)

-- A raid change is not a unit-frame change: the unit-frame save is not asked for.
ns.RaidConfig.Set("r20", "x", 33)
M.RunTimers()
H.check("raid value saved", ForeverUnitFramesDB.raid["Tester-Testrealm"].r20.x, 33)
H.check("unit-frame profile still the loaded one", ForeverUnitFramesDB.profile.player.width, 290)

-- Next session: the raid profile comes back.
local saved = ForeverUnitFramesDB
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = saved
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
H.check("raid value back", ns.RaidConfig.Get("r20", "x"), 33)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run raid_boot`
Expected: `ERROR test_raid_boot.lua:...: attempt to index field 'raid' (a nil value)`, `1 passed, 1 failed`

- [ ] **Step 3: Attach in `Core/Boot.lua`**

In the `PLAYER_LOGIN` handler, change

```lua
    ns.Blizzard.HideDefaults()
    ns.MinimapButton.Create()
end)
```

to

```lua
    ns.Blizzard.HideDefaults()
    ns.MinimapButton.Create()
    -- Raid profiles last: nothing above depends on them.
    ns.RaidProfiles.Attach(ForeverUnitFramesDB)
    ns.RaidSize.Update()
end)
```

- [ ] **Step 4: Run the tests**

Run: `tests/run raid_boot` → `7 passed, 0 failed`
Run: `tests/run` → Expected: `18765 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add Core/Boot.lua tests/test_raid_boot.lua
git commit -m "Attach the raid profile at login

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## After the last task

- `./install "<AddOns folder of _classic_beta_>"`, `/reload` in game (new Lua files load with `/reload`): no Lua error at login; `/run print(ForeverUnitFramesDB.raid ~= nil)` after a `/reload` prints `true`. Nothing visible changes — R1 has no frames.
- No release for R1 alone: it ships with R2–R4 (0.22.0).
