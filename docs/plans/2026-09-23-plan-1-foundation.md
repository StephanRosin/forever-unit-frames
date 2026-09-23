# Forever Unit Frames — Plan 1: Foundation and first frames

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A loadable addon with Player and Target frames (health, power, four text slots), hidden Blizzard frames, drag movers, `/fuf` commands, and a complete settings/codec/storage core, all covered by offline tests.

**Architecture:** Small single-purpose Lua files sharing the addon namespace `ns`. A settings registry (`Core/Settings.lua`) is the single source of truth for keys, short codes, types and defaults; `Config`, `Codec`, `Storage` and later the options window all read from it. Unit frames are `SecureUnitButtonTemplate` buttons whose regions are built by element modules (`Build/Update/Style`). Secret values from the client are only ever passed through to widgets.

**Tech Stack:** Lua 5.1 (as in the WoW client), WoW: Forever API (Interface 16001), offline tests with `lua5.1` against a hand-written WoW mock.

Spec: `docs/specs/2026-09-23-forever-unit-frames-design.md`. This is plan 1 of 5:
1. Foundation + Player/Target (this plan)
2. Target of Target, Pet, Focus, Party, Portrait, Castbar
3. Auras with full anchoring
4. Options window + test mode
5. Release packaging

## Global Constraints

- Everything in English: UI strings, file names, identifiers, comments. All user-facing strings through `ns.L` (`Locales/enUS.lua`).
- Target client: WoW: Forever, `## Interface: 16001`. Detect the game by `WOW_PROJECT_ID`, never by interface number.
- Never do arithmetic, comparisons, concatenation or `tostring` on values that may be secret (`UnitHealth`, `UnitHealthMax`, `UnitHealthPercent`, `UnitHealthMissing`, `UnitPower*`, cast and aura data). Pass them to `SetValue`, `SetMinMaxValues`, `SetText`, `SetFormattedText`, `SetStatusBarColor` only. Readability is checked with `ns.Secrets.IsSecret`.
- Never `print` a value that may be secret.
- Never `hooksecurefunc` a frame's Lua mixin method. `HookScript` and hooks on plain tables are allowed.
- No secure snippets: no `WrapScript`, `SecureHandler*` execute, `_onstate-*`, `initialConfigFunction`, `RunAttribute`.
- Secure frames are created, resized, re-anchored and shown/hidden (other than by `RegisterUnitWatch`) only out of combat; everything else goes through `ns.AfterCombat`.
- Setting short codes are permanent: once released, a code is never changed or reused.
- Public repository: no local paths, hostnames, character names or anything about the author's machine in any file or commit message. The local pre-push hook enforces this.
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`

## File structure after this plan

```
ForeverUnitFrames.toc
Locales/enUS.lua          ns.L — all user-facing strings
Core/Init.lua             ns bootstrap, event hub, AfterCombat queue, public API table
Core/Secrets.lua          IsSecret, Number, Bool, Abbreviate, curves
Core/Settings.lua         settings registry (key, code, scope, type, default, limits)
Core/Config.lua           profile access with inheritance and change listeners
Core/Codec.lua            diff-to-defaults string encoding
Core/MacroBackup.lua      read/write encoded string in character macros
Core/Storage.lua          load order, providers, save fan-out
Core/Media.lua            fonts and bar textures
Core/Layout.lua           pure layout maths (bar heights)
Core/Blizzard.lua         hide default Player/Target frames
Core/Movers.lua           drag handles, unlock/lock
Core/Commands.lua         /fuf
Units/Units.lua           unit definitions
Units/Single.lua          frame factory for single units
Elements/Health.lua
Elements/Power.lua
Elements/Texts.lua
Core/Boot.lua             ADDON_LOADED / PLAYER_LOGIN wiring (loaded last)
tests/run                 test entry point
tests/run.lua             runner: loads every tests/test_*.lua
tests/harness.lua         assertions + addon loader
tests/mock.lua            WoW API mock incl. secret values
tests/test_*.lua          one file per unit
install                   copy addon files into an AddOns folder
.gitignore
```

The addon files live in the repository root (the repository *is* the addon folder; `docs/`, `tests/`, `install` are excluded from packages later via `.pkgmeta`).

---

### Task 1: Scaffold, TOC, test harness with secret values

**Files:**
- Create: `ForeverUnitFrames.toc`, `Locales/enUS.lua`, `Core/Init.lua`, `.gitignore`, `install`
- Create: `tests/run`, `tests/run.lua`, `tests/harness.lua`, `tests/mock.lua`, `tests/test_harness.lua`

**Interfaces:**
- Produces: `H.LoadAddon(files?) -> ns` (fresh mock + addon loaded in TOC order, returns namespace); `H.check(label, got, want)`, `H.checkTrue(label, v)`, `H.checkError(label, fn)`; mock `M.Secret(v)` (secret proxy), `M.FireEvent(event, ...)`, `M.SetCombat(bool)`, `M.units[unit] = {...}` unit data table; addon `ns.L`, `ns.On(event, fn)`, `ns.Fire(event, ...)` (internal events), `ns.AfterCombat(key, fn)`, global `ForeverUnitFrames` public table.

- [ ] **Step 1: Create `.gitignore` and `install`**

`.gitignore`:
```
*.swp
.DS_Store
/dist/
```

`install` (executable):
```bash
#!/usr/bin/env bash
# Copy the addon into a WoW AddOns folder.
#   ./install "<path to>/_classic_beta_/Interface/AddOns"
set -eu
DEST="${1:?usage: ./install <AddOns folder>}"
[ -d "$DEST" ] || { echo "Not a directory: $DEST" >&2; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET="$DEST/ForeverUnitFrames"
rm -rf "$TARGET"
mkdir -p "$TARGET"
# Files listed in the TOC plus the TOC itself; nothing else ships.
cp "$HERE/ForeverUnitFrames.toc" "$TARGET/"
grep -v '^\s*#' "$HERE/ForeverUnitFrames.toc" | grep -v '^\s*$' | tr -d '\r' | while read -r f; do
    f="${f//\\//}"
    mkdir -p "$TARGET/$(dirname "$f")"
    cp "$HERE/$f" "$TARGET/$f"
done
echo "Installed to $TARGET"
```

- [ ] **Step 2: Write the TOC with only the files of this task**

`ForeverUnitFrames.toc`:
```
## Interface: 16001
## Title: Forever Unit Frames
## Notes: Clean, flat and fully configurable unit frames for WoW: Forever.
## Author: StephanRosin
## Version: 0.1.0
## SavedVariables: ForeverUnitFramesDB

Locales\enUS.lua
Core\Init.lua
```
Later tasks append their files in the order given in each task. Final order is listed in Task 12.

- [ ] **Step 3: Write `Locales/enUS.lua`**

```lua
local _, ns = ...

-- Missing keys fall back to the key itself, so an untranslated string is
-- visible in-game instead of raising an error.
ns.L = setmetatable({}, { __index = function(_, key) return key end })
local L = ns.L

L.ADDON_NAME = "Forever Unit Frames"
```

- [ ] **Step 4: Write `Core/Init.lua`**

```lua
local ADDON, ns = ...

ns.name = ADDON

-- Public API for other addons (storage providers etc.). Filled by later files.
ForeverUnitFrames = ForeverUnitFrames or {}
ns.api = ForeverUnitFrames

-- Event hub ----------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do list[i](event, ...) end
end)

-- Register fn for a game event. Several handlers per event are allowed and
-- run in registration order.
function ns.On(event, fn)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        eventFrame:RegisterEvent(event)
    end
    list[#list + 1] = fn
end

-- Internal (addon-only) events, e.g. "CONFIG_CHANGED". Never registered
-- with the client.
local internal = {}

function ns.Listen(name, fn)
    internal[name] = internal[name] or {}
    table.insert(internal[name], fn)
end

function ns.Fire(name, ...)
    local list = internal[name]
    if not list then return end
    for i = 1, #list do list[i](...) end
end

-- Combat queue ---------------------------------------------------------------

-- Work that touches secure frames must wait until combat ends. Keyed, so
-- repeated requests for the same work collapse into one run.
local pending, order = {}, {}

function ns.AfterCombat(key, fn)
    if not InCombatLockdown() then
        fn()
        return
    end
    if not pending[key] then order[#order + 1] = key end
    pending[key] = fn
end

function ns.PendingCombatWork()
    return #order
end

ns.On("PLAYER_REGEN_ENABLED", function()
    local keys = order
    order = {}
    for i = 1, #keys do
        local fn = pending[keys[i]]
        pending[keys[i]] = nil
        if fn then fn() end
    end
end)

-- Chat output ----------------------------------------------------------------

-- Only ever pass plain strings here, never values from unit APIs: printing a
-- secret value corrupts the chat history on this client.
function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7" .. ns.L.ADDON_NAME .. ":|r " .. msg)
end
```

- [ ] **Step 5: Write `tests/mock.lua`**

```lua
-- Minimal WoW API mock for offline tests. Lua 5.1 like the client.
local M = {}

-- Secret values ------------------------------------------------------------
-- Real secret values refuse arithmetic, comparison, concatenation and
-- tostring. The proxy below does the same, so any forbidden use fails in a
-- test instead of in combat. Equality against a number cannot be trapped in
-- Lua 5.1 (it is simply false), so code must not rely on it either way.
local secretMeta = {}
local function refuse() error("secret value used in Lua arithmetic/comparison", 2) end
for _, mm in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow",
                      "__unm", "__lt", "__le", "__concat", "__len", "__call" }) do
    secretMeta[mm] = refuse
end
secretMeta.__tostring = refuse
secretMeta.__index = function() refuse() end

function M.Secret(v)
    return setmetatable({ __secret = v }, secretMeta)
end
function M.IsSecret(v)
    return type(v) == "table" and getmetatable(v) == secretMeta
end
function M.Reveal(v)
    if M.IsSecret(v) then return rawget(v, "__secret") end
    return v
end

-- Widgets ------------------------------------------------------------------
local widget = {}
widget.__index = function(t, k)
    -- Unknown CamelCase keys are widget methods that do nothing; anything
    -- else is addon data and must be nil, as in the game.
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local f = function() end
    rawset(t, k, f)
    return f
end

local function newWidget(kind, name, parent)
    local w = setmetatable({
        _kind = kind, _name = name, _parent = parent, _scripts = {},
        _events = {}, _attr = {}, _points = {}, _w = 0, _h = 0, _shown = true,
    }, widget)
    function w:GetName() return self._name end
    function w:GetObjectType() return self._kind end
    function w:SetScript(s, fn) self._scripts[s] = fn end
    function w:GetScript(s) return self._scripts[s] end
    function w:HookScript(s, fn)
        local old = self._scripts[s]
        self._scripts[s] = function(...) if old then old(...) end fn(...) end
    end
    function w:RegisterEvent(e) self._events[e] = true; M.eventFrames[self] = true end
    function w:UnregisterEvent(e) self._events[e] = nil end
    function w:UnregisterAllEvents() self._events = {} end
    function w:SetAttribute(k, v) self._attr[k] = v end
    function w:GetAttribute(k) return self._attr[k] end
    function w:RegisterForClicks(...) self._clicks = { ... } end
    function w:SetSize(a, b) self._w, self._h = a, b end
    function w:SetWidth(v) self._w = v end
    function w:SetHeight(v) self._h = v end
    function w:GetWidth() return self._w end
    function w:GetHeight() return self._h end
    function w:ClearAllPoints() self._points = {} end
    function w:SetPoint(...) table.insert(self._points, { ... }) end
    function w:GetPoint(i) local p = self._points[i or 1]; if p then return unpack(p) end end
    function w:GetCenter() return self._cx or 0, self._cy or 0 end
    function w:Show() self._shown = true end
    function w:Hide() self._shown = false end
    function w:IsShown() return self._shown end
    function w:SetShown(v) self._shown = not not v end
    function w:SetParent(p) self._parent = p end
    function w:GetParent() return self._parent end
    function w:SetAlpha(a) self._alpha = a end
    function w:GetAlpha() return self._alpha or 1 end
    function w:EnableMouse(v) self._mouse = v end
    function w:IsProtected() return self._protected or false end
    function w:GetEffectiveScale() return 1 end
    -- StatusBar
    function w:SetMinMaxValues(a, b) self._min, self._max = a, b end
    function w:GetMinMaxValues() return self._min, self._max end
    function w:SetValue(v) self._value = v end
    function w:GetValue() return self._value end
    function w:SetStatusBarTexture(t) self._texture = t end
    function w:SetStatusBarColor(r, g, b, a) self._color = { r, g, b, a } end
    function w:GetStatusBarTexture() return self._barTex end
    -- Texture
    function w:SetTexture(t) self._texture = t end
    function w:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
    function w:SetVertexColor(r, g, b, a) self._color = { r, g, b, a } end
    function w:SetAllPoints(p) self._allPoints = p or true end
    -- FontString
    function w:SetFont(path, size, flags) self._font = { path, size, flags }; return true end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end
    function w:SetFormattedText(fmt, ...) self._fmt = fmt; self._args = { ... } end
    function w:SetShadowOffset(x, y) self._shadow = { x, y } end
    function w:SetJustifyH(v) self._justifyH = v end
    -- Creation
    function w:CreateTexture(n) return newWidget("Texture", n, self) end
    function w:CreateFontString(n) return newWidget("FontString", n, self) end
    -- Movable
    function w:SetMovable(v) self._movable = v end
    function w:RegisterForDrag(...) self._drag = { ... } end
    function w:StartMoving() end
    function w:StopMovingOrSizing() end
    function w:SetClampedToScreen() end
    return w
end
M.newWidget = newWidget

function M.Reset()
    M.eventFrames = {}
    M.frames = {}
    M.chat = {}
    M.combat = false
    M.units = {}
    M.cvars = {}
    M.macros = {}          -- list of { name=, icon=, body=, perChar= }
    M.macroFrameShown = false

    _G.UIParent = newWidget("Frame", "UIParent")
    _G.UIParent._w, _G.UIParent._h = 1920, 1080
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg)
        assert(type(msg) == "string", "chat message must be a plain string")
        table.insert(M.chat, msg)
    end }
    _G.CreateFrame = function(kind, name, parent, template)
        local w = newWidget(kind, name, parent)
        w._template = template
        if template and template:find("Secure") then w._protected = true end
        if kind == "StatusBar" then w._barTex = newWidget("Texture", nil, w) end
        if name then _G[name] = w end
        table.insert(M.frames, w)
        return w
    end
    _G.InCombatLockdown = function() return M.combat end
    _G.WOW_PROJECT_MAINLINE = 1
    _G.WOW_PROJECT_ID = 1
    _G.GetBuildInfo = function() return "1.60.1", "69977", "Sep 22 2026", 16001 end
    _G.issecretvalue = M.IsSecret
    _G.RegisterUnitWatch = function(f) f._unitWatch = true end
    _G.UnregisterUnitWatch = function(f) f._unitWatch = nil end
    _G.RAID_CLASS_COLORS = {
        WARLOCK = { r = 0.53, g = 0.53, b = 0.93, GetRGB = function(c) return c.r, c.g, c.b end },
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43, GetRGB = function(c) return c.r, c.g, c.b end },
    }
    _G.Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 30 } }
    _G.MacroFrame = { IsShown = function() return M.macroFrameShown end }
    _G.ForeverUnitFrames = nil
    _G.ForeverUnitFramesDB = nil

    -- Unit API: data comes from M.units[unit]; fields may hold secret proxies.
    local function u(unit) return M.units[unit] end
    _G.UnitExists = function(unit) return u(unit) ~= nil end
    _G.UnitName = function(unit) local d = u(unit); return d and d.name end
    _G.UnitLevel = function(unit) local d = u(unit); return d and d.level or 0 end
    _G.UnitClass = function(unit) local d = u(unit); if d then return d.className, d.class end end
    _G.UnitIsPlayer = function(unit) local d = u(unit); return d and d.isPlayer or false end
    _G.UnitIsFriend = function(_, unit) local d = u(unit); return d and d.friend or false end
    _G.UnitReaction = function(unit) local d = u(unit); return d and d.reaction end
    _G.UnitHealth = function(unit) local d = u(unit); return d and d.health or 0 end
    _G.UnitHealthMax = function(unit) local d = u(unit); return d and d.healthMax or 0 end
    _G.UnitHealthMissing = function(unit) local d = u(unit); return d and d.healthMissing or 0 end
    _G.UnitHealthPercent = function(unit, _, curve)
        local d = u(unit); local p = d and d.healthPercent or 0
        if curve then return curve:Evaluate(p) end
        return p
    end
    _G.UnitPower = function(unit) local d = u(unit); return d and d.power or 0 end
    _G.UnitPowerMax = function(unit) local d = u(unit); return d and d.powerMax or 0 end
    _G.UnitPowerType = function(unit) local d = u(unit); return d and d.powerType or 0, d and d.powerToken or "MANA" end
    _G.UnitPowerPercent = function(unit, _, _, curve)
        local d = u(unit); local p = d and d.powerPercent or 0
        if curve then return curve:Evaluate(p) end
        return p
    end
    _G.C_StringUtil = { TruncateWhenZero = function(n) return n end }

    -- Curves: Evaluate passes secrets through as secrets.
    _G.C_CurveUtil = {
        CreateCurve = function()
            local c = { points = {} }
            function c:AddPoint(x, y) table.insert(self.points, { x, y }) end
            function c:Evaluate(x)
                if M.IsSecret(x) then return M.Secret(M.Reveal(x) * 100) end
                return x * 100
            end
            return c
        end,
        CreateColorCurve = function()
            local c = { points = {} }
            function c:AddPoint(x, color) table.insert(self.points, { x, color }) end
            function c:Evaluate() return { GetRGB = function() return 1, 1, 1 end } end
            return c
        end,
    }

    -- CVars
    _G.C_CVar = {
        RegisterCVar = function(name, default) if M.cvars[name] == nil then M.cvars[name] = default or "" end end,
        GetCVar = function(name) return M.cvars[name] end,
        SetCVar = function(name, v) M.cvars[name] = v; return true end,
    }

    -- Macros (character macros live at indices MAX_ACCOUNT_MACROS + 1 ...)
    _G.GetNumMacros = function()
        local n = 0
        for _, m in ipairs(M.macros) do if m.perChar then n = n + 1 end end
        return 0, n
    end
    _G.GetMacroIndexByName = function(name)
        for i, m in ipairs(M.macros) do if m.name == name then return 120 + i end end
        return 0
    end
    _G.GetMacroBody = function(index) local m = M.macros[index - 120]; return m and m.body end
    _G.CreateMacro = function(name, icon, body, perChar)
        assert(#body <= 255, "macro body over 255 characters")
        table.insert(M.macros, { name = name, icon = icon, body = body, perChar = perChar })
        return 120 + #M.macros
    end
    _G.EditMacro = function(index, name, icon, body)
        assert(#body <= 255, "macro body over 255 characters")
        local m = M.macros[index - 120]
        m.name, m.icon, m.body = name, icon, body
        return index
    end
    _G.DeleteMacro = function(index) table.remove(M.macros, index - 120) end

    _G.SlashCmdList = {}
end

function M.SetCombat(v)
    M.combat = v
    if not v then M.FireEvent("PLAYER_REGEN_ENABLED") end
end

function M.FireEvent(event, ...)
    for f in pairs(M.eventFrames) do
        if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
    end
end

return M
```

- [ ] **Step 6: Write `tests/harness.lua`**

```lua
local H = { pass = 0, fail = 0 }
local M = dofile("mock.lua")
H.M = M

local function show(v)
    if M.IsSecret(v) then return "<secret>" end
    return tostring(v)
end

function H.check(label, got, want)
    if got == want then
        H.pass = H.pass + 1
    else
        H.fail = H.fail + 1
        print(("  FAIL %s -> %s (want %s)"):format(label, show(got), show(want)))
    end
end
function H.checkTrue(label, v) H.check(label, not not v, true) end
function H.checkError(label, fn)
    local ok = pcall(fn)
    H.check(label .. " raises", ok, false)
end

-- Files of the addon in TOC order (ignores comments and blank lines).
function H.TocFiles()
    local files = {}
    for line in io.lines(ADDONDIR .. "/ForeverUnitFrames.toc") do
        line = line:gsub("\r", "")
        if not line:match("^%s*#") and line:match("%S") then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    return files
end

-- Fresh mock + fresh namespace, every file loaded like the client does:
-- chunk(addonName, ns). `files` defaults to the whole TOC.
function H.LoadAddon(files)
    M.Reset()
    local ns = {}
    for _, f in ipairs(files or H.TocFiles()) do
        local chunk = assert(loadfile(ADDONDIR .. "/" .. f))
        chunk("ForeverUnitFrames", ns)
    end
    return ns
end

return H
```

- [ ] **Step 7: Write `tests/run.lua` and `tests/run`**

`tests/run.lua`:
```lua
package.path = "./?.lua;" .. package.path
local H = dofile("harness.lua")
_G.H = H

local names = {}
for f in io.popen('ls test_*.lua'):lines() do names[#names + 1] = f end
table.sort(names)
for _, f in ipairs(names) do
    print(f)
    local ok, err = pcall(dofile, f)
    if not ok then H.fail = H.fail + 1; print("  ERROR " .. tostring(err)) end
end
print(("%d passed, %d failed"):format(H.pass, H.fail))
os.exit(H.fail == 0 and 0 or 1)
```

`tests/run` (executable):
```bash
#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
exec lua5.1 -e "ADDONDIR='$(cd "$HERE/.." && pwd)'" run.lua
```

- [ ] **Step 8: Write `tests/test_harness.lua` (the first failing test)**

```lua
local M = H.M

-- The secret proxy must refuse everything real secrets refuse.
local s = M.Secret(50)
H.checkError("secret + 1", function() return s + 1 end)
H.checkError("secret < 1", function() return s < 1 end)
H.checkError("secret .. ''", function() return s .. "" end)
H.checkError("tostring(secret)", function() return tostring(s) end)
H.checkError("format %d secret", function() return ("%d"):format(s) end)
H.checkTrue("IsSecret", M.IsSecret(s))

-- Loading the addon creates the namespace and public table.
local ns = H.LoadAddon()
H.checkTrue("ns.L exists", ns.L)
H.check("unknown locale key falls back", ns.L.SOME_KEY, "SOME_KEY")
H.checkTrue("public API table", ForeverUnitFrames == ns.api)

-- AfterCombat runs now out of combat, later (once, collapsed) in combat.
local runs = 0
ns.AfterCombat("a", function() runs = runs + 1 end)
H.check("runs immediately out of combat", runs, 1)
M.SetCombat(true)
ns.AfterCombat("a", function() runs = runs + 1 end)
ns.AfterCombat("a", function() runs = runs + 1 end)
H.check("deferred in combat", runs, 1)
H.check("one pending job", ns.PendingCombatWork(), 1)
M.SetCombat(false)
H.check("ran once after combat", runs, 2)

-- Chat output accepts plain strings only.
ns.Print("hello")
H.checkTrue("printed", M.chat[1]:find("hello"))
```

- [ ] **Step 9: Run tests**

Run: `chmod +x tests/run install && tests/run`
Expected: all checks pass, last line `N passed, 0 failed`. (If Step 8 was run before Steps 3–4 existed, it fails with a loadfile error — that is the red phase.)

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "Scaffold addon, event hub, combat queue and offline test harness

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Secrets helpers

**Files:**
- Create: `Core/Secrets.lua`
- Modify: `ForeverUnitFrames.toc` (append `Core\Secrets.lua` after `Core\Init.lua`)
- Test: `tests/test_secrets.lua`

**Interfaces:**
- Consumes: `ns` from Task 1.
- Produces: `ns.Secrets.IsSecret(v) -> bool`; `ns.Secrets.Number(v) -> number|nil` (nil if secret or not a number); `ns.Secrets.Bool(fn, ...) -> bool|nil` (calls `fn(...)`, returns a plain boolean, nil if the result is secret or the call fails); `ns.Secrets.Abbreviate(v) -> string|secret` (abbreviated text if readable, otherwise `v` unchanged); `ns.Secrets.PercentCurve() -> curve` (0→0, 1→100, cached).

- [ ] **Step 1: Write the failing test `tests/test_secrets.lua`**

```lua
local M = H.M
local ns = H.LoadAddon()
local S = ns.Secrets

H.checkTrue("IsSecret on proxy", S.IsSecret(M.Secret(1)))
H.check("IsSecret on number", S.IsSecret(5), false)

H.check("Number readable", S.Number(42), 42)
H.check("Number secret -> nil", S.Number(M.Secret(42)), nil)
H.check("Number of string -> nil", S.Number("x"), nil)

H.check("Bool plain true", S.Bool(function() return true end), true)
H.check("Bool plain nil -> false", S.Bool(function() return nil end), false)
H.check("Bool secret -> nil", S.Bool(function() return M.Secret(true) end), nil)
H.check("Bool error -> nil", S.Bool(function() error("x") end), nil)

H.check("Abbreviate small", S.Abbreviate(9876), "9876")
H.check("Abbreviate thousands", S.Abbreviate(12345), "12.3k")
H.check("Abbreviate millions", S.Abbreviate(2500000), "2.5m")
local sec = M.Secret(12345)
H.check("Abbreviate secret passes through", S.Abbreviate(sec), sec)

local c = S.PercentCurve()
H.check("curve cached", S.PercentCurve(), c)
H.check("curve has two points", #c.points, 2)
```

- [ ] **Step 2: Run to see it fail**

Run: `tests/run`
Expected: `test_secrets.lua` ERROR `attempt to index field 'Secrets' (a nil value)`.

- [ ] **Step 3: Write `Core/Secrets.lua`**

```lua
local _, ns = ...

-- Values from unit APIs can be "secret" on this client: they may be handed
-- to widgets but not inspected by Lua. Everything here follows one rule:
-- never calculate, pass through.
local Secrets = {}
ns.Secrets = Secrets

local issecret = issecretvalue or function() return false end

function Secrets.IsSecret(v)
    return issecret(v) == true
end

-- A plain number, or nil when the value is secret or not a number.
function Secrets.Number(v)
    if Secrets.IsSecret(v) then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

-- Call fn(...) and return a plain boolean. Secret results and errors give
-- nil so callers can pick their own fallback.
function Secrets.Bool(fn, ...)
    local ok, v = pcall(fn, ...)
    if not ok or Secrets.IsSecret(v) then return nil end
    return v and true or false
end

-- "12.3k" style text for readable numbers; secret values are returned
-- untouched so SetText/SetFormattedText can still display them in full.
function Secrets.Abbreviate(v)
    local n = Secrets.Number(v)
    if not n then return v end
    if n >= 1000000 then return ("%.1fm"):format(n / 1000000) end
    if n >= 10000 then return ("%.1fk"):format(n / 1000) end
    return ("%d"):format(n)
end

local percentCurve
function Secrets.PercentCurve()
    if not percentCurve then
        percentCurve = C_CurveUtil.CreateCurve()
        percentCurve:AddPoint(0, 0)
        percentCurve:AddPoint(1, 100)
    end
    return percentCurve
end
```

- [ ] **Step 4: Append to TOC and run tests**

TOC: add line `Core\Secrets.lua` after `Core\Init.lua`.
Run: `tests/run` → Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add secret-safe helpers

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Settings registry

**Files:**
- Create: `Core/Settings.lua`
- Modify: `ForeverUnitFrames.toc` (append `Core\Settings.lua`), `Locales/enUS.lua` (setting labels)
- Test: `tests/test_settings.lua`

**Interfaces:**
- Produces:
  - `ns.Settings.SCOPES` — ordered list `{ "general", "player", "target" }` in this plan (later plans append `targettarget`, `pet`, `focus`, `party`).
  - `ns.Settings.PREFIX` — scope → one lowercase letter: `general="g", player="p", target="t", targettarget="o", pet="e", focus="f", party="y"`.
  - `ns.Settings.Define(def)`; `ns.Settings.Get(key) -> def`; `ns.Settings.ByCode(code) -> def`; `ns.Settings.All() -> list in definition order`.
  - `def` fields: `key` (string), `code` (1–2 uppercase letters, unique), `scope` (`"general"` | `"frame"` | `"inherit"`), `type` (`"int"` | `"bool"` | `"enum"` | `"color"` | `"media"`), `default` (value, or table `{ [scope]=value, _=value }` for per-frame defaults), `min`/`max` (int), `values` (enum: ordered list of strings), `mediaKind` (`"font"`|`"statusbar"`).
  - `ns.Settings.Default(def, scope) -> value`.
  - `ns.Settings.Validate(def, value) -> value|nil` (clamped int, known enum, 4-number color table with 0..1 components, string media, boolean).
  - `ns.Settings.AppliesTo(def, scope) -> bool` (`general` scope only for `general`/`inherit`; frame scopes only for `frame`/`inherit`).

- [ ] **Step 1: Write the failing test `tests/test_settings.lua`**

```lua
local ns = H.LoadAddon()
local S = ns.Settings

-- Codes are unique and well-formed.
local seen = {}
for _, def in ipairs(S.All()) do
    H.checkTrue("code format " .. def.key, def.code:match("^%u%u?$"))
    H.check("code unique " .. def.code, seen[def.code], nil)
    seen[def.code] = true
    H.checkTrue("label for " .. def.key, ns.L["SETTING_" .. def.key] ~= "SETTING_" .. def.key)
end

H.check("ByCode", S.ByCode("W").key, "width")
H.check("per-frame default player", S.Default(S.Get("x"), "player"), -300)
H.check("per-frame default target", S.Default(S.Get("x"), "target"), 300)
H.check("plain default", S.Default(S.Get("fontSize"), "general"), 12)

H.check("clamp high", S.Validate(S.Get("width"), 9999), 600)
H.check("clamp low", S.Validate(S.Get("width"), 1), 40)
H.check("int rounds", S.Validate(S.Get("width"), 200.6), 201)
H.check("enum ok", S.Validate(S.Get("fontOutline"), "THICKOUTLINE"), "THICKOUTLINE")
H.check("enum bad", S.Validate(S.Get("fontOutline"), "BOLD"), nil)
H.check("bool ok", S.Validate(S.Get("enabled"), false), false)
H.check("bool bad", S.Validate(S.Get("enabled"), 1), nil)
H.check("color bad", S.Validate(S.Get("healthColor"), { 2, 0, 0, 1 }), nil)
H.check("color ok", S.Validate(S.Get("healthColor"), { 1, 0, 0, 1 })[1], 1)

H.checkTrue("width applies to player", S.AppliesTo(S.Get("width"), "player"))
H.check("width not general", S.AppliesTo(S.Get("width"), "general"), false)
H.checkTrue("fontSize inherits to frames", S.AppliesTo(S.Get("fontSize"), "target"))
```

- [ ] **Step 2: Run to see it fail**

Run: `tests/run` → Expected: ERROR `attempt to index field 'Settings' (a nil value)`.

- [ ] **Step 3: Write `Core/Settings.lua`**

```lua
local _, ns = ...

-- The one list of every setting. Config, Codec, the options window and the
-- tests all read from here. A setting's `code` is written into saved and
-- exported strings: once released it must never change or be reused.
local Settings = {}
ns.Settings = Settings

Settings.SCOPES = { "general", "player", "target" }
Settings.PREFIX = {
    general = "g", player = "p", target = "t", targettarget = "o",
    pet = "e", focus = "f", party = "y",
}

local list, byKey, byCode = {}, {}, {}

function Settings.Define(def)
    assert(not byKey[def.key], "duplicate key " .. def.key)
    assert(not byCode[def.code], "duplicate code " .. def.code)
    list[#list + 1] = def
    byKey[def.key] = def
    byCode[def.code] = def
end

function Settings.Get(key) return byKey[key] end
function Settings.ByCode(code) return byCode[code] end
function Settings.All() return list end

function Settings.Default(def, scope)
    local d = def.default
    if type(d) == "table" and d._ ~= nil then
        local v = d[scope]
        if v == nil then v = d._ end
        return v
    end
    return d
end

function Settings.AppliesTo(def, scope)
    if scope == "general" then return def.scope ~= "frame" end
    return def.scope ~= "general"
end

local function inList(values, v)
    for i = 1, #values do if values[i] == v then return true end end
    return false
end

function Settings.Validate(def, v)
    local t = def.type
    if t == "int" then
        if type(v) ~= "number" then return nil end
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
    end
    return nil
end

-- Definitions -----------------------------------------------------------------
-- Order here is the order of the options pages; codes are permanent.

local TEXT_TAGS = { "NONE", "NAME", "NAME_LEVEL", "LEVEL", "CURRENT", "CURRENT_MAX", "PERCENT", "DEFICIT" }
Settings.TEXT_TAGS = TEXT_TAGS

-- General appearance (inherited by every frame, overridable per frame)
Settings.Define({ key = "fontFace", code = "FF", scope = "inherit", type = "media", mediaKind = "font", default = "Friz Quadrata" })
Settings.Define({ key = "fontSize", code = "FS", scope = "inherit", type = "int", min = 6, max = 32, default = 12 })
Settings.Define({ key = "fontOutline", code = "FO", scope = "inherit", type = "enum",
    values = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME" }, default = "OUTLINE" })
Settings.Define({ key = "fontShadow", code = "FH", scope = "inherit", type = "bool", default = false })
Settings.Define({ key = "barTexture", code = "BT", scope = "inherit", type = "media", mediaKind = "statusbar", default = "Flat" })
Settings.Define({ key = "backgroundColor", code = "BC", scope = "inherit", type = "color", default = { 0, 0, 0, 0.6 } })
Settings.Define({ key = "borderSize", code = "BS", scope = "inherit", type = "int", min = 0, max = 2, default = 1 })
Settings.Define({ key = "borderColor", code = "BO", scope = "inherit", type = "color", default = { 0, 0, 0, 1 } })

-- Colors
Settings.Define({ key = "healthColorMode", code = "HM", scope = "inherit", type = "enum",
    values = { "CLASS", "REACTION", "STATIC", "GRADIENT" }, default = "CLASS" })
Settings.Define({ key = "healthColor", code = "HC", scope = "inherit", type = "color", default = { 0.2, 0.75, 0.3, 1 } })

-- Frame layout
Settings.Define({ key = "enabled", code = "E", scope = "frame", type = "bool", default = true })
Settings.Define({ key = "width", code = "W", scope = "frame", type = "int", min = 40, max = 600,
    default = { player = 220, target = 220, _ = 120 } })
Settings.Define({ key = "height", code = "H", scope = "frame", type = "int", min = 8, max = 200,
    default = { player = 46, target = 46, _ = 28 } })
Settings.Define({ key = "healthPercent", code = "HP", scope = "frame", type = "int", min = 10, max = 100, default = 75 })
Settings.Define({ key = "powerPercent", code = "PP", scope = "frame", type = "int", min = 0, max = 90, default = 25 })
Settings.Define({ key = "powerEnabled", code = "PE", scope = "frame", type = "bool", default = true })
Settings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000,
    default = { player = -300, target = 300, _ = 0 } })
Settings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000,
    default = { player = -220, target = -220, _ = 0 } })

-- Texts
Settings.Define({ key = "textHealthLeft", code = "TL", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "NAME_LEVEL", target = "NAME_LEVEL", _ = "NAME" } })
Settings.Define({ key = "textHealthRight", code = "TR", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "CURRENT_MAX", target = "PERCENT", _ = "NONE" } })
Settings.Define({ key = "textPowerLeft", code = "UL", scope = "frame", type = "enum", values = TEXT_TAGS, default = "NONE" })
Settings.Define({ key = "textPowerRight", code = "UR", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "CURRENT", _ = "NONE" } })
```

- [ ] **Step 4: Add labels to `Locales/enUS.lua`** (append)

```lua
L.SETTING_fontFace = "Font"
L.SETTING_fontSize = "Font size"
L.SETTING_fontOutline = "Font style"
L.SETTING_fontShadow = "Font shadow"
L.SETTING_barTexture = "Bar texture"
L.SETTING_backgroundColor = "Background color"
L.SETTING_borderSize = "Border size"
L.SETTING_borderColor = "Border color"
L.SETTING_healthColorMode = "Health color"
L.SETTING_healthColor = "Static health color"
L.SETTING_enabled = "Enabled"
L.SETTING_width = "Width"
L.SETTING_height = "Height"
L.SETTING_healthPercent = "Health bar height (%)"
L.SETTING_powerPercent = "Power bar height (%)"
L.SETTING_powerEnabled = "Show power bar"
L.SETTING_x = "Position X"
L.SETTING_y = "Position Y"
L.SETTING_textHealthLeft = "Health bar, left text"
L.SETTING_textHealthRight = "Health bar, right text"
L.SETTING_textPowerLeft = "Power bar, left text"
L.SETTING_textPowerRight = "Power bar, right text"
```

- [ ] **Step 5: Append TOC line `Core\Settings.lua`, run tests**

Run: `tests/run` → Expected: `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Add settings registry with permanent short codes

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Config with inheritance and change notification

**Files:**
- Create: `Core/Config.lua`
- Modify: `ForeverUnitFrames.toc` (append `Core\Config.lua`)
- Test: `tests/test_config.lua`

**Interfaces:**
- Consumes: `ns.Settings` (Task 3), `ns.Fire` (Task 1).
- Produces:
  - Profile shape: `{ [scope] = { [key] = value } }` holding **only overrides**.
  - `ns.Config.Use(profile)` — adopt a profile table (missing scopes created).
  - `ns.Config.Profile() -> profile`.
  - `ns.Config.Get(scope, key) -> value` — resolution: own override → (`inherit` settings on frame scopes) general override → default for this scope.
  - `ns.Config.Set(scope, key, value) -> bool` — validates; stores, or removes the override when the value equals what resolution would give without it; fires `ns.Fire("CONFIG_CHANGED", scope, key)`; returns false if invalid or not applicable.
  - `ns.Config.ResetScope(scope)`, `ns.Config.ResetAll()` — fire `CONFIG_CHANGED` with `(scope, nil)` / `(nil, nil)`.
  - `ns.Config.IsOverridden(scope, key) -> bool`.

- [ ] **Step 1: Write the failing test `tests/test_config.lua`**

```lua
local ns = H.LoadAddon()
local C = ns.Config

local changes = {}
ns.Listen("CONFIG_CHANGED", function(scope, key) changes[#changes + 1] = (scope or "*") .. "." .. (key or "*") end)

C.Use({})
H.check("default width player", C.Get("player", "width"), 220)
H.check("default fontSize via general", C.Get("target", "fontSize"), 12)

H.checkTrue("set general font size", C.Set("general", "fontSize", 14))
H.check("target inherits general", C.Get("target", "fontSize"), 14)
H.checkTrue("override on target", C.Set("target", "fontSize", 10))
H.check("target override wins", C.Get("target", "fontSize"), 10)
H.check("player still inherits", C.Get("player", "fontSize"), 14)

-- Setting a value equal to its fallback removes the override.
C.Set("target", "fontSize", 14)
H.check("override removed", C.IsOverridden("target", "fontSize"), false)
C.Set("player", "width", 220)
H.check("default value not stored", C.Profile().player.width, nil)

H.check("invalid value rejected", C.Set("player", "fontOutline", "BOLD"), false)
H.check("frame-only key rejected on general", C.Set("general", "width", 100), false)
H.check("general-applicable ok", C.Set("general", "healthColorMode", "GRADIENT"), true)

-- Colors are copied, not shared.
local col = { 1, 0, 0, 1 }
C.Set("general", "healthColor", col)
col[1] = 0
H.check("color copied", C.Get("player", "healthColor")[1], 1)

H.check("change events fired", changes[1], "general.fontSize")

C.Set("player", "width", 300)
C.ResetScope("player")
H.check("reset scope", C.Get("player", "width"), 220)
C.ResetAll()
H.check("reset all", C.Get("target", "healthColorMode"), "CLASS")
H.check("last event is reset all", changes[#changes], "*.*")
```

- [ ] **Step 2: Run to see it fail**

Run: `tests/run` → Expected: ERROR `attempt to index field 'Config' (a nil value)`.

- [ ] **Step 3: Write `Core/Config.lua`**

```lua
local _, ns = ...

-- Profile access. The profile holds overrides only; everything else comes
-- from inheritance (frame -> general) and the defaults in Settings.
local Config = {}
ns.Config = Config

local Settings = ns.Settings
local profile

local function sameValue(a, b)
    if type(a) == "table" and type(b) == "table" then
        for i = 1, 4 do if a[i] ~= b[i] then return false end end
        return true
    end
    return a == b
end

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

-- What a scope gets when it has no override of its own.
local function fallback(scope, def)
    if scope ~= "general" and def.scope == "inherit" then
        local g = profile.general[def.key]
        if g ~= nil then return g end
        return Settings.Default(def, "general")
    end
    return Settings.Default(def, scope)
end

function Config.Get(scope, key)
    local def = assert(Settings.Get(key), "unknown setting " .. tostring(key))
    local own = profile[scope] and profile[scope][key]
    if own ~= nil then return own end
    return fallback(scope, def)
end

function Config.IsOverridden(scope, key)
    return profile[scope] ~= nil and profile[scope][key] ~= nil
end

function Config.Set(scope, key, value)
    local def = Settings.Get(key)
    if not def or not profile[scope] or not Settings.AppliesTo(def, scope) then return false end
    local v = Settings.Validate(def, value)
    if v == nil then return false end
    if sameValue(v, fallback(scope, def)) then
        profile[scope][key] = nil
    else
        profile[scope][key] = v
    end
    ns.Fire("CONFIG_CHANGED", scope, key)
    return true
end

function Config.ResetScope(scope)
    profile[scope] = {}
    ns.Fire("CONFIG_CHANGED", scope, nil)
end

function Config.ResetAll()
    for _, scope in ipairs(Settings.SCOPES) do profile[scope] = {} end
    ns.Fire("CONFIG_CHANGED", nil, nil)
end
```

- [ ] **Step 4: Append TOC line `Core\Config.lua`, run tests**

Run: `tests/run` → Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add config with general-to-frame inheritance

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Codec (diff-to-defaults string)

**Files:**
- Create: `Core/Codec.lua`
- Modify: `ForeverUnitFrames.toc` (append `Core\Codec.lua`)
- Test: `tests/test_codec.lua`

**Interfaces:**
- Consumes: `ns.Settings` (Task 3); profile shape from Task 4.
- Produces:
  - `ns.Codec.VERSION = 1`
  - `ns.Codec.Encode(profile) -> string` — `"1"` for an empty profile, else `"1;" .. entries joined by ";"`, entries sorted by scope order in `Settings.SCOPES` then by code.
  - `ns.Codec.Decode(str) -> profile | nil, errorKey` — errorKey is `"CODEC_EMPTY"`, `"CODEC_VERSION"` or `"CODEC_FORMAT"`. Unknown scope prefixes and unknown codes are skipped silently; invalid values are skipped.
- Entry grammar: `<prefix lowercase letter><CODE uppercase 1–2 letters><value>`.
  Values: int → decimal (may start with `-`); bool → `0`/`1`; enum → 1-based index; color → `#` + 8 lowercase hex digits (RGBA); media → `'` + name with `%`, `;` escaped as `%25`, `%3B`.

- [ ] **Step 1: Write the failing test `tests/test_codec.lua`**

```lua
local ns = H.LoadAddon()
local Codec, C = ns.Codec, ns.Config

local function deepEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then
        if type(a) == "number" then return math.abs(a - b) < 0.003 end
        return a == b
    end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

C.Use({})
H.check("empty profile", Codec.Encode(C.Profile()), "1")

C.Set("player", "width", 250)
C.Set("player", "enabled", false)
C.Set("target", "textHealthRight", "CURRENT_MAX")
C.Set("general", "healthColor", { 1, 0.5, 0, 1 })
C.Set("general", "fontFace", "My;Font%")
C.Set("target", "x", -120)
local s = Codec.Encode(C.Profile())
H.check("encoded form", s, "1;gFF'My%3BFont%25;gHC#ff8000ff;pE0;pW250;tTR6;tX-120")

local back = assert(Codec.Decode(s))
H.checkTrue("round trip", deepEqual(back, C.Profile()))

-- Robustness
H.check("unknown code skipped", Codec.Decode("1;pZZ5;pW250").player.width, 250)
H.check("unknown scope skipped", Codec.Decode("1;qW250;pW260").player.width, 260)
H.check("invalid value skipped", Codec.Decode("1;pWabc").player.width, nil)
H.check("enum index out of range skipped", Codec.Decode("1;tTR99").target.textHealthRight, nil)
local p, err = Codec.Decode("2;pW250")
H.check("future version rejected", p, nil)
H.check("version error key", err, "CODEC_VERSION")
local _, err2 = Codec.Decode("")
H.check("empty rejected", err2, "CODEC_EMPTY")
local _, err3 = Codec.Decode("hello")
H.check("garbage rejected", err3, "CODEC_FORMAT")

-- Budget: a heavily customised profile stays small.
C.ResetAll()
for _, scope in ipairs({ "player", "target" }) do
    C.Set(scope, "width", 333); C.Set(scope, "height", 55); C.Set(scope, "x", -1234); C.Set(scope, "y", 456)
    C.Set(scope, "healthPercent", 70); C.Set(scope, "powerPercent", 20)
    C.Set(scope, "textHealthLeft", "NAME"); C.Set(scope, "textHealthRight", "PERCENT")
    C.Set(scope, "fontSize", 11); C.Set(scope, "barTexture", "Smooth")
end
C.Set("general", "fontFace", "Arial Narrow"); C.Set("general", "backgroundColor", { 0.1, 0.1, 0.1, 0.8 })
local size = #Codec.Encode(C.Profile())
H.checkTrue("two heavily customised frames under 250 chars (" .. size .. ")", size < 250)
```

- [ ] **Step 2: Run to see it fail**

Run: `tests/run` → Expected: ERROR `attempt to index field 'Codec' (a nil value)`.

- [ ] **Step 3: Write `Core/Codec.lua`**

```lua
local _, ns = ...

-- Compact text form of a profile: only overrides, each as
-- <scope letter><CODE><value>, joined by ";" behind a format version.
-- Used for export/import, the macro backup and storage providers.
local Codec = {}
ns.Codec = Codec
Codec.VERSION = 1

local Settings = ns.Settings

local scopeByPrefix = {}
for scope, prefix in pairs(Settings.PREFIX) do scopeByPrefix[prefix] = scope end

local function escape(s)
    return (s:gsub("%%", "%%25"):gsub(";", "%%3B"))
end
local function unescape(s)
    return (s:gsub("%%3B", ";"):gsub("%%25", "%%"))
end

local function hexByte(c) return ("%02x"):format(math.floor(c * 255 + 0.5)) end

local function encodeValue(def, v)
    local t = def.type
    if t == "int" then return ("%d"):format(v) end
    if t == "bool" then return v and "1" or "0" end
    if t == "enum" then
        for i, name in ipairs(def.values) do if name == v then return tostring(i) end end
    end
    if t == "color" then return "#" .. hexByte(v[1]) .. hexByte(v[2]) .. hexByte(v[3]) .. hexByte(v[4]) end
    if t == "media" then return "'" .. escape(v) end
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
    return nil
end

function Codec.Encode(profile)
    local parts = { tostring(Codec.VERSION) }
    for _, scope in ipairs(Settings.SCOPES) do
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

function Codec.Decode(str)
    if type(str) ~= "string" or str == "" then return nil, "CODEC_EMPTY" end
    local version = str:match("^(%d+)")
    if not version then return nil, "CODEC_FORMAT" end
    if tonumber(version) ~= Codec.VERSION then return nil, "CODEC_VERSION" end
    local profile = {}
    for _, scope in ipairs(Settings.SCOPES) do profile[scope] = {} end
    for entry in (str .. ";"):gmatch("([^;]*);") do
        local prefix, code, raw = entry:match("^(%l)(%u%u?)(.*)$")
        -- Two-letter codes: prefer the longest code that exists.
        if prefix then
            local def = Settings.ByCode(code)
            if not def and #code == 2 then
                def = Settings.ByCode(code:sub(1, 1))
                raw = code:sub(2) .. raw
            end
            local scope = scopeByPrefix[prefix]
            if def and scope and profile[scope] and Settings.AppliesTo(def, scope) then
                local v = decodeValue(def, raw)
                if v ~= nil then profile[scope][def.key] = v end
            end
        end
    end
    return profile
end
```

Note on the two-letter fallback: a one-letter code (`E`, `W`, `H`, `X`, `Y`) followed by an uppercase value never happens (values start with a digit, `-`, `#` or `'`), so `pW250` matches `code="W"` directly because `%u%u?` stops at `2`. The fallback only matters for a hypothetical `pWX…`; it keeps decoding total.

- [ ] **Step 4: Append TOC line `Core\Codec.lua`, run tests**

Run: `tests/run` → Expected: `0 failed`. If the "encoded form" check fails, compare ordering: scope order `general, player, target`, then codes ascending byte order (`FF` < `HC`, `E` < `W`, `TR` < `X`).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add compact diff-to-defaults codec

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Macro backup and storage

**Files:**
- Create: `Core/MacroBackup.lua`, `Core/Storage.lua`
- Modify: `ForeverUnitFrames.toc` (append both, in that order), `Locales/enUS.lua`
- Test: `tests/test_storage.lua`

**Interfaces:**
- Consumes: `ns.Codec`, `ns.Config`, `ns.AfterCombat`, `ns.Listen`, `ns.api`.
- Produces:
  - `ns.MacroBackup.Read() -> string|nil`; `ns.MacroBackup.Write(str) -> bool` (false when in combat, macro frame shown, no free character slot, or string too long for `MAX_MACROS` chunks).
  - Macro names `"FUF Save 1"`, `"FUF Save 2"`; body = header line `#Forever Unit Frames backup i/n - keep` + `"\n"` + chunk; `MAX_MACROS = 2`; icon `"INV_MISC_QUESTIONMARK"`.
  - `ForeverUnitFrames.RegisterStorageProvider(name, provider)` where `provider = { load = function() -> string|nil, save = function(str) }`.
  - `ns.Storage.Load(db) -> profile, source` — `db` is the SavedVariables table (may be nil). Source is `"SavedVariables"`, the provider name, `"macro backup"` or `"defaults"`.
  - `ns.Storage.Save()` — writes `db.profile` (deep copy), calls every provider's `save(encoded)` inside `pcall`, and queues `MacroBackup.Write(encoded)` via `ns.AfterCombat("macroBackup", …)`; skips all writes if the encoded string is unchanged since the last save.
  - `ns.Storage.Source() -> string`.
  - `ns.Storage.Attach(db)` — remembers the SavedVariables table to write into.

- [ ] **Step 1: Write the failing test `tests/test_storage.lua`**

```lua
local M = H.M

-- 1. SavedVariables win when present.
local ns = H.LoadAddon()
local db = { profile = { player = { width = 300 } } }
local p, src = ns.Storage.Load(db)
H.check("source SV", src, "SavedVariables")
H.check("SV value", p.player.width, 300)

-- 2. Provider next.
ns = H.LoadAddon()
ForeverUnitFrames.RegisterStorageProvider("Test provider", {
    load = function() return "1;pW310" end,
    save = function(s) ns._saved = s end,
})
p, src = ns.Storage.Load(nil)
H.check("source provider", src, "Test provider")
H.check("provider value", p.player.width, 310)

-- A broken provider is skipped.
ns = H.LoadAddon()
ForeverUnitFrames.RegisterStorageProvider("Broken", { load = function() error("boom") end, save = function() end })
p, src = ns.Storage.Load(nil)
H.check("broken provider skipped", src, "defaults")

-- 3. Macro backup next.
ns = H.LoadAddon()
ns.MacroBackup.Write("1;pW320")
p, src = ns.Storage.Load(nil)
H.check("source macro", src, "macro backup")
H.check("macro value", p.player.width, 320)

-- 4. Defaults last.
ns = H.LoadAddon()
p, src = ns.Storage.Load(nil)
H.check("source defaults", src, "defaults")
H.check("empty profile", next(p.player), nil)

-- Macro backup details
ns = H.LoadAddon()
local long = "1;" .. string.rep("pW250;", 60)   -- ~362 chars, needs two macros
H.checkTrue("write long", ns.MacroBackup.Write(long))
H.check("two macros", #M.macros, 2)
H.check("macro name", M.macros[1].name, "FUF Save 1")
H.checkTrue("per character", M.macros[1].perChar)
H.check("read back", ns.MacroBackup.Read(), long)
H.checkTrue("shorter write", ns.MacroBackup.Write("1;pW250"))
H.check("second macro emptied", ns.MacroBackup.Read(), "1;pW250")
H.check("too long refused", ns.MacroBackup.Write(string.rep("x", 600)), false)
M.macroFrameShown = true
H.check("refused while macro frame open", ns.MacroBackup.Write("1;pW251"), false)
M.macroFrameShown = false
M.combat = true
H.check("refused in combat", ns.MacroBackup.Write("1;pW251"), false)
M.combat = false

-- Save fans out and skips unchanged strings.
ns = H.LoadAddon()
local saved = {}
ForeverUnitFrames.RegisterStorageProvider("Rec", { load = function() end, save = function(s) saved[#saved + 1] = s end })
local svdb = {}
ns.Storage.Attach(svdb)
p = ns.Storage.Load(svdb)
ns.Config.Use(p)
ns.Config.Set("player", "width", 280)
ns.Storage.Save()
H.check("provider got string", saved[1], "1;pW280")
H.check("SV written", svdb.profile.player.width, 280)
H.check("macro written", ns.MacroBackup.Read(), "1;pW280")
ns.Storage.Save()
H.check("unchanged not re-saved", #saved, 1)
M.combat = true
ns.Config.Set("player", "width", 281)
ns.Storage.Save()
H.check("macro deferred in combat", ns.MacroBackup.Read(), "1;pW280")
M.SetCombat(false)
H.check("macro written after combat", ns.MacroBackup.Read(), "1;pW281")
```

- [ ] **Step 2: Run to see it fail**

Run: `tests/run` → Expected: ERROR `attempt to index field 'Storage'` / `'MacroBackup'` (nil).

- [ ] **Step 3: Write `Core/MacroBackup.lua`**

```lua
local _, ns = ...

-- Stores the encoded profile in character macros. Needed while the client
-- does not load SavedVariables back. A macro body holds 255 characters; the
-- first line marks the macro so players know not to delete it.
local MacroBackup = {}
ns.MacroBackup = MacroBackup

local PREFIX = "FUF Save "
local MAX_MACROS = 2
local BODY_LIMIT = 255
local ICON = "INV_MISC_QUESTIONMARK"

local function header(i, n)
    return ("#Forever Unit Frames backup %d/%d - keep\n"):format(i, n)
end

local function indexOf(i)
    local idx = GetMacroIndexByName(PREFIX .. i)
    if idx and idx > 0 then return idx end
    return nil
end

function MacroBackup.Read()
    local chunks = {}
    for i = 1, MAX_MACROS do
        local idx = indexOf(i)
        if not idx then break end
        local body = GetMacroBody(idx) or ""
        local chunk = body:match("^#[^\n]*\n(.*)$")
        if not chunk or chunk == "" then break end
        chunks[#chunks + 1] = chunk
    end
    if #chunks == 0 then return nil end
    return table.concat(chunks)
end

local function split(str)
    local chunks = {}
    local pos = 1
    while pos <= #str do
        local i = #chunks + 1
        local room = BODY_LIMIT - #header(i, MAX_MACROS)
        chunks[i] = str:sub(pos, pos + room - 1)
        pos = pos + room
    end
    return chunks
end

function MacroBackup.Write(str)
    if InCombatLockdown() then return false end
    if MacroFrame and MacroFrame.IsShown and MacroFrame:IsShown() then return false end
    local chunks = split(str)
    if #chunks > MAX_MACROS then return false end

    local maxChar = Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_CHARACTER_MACROS or 18
    for i = 1, MAX_MACROS do
        local idx = indexOf(i)
        local chunk = chunks[i]
        if chunk then
            local body = header(i, #chunks) .. chunk
            if idx then
                EditMacro(idx, PREFIX .. i, ICON, body)
            else
                local _, numChar = GetNumMacros()
                if numChar >= maxChar then return false end
                CreateMacro(PREFIX .. i, ICON, body, true)
            end
        elseif idx then
            -- Fewer chunks than before: blank the leftover macro so Read stops.
            EditMacro(idx, PREFIX .. i, ICON, header(i, #chunks))
        end
    end
    return true
end
```

- [ ] **Step 4: Write `Core/Storage.lua`**

```lua
local _, ns = ...

-- Where the profile comes from and where it goes. Load order:
-- SavedVariables -> registered providers -> macro backup -> defaults.
local Storage = {}
ns.Storage = Storage

local providers = {}      -- ordered list of { name =, load =, save = }
local attached            -- the SavedVariables table
local source = "defaults"
local lastSaved

function ns.api.RegisterStorageProvider(name, provider)
    assert(type(name) == "string" and name ~= "", "provider name required")
    assert(type(provider) == "table" and type(provider.load) == "function"
        and type(provider.save) == "function", "provider needs load and save")
    providers[#providers + 1] = { name = name, load = provider.load, save = provider.save }
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

local function fromString(str)
    if type(str) ~= "string" then return nil end
    return (ns.Codec.Decode(str))
end

function Storage.Attach(db)
    attached = db
end

function Storage.Load(db)
    if type(db) == "table" and type(db.profile) == "table" then
        source = "SavedVariables"
        return copy(db.profile), source
    end
    for _, p in ipairs(providers) do
        local ok, str = pcall(p.load)
        local profile = ok and fromString(str)
        if profile then
            source = p.name
            return profile, source
        end
    end
    local profile = fromString(ns.MacroBackup.Read())
    if profile then
        source = "macro backup"
        return profile, source
    end
    source = "defaults"
    return fromString("1"), source
end

function Storage.Source()
    return source
end

function Storage.Save()
    local profile = ns.Config.Profile()
    local encoded = ns.Codec.Encode(profile)
    if encoded == lastSaved then return end
    lastSaved = encoded
    if attached then
        attached.version = ns.Codec.VERSION
        attached.profile = copy(profile)
    end
    for _, p in ipairs(providers) do pcall(p.save, encoded) end
    ns.AfterCombat("macroBackup", function() ns.MacroBackup.Write(encoded) end)
end
```

- [ ] **Step 5: Append TOC lines `Core\MacroBackup.lua`, `Core\Storage.lua`; run tests**

Run: `tests/run` → Expected: `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Add storage: SavedVariables, providers and macro backup

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Media and layout maths

**Files:**
- Create: `Core/Media.lua`, `Core/Layout.lua`
- Modify: `ForeverUnitFrames.toc` (append both)
- Test: `tests/test_media_layout.lua`

**Interfaces:**
- Produces:
  - `ns.Media.Font(name) -> path`, `ns.Media.StatusBar(name) -> path` (unknown names fall back to the first entry); `ns.Media.List(kind) -> sorted list of names` (`kind` = `"font"`|`"statusbar"`); uses LibSharedMedia-3.0 via `LibStub` when loaded.
  - Built-in fonts: `Friz Quadrata = Fonts\FRIZQT__.TTF`, `Arial Narrow = Fonts\ARIALN.TTF`, `Skurri = Fonts\skurri.ttf`, `Morpheus = Fonts\MORPHEUS.ttf`.
  - Built-in bars: `Flat = Interface\Buttons\WHITE8X8`, `Blizzard = Interface\TargetingFrame\UI-StatusBar`, `Raid = Interface\RaidFrame\Raid-Bar-Hp-Fill`.
  - `ns.Layout.Bars(height, healthPercent, powerPercent, powerEnabled) -> healthH, gap, powerH` (integers; `healthH + gap + powerH == height`).

- [ ] **Step 1: Write the failing test `tests/test_media_layout.lua`**

```lua
local ns = H.LoadAddon()

H.check("known font", ns.Media.Font("Arial Narrow"), "Fonts\\ARIALN.TTF")
H.check("unknown font falls back", ns.Media.Font("Nope"), "Fonts\\FRIZQT__.TTF")
H.check("bar texture", ns.Media.StatusBar("Flat"), "Interface\\Buttons\\WHITE8X8")
H.check("font list sorted", ns.Media.List("font")[1], "Arial Narrow")

local L = ns.Layout
local h, g, p = L.Bars(48, 75, 25, true)
H.check("75/25 health", h, 36); H.check("75/25 gap", g, 0); H.check("75/25 power", p, 12)
h, g, p = L.Bars(48, 70, 20, true)
H.check("70/20 gap", g, 5); H.check("sum", h + g + p, 48)
h, g, p = L.Bars(48, 90, 30, true)
H.check("over 100 clamps power", h + g + p, 48); H.check("over 100 no gap", g, 0)
h, g, p = L.Bars(48, 60, 25, false)
H.check("no power: health fills", h, 48); H.check("no power: zero power", p, 0)
h, g, p = L.Bars(10, 75, 25, true)
H.checkTrue("tiny frame keeps 1px power", p >= 1)
```

- [ ] **Step 2: Run to see it fail**

Run: `tests/run` → Expected: ERROR on `ns.Media` (nil).

- [ ] **Step 3: Write `Core/Media.lua`**

```lua
local _, ns = ...

-- Fonts and bar textures. Settings store the *name*, never the path, so a
-- profile survives when files move. LibSharedMedia is used if another addon
-- loaded it; we do not ship it.
local Media = {}
ns.Media = Media

local builtin = {
    font = {
        ["Friz Quadrata"] = "Fonts\\FRIZQT__.TTF",
        ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
        ["Skurri"] = "Fonts\\skurri.ttf",
        ["Morpheus"] = "Fonts\\MORPHEUS.ttf",
    },
    statusbar = {
        ["Flat"] = "Interface\\Buttons\\WHITE8X8",
        ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
        ["Raid"] = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    },
}
local fallback = { font = "Friz Quadrata", statusbar = "Flat" }

local function lsm()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

local function fetch(kind, name)
    local path = builtin[kind][name]
    if path then return path end
    local lib = lsm()
    if lib and name and lib:IsValid(kind, name) then return lib:Fetch(kind, name) end
    return builtin[kind][fallback[kind]]
end

function Media.Font(name) return fetch("font", name) end
function Media.StatusBar(name) return fetch("statusbar", name) end

function Media.List(kind)
    local names, seen = {}, {}
    for name in pairs(builtin[kind]) do names[#names + 1] = name; seen[name] = true end
    local lib = lsm()
    if lib then
        for _, name in ipairs(lib:List(kind)) do
            if not seen[name] then names[#names + 1] = name end
        end
    end
    table.sort(names)
    return names
end
```

- [ ] **Step 4: Write `Core/Layout.lua`**

```lua
local _, ns = ...

-- Pure layout maths, kept free of widgets so it can be tested directly.
local Layout = {}
ns.Layout = Layout

local function round(v) return math.floor(v + 0.5) end

-- Split a frame height into health bar, gap and power bar. Percentages are
-- of the whole frame; whatever they leave over becomes the gap. With the
-- power bar off, health takes everything.
function Layout.Bars(height, healthPercent, powerPercent, powerEnabled)
    if not powerEnabled or powerPercent <= 0 then
        return height, 0, 0
    end
    local powerH = math.max(1, round(height * powerPercent / 100))
    local healthH = round(height * healthPercent / 100)
    if healthH + powerH > height then
        healthH = height - powerH
    end
    healthH = math.max(1, healthH)
    return healthH, height - healthH - powerH, powerH
end
```

- [ ] **Step 5: Append TOC lines `Core\Media.lua`, `Core\Layout.lua`; run tests**

Run: `tests/run` → Expected: `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Add media lists and bar layout maths

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Unit definitions, frame factory and Health element

**Files:**
- Create: `Units/Units.lua`, `Units/Single.lua`, `Elements/Health.lua`
- Modify: `ForeverUnitFrames.toc` (append `Units\Units.lua`, `Elements\Health.lua`, `Units\Single.lua` — elements before the factory)
- Test: `tests/test_health.lua`

**Interfaces:**
- Consumes: `ns.Config.Get`, `ns.Media`, `ns.Layout.Bars`, `ns.Secrets`, `ns.AfterCombat`, `ns.On`, `ns.Listen`.
- Produces:
  - `ns.Units.List` — ordered `{ { key = "player", unit = "player", events = { "PLAYER_ENTERING_WORLD" } }, { key = "target", unit = "target", events = { "PLAYER_TARGET_CHANGED" } } }`.
  - `ns.Elements` — ordered list; each element is `{ name = string, unitEvents = { EVENT, ... }, Build = fn(frame), Update = fn(frame, event), Style = fn(frame) }`. `ns.RegisterElement(element)` appends.
  - `ns.Frames` — map key → frame. Frame fields: `frame.key`, `frame.unit`, `frame.health` (StatusBar), `frame.healthBg` (Texture), `frame.power`, `frame.powerBg`, `frame.border` (Texture list), `frame.texts` (Task 9).
  - `ns.Single.Create(def) -> frame` (out of combat only), `ns.Single.UpdateAll(frame, event)`, `ns.Single.StyleAll(frame)`, `ns.Single.CreateAll()`.
  - Unit events are dispatched: `UNIT_*` events with a unit argument go to frames whose `frame.unit` equals it; frame-specific events (e.g. `PLAYER_TARGET_CHANGED`) trigger a full update of that frame.
  - `ns.Health.ColorFor(frame) -> r, g, b` (may return secret numbers for GRADIENT).

- [ ] **Step 1: Write the failing test `tests/test_health.lua`**

```lua
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()

local f = ns.Frames.player
H.check("secure template", f._template, "SecureUnitButtonTemplate")
H.check("unit attribute", f:GetAttribute("unit"), "player")
H.check("left click targets", f:GetAttribute("*type1"), "target")
H.check("right click menu", f:GetAttribute("*type2"), "togglemenu")
H.checkTrue("unit watch", f._unitWatch)
H.check("width from config", f:GetWidth(), 220)

-- Health bar height follows the layout maths (power bar arrives in Task 9).
local hh = ns.Layout.Bars(46, 75, 25, true)
H.check("health height", f.health:GetHeight(), hh)

-- Secret health values pass straight through to the bar.
local hp, hpMax = M.Secret(900), M.Secret(1000)
M.units.player = { name = "Tester", level = 60, class = "WARLOCK", className = "Warlock",
    isPlayer = true, health = hp, healthMax = hpMax, healthPercent = M.Secret(0.9) }
M.FireEvent("UNIT_HEALTH", "player")
H.check("bar value is the secret", f.health:GetValue(), hp)
local _, max = f.health:GetMinMaxValues()
H.check("bar max is the secret", max, hpMax)

-- Class colour
local c = f.health._color
H.check("class color r", c[1], RAID_CLASS_COLORS.WARLOCK.r)

-- Other units' events do not touch this frame.
M.units.target = { health = 5, healthMax = 10 }
M.FireEvent("UNIT_HEALTH", "target")
H.check("player unchanged by target event", f.health:GetValue(), hp)

-- Reaction mode with a secret reaction falls back to UnitIsFriend.
ns.Config.Set("target", "healthColorMode", "REACTION")
M.units.target = { health = 5, healthMax = 10, reaction = M.Secret(2), friend = false }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("hostile red via fallback", ns.Frames.target.health._color[1], 0.85)

-- Config change restyles out of combat, defers in combat.
ns.Config.Set("player", "width", 250)
H.check("restyled", f:GetWidth(), 250)
M.combat = true
ns.Config.Set("player", "width", 260)
H.check("deferred in combat", f:GetWidth(), 250)
M.SetCombat(false)
H.check("applied after combat", f:GetWidth(), 260)

-- Disabled frames lose their unit watch and hide.
ns.Config.Set("target", "enabled", false)
H.check("disabled: no watch", ns.Frames.target._unitWatch, nil)
H.check("disabled: hidden", ns.Frames.target:IsShown(), false)
```

- [ ] **Step 2: Run to see it fail**

Run: `tests/run` → Expected: ERROR `attempt to index field 'Single' (a nil value)`.

- [ ] **Step 3: Write `Units/Units.lua`**

```lua
local _, ns = ...

-- Which frames exist and which game events make them refresh completely.
ns.Units = {}
ns.Units.List = {
    { key = "player", unit = "player", events = { "PLAYER_ENTERING_WORLD" } },
    { key = "target", unit = "target", events = { "PLAYER_TARGET_CHANGED" } },
}

ns.Elements = {}
function ns.RegisterElement(element)
    ns.Elements[#ns.Elements + 1] = element
end
```

- [ ] **Step 4: Write `Elements/Health.lua`**

```lua
local _, ns = ...

local Health = { name = "Health", unitEvents = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION" } }
ns.Health = Health

local Secrets, Config = ns.Secrets, ns.Config

local REACTION = {
    hostile = { 0.85, 0.2, 0.2 },
    neutral = { 0.9, 0.8, 0.25 },
    friendly = { 0.2, 0.75, 0.3 },
}

local gradientCurve
local function gradient()
    if not gradientCurve then
        gradientCurve = C_CurveUtil.CreateColorCurve()
        gradientCurve:AddPoint(0, CreateColor(0.85, 0.2, 0.2))
        gradientCurve:AddPoint(0.5, CreateColor(0.9, 0.8, 0.25))
        gradientCurve:AddPoint(1, CreateColor(0.2, 0.75, 0.3))
    end
    return gradientCurve
end

local function reactionColor(unit)
    local r = Secrets.Number(UnitReaction(unit, "player"))
    if r then
        if r <= 3 then return REACTION.hostile end
        if r == 4 then return REACTION.neutral end
        return REACTION.friendly
    end
    -- Reaction can be secret; friend/foe is the coarse fallback.
    if Secrets.Bool(UnitIsFriend, "player", unit) then return REACTION.friendly end
    return REACTION.hostile
end

function Health.ColorFor(frame)
    local scope, unit = frame.key, frame.unit
    local mode = Config.Get(scope, "healthColorMode")
    if mode == "CLASS" and Secrets.Bool(UnitIsPlayer, unit) then
        local ok, c = pcall(function()
            local _, class = UnitClass(unit)
            return RAID_CLASS_COLORS[class]
        end)
        if ok and c then return c.r, c.g, c.b end
    end
    if mode == "CLASS" or mode == "REACTION" then
        local c = reactionColor(unit)
        return c[1], c[2], c[3]
    end
    if mode == "GRADIENT" then
        return UnitHealthPercent(unit, true, gradient()):GetRGB()
    end
    local c = Config.Get(scope, "healthColor")
    return c[1], c[2], c[3]
end

function Health.Build(frame)
    frame.health = CreateFrame("StatusBar", nil, frame)
    frame.healthBg = frame.health:CreateTexture(nil, "BACKGROUND")
    frame.healthBg:SetAllPoints(frame.health)
end

function Health.Style(frame)
    local scope = frame.key
    local tex = ns.Media.StatusBar(Config.Get(scope, "barTexture"))
    frame.health:SetStatusBarTexture(tex)
    frame.healthBg:SetTexture(tex)
    local bg = Config.Get(scope, "backgroundColor")
    frame.healthBg:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
end

function Health.Update(frame)
    local unit = frame.unit
    frame.health:SetMinMaxValues(0, UnitHealthMax(unit))
    frame.health:SetValue(UnitHealth(unit))
    frame.health:SetStatusBarColor(Health.ColorFor(frame))
end

ns.RegisterElement(Health)
```

`CreateColor` exists in the client (`Blizzard_SharedXMLBase/Color.lua`). Add it to the mock in `tests/mock.lua` inside `M.Reset()`:
```lua
    _G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGB = function(c) return c.r, c.g, c.b end } end
```

- [ ] **Step 5: Write `Units/Single.lua`**

```lua
local _, ns = ...

-- Builds single-unit frames (player, target, ...) and routes events to
-- their elements. Frames are secure buttons; everything that touches their
-- size, anchors or visibility runs out of combat.
local Single = {}
ns.Single = Single
ns.Frames = {}

local Config, Layout = ns.Config, ns.Layout

local function place(frame)
    local scope = frame.key
    frame:SetSize(Config.Get(scope, "width"), Config.Get(scope, "height"))
    frame:ClearAllPoints()
    local anchor = frame.mover or UIParent
    if frame.mover then
        frame:SetPoint("CENTER", frame.mover, "CENTER", 0, 0)
    else
        frame:SetPoint("CENTER", anchor, "CENTER", Config.Get(scope, "x"), Config.Get(scope, "y"))
    end
end

local function layoutBars(frame)
    local scope = frame.key
    local height = Config.Get(scope, "height")
    local powerOn = Config.Get(scope, "powerEnabled")
    local hh, gap, ph = Layout.Bars(height, Config.Get(scope, "healthPercent"),
        Config.Get(scope, "powerPercent"), powerOn)
    frame.health:ClearAllPoints()
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.health:SetHeight(hh)
    frame.power:ClearAllPoints()
    frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.power:SetHeight(math.max(ph, 1))
    frame.power:SetShown(powerOn and ph > 0)
    frame.gap = gap
end

local function border(frame)
    local size = Config.Get(frame.key, "borderSize")
    local c = Config.Get(frame.key, "borderColor")
    if not frame.border then
        frame.border = {}
        for i = 1, 4 do frame.border[i] = frame:CreateTexture(nil, "OVERLAY") end
    end
    local b = frame.border
    -- top, bottom, left, right; drawn just outside the frame
    b[1]:ClearAllPoints(); b[1]:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -size, 0); b[1]:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", size, 0); b[1]:SetHeight(size)
    b[2]:ClearAllPoints(); b[2]:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -size, 0); b[2]:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", size, 0); b[2]:SetHeight(size)
    b[3]:ClearAllPoints(); b[3]:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0); b[3]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0); b[3]:SetWidth(size)
    b[4]:ClearAllPoints(); b[4]:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0); b[4]:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0); b[4]:SetWidth(size)
    for i = 1, 4 do
        b[i]:SetColorTexture(c[1], c[2], c[3], c[4])
        b[i]:SetShown(size > 0)
    end
end

local function applyEnabled(frame)
    if Config.Get(frame.key, "enabled") then
        RegisterUnitWatch(frame)
    else
        UnregisterUnitWatch(frame)
        frame:Hide()
    end
end

function Single.UpdateAll(frame, event)
    if not UnitExists(frame.unit) then return end
    for _, el in ipairs(ns.Elements) do el.Update(frame, event) end
end

function Single.StyleAll(frame)
    place(frame)
    layoutBars(frame)
    border(frame)
    for _, el in ipairs(ns.Elements) do el.Style(frame) end
    applyEnabled(frame)
    Single.UpdateAll(frame)
end

function Single.Create(def)
    local frame = CreateFrame("Button", "ForeverUnitFrames_" .. def.key, UIParent, "SecureUnitButtonTemplate")
    frame.key, frame.unit = def.key, def.unit
    frame:SetAttribute("unit", def.unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
    frame:RegisterForClicks("AnyUp")
    for _, el in ipairs(ns.Elements) do el.Build(frame) end
    ns.Frames[def.key] = frame
    Single.StyleAll(frame)
    return frame
end

-- Event routing ----------------------------------------------------------------

local unitEventsRegistered = false
local function registerUnitEvents()
    if unitEventsRegistered then return end
    unitEventsRegistered = true
    local seen = {}
    for _, el in ipairs(ns.Elements) do
        for _, event in ipairs(el.unitEvents or {}) do
            if not seen[event] then
                seen[event] = true
                ns.On(event, function(_, unit)
                    for _, frame in pairs(ns.Frames) do
                        if frame.unit == unit and UnitExists(unit) then el.Update(frame, event) end
                    end
                end)
            end
        end
    end
end

function Single.CreateAll()
    ns.AfterCombat("createSingle", function()
        for _, def in ipairs(ns.Units.List) do
            if not ns.Frames[def.key] then
                local frame = Single.Create(def)
                for _, event in ipairs(def.events) do
                    ns.On(event, function(e) Single.UpdateAll(frame, e) end)
                end
            end
        end
        registerUnitEvents()
    end)
end

ns.Listen("CONFIG_CHANGED", function(scope)
    ns.AfterCombat("restyle", function()
        for key, frame in pairs(ns.Frames) do
            if scope == nil or scope == "general" or scope == key then Single.StyleAll(frame) end
        end
    end)
end)
```

Note: the registerUnitEvents closure iterates elements; each element registers per event, so two elements sharing an event register two handlers — fine, each updates only itself.

The Power element does not exist yet; `layoutBars` needs `frame.power`. Create a placeholder in this task by adding Task 9's Power element **before** running tests, or temporarily guard: this plan orders Task 9 immediately after — to keep Task 8 green on its own, `Single.lua` must not require `frame.power`. Use this guard in `layoutBars` instead of the unguarded power lines:

```lua
    if frame.power then
        frame.power:ClearAllPoints()
        frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame.power:SetHeight(math.max(ph, 1))
        frame.power:SetShown(powerOn and ph > 0)
    end
```
The "power height" check lives in Task 9's test.

- [ ] **Step 6: Append TOC lines in this order: `Units\Units.lua`, `Elements\Health.lua`, `Units\Single.lua`; run tests**

Run: `tests/run` → Expected: `0 failed`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Add secure frame factory and health element

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Power and Texts elements

**Files:**
- Create: `Elements/Power.lua`, `Elements/Texts.lua`
- Modify: `ForeverUnitFrames.toc` (append `Elements\Power.lua`, `Elements\Texts.lua` directly after `Elements\Health.lua`, before `Units\Single.lua`)
- Test: `tests/test_power_texts.lua`

**Interfaces:**
- Consumes: Task 8 frame fields and element interface; `ns.Secrets`; `ns.Settings.TEXT_TAGS`.
- Produces: `frame.power`, `frame.powerBg`; `frame.texts = { healthLeft, healthRight, powerLeft, powerRight }` (FontStrings); `ns.Power.COLORS` indexed by power type number; `ns.Texts.Apply(fontString, tag, unit, kind)` with `kind` = `"health"`|`"power"`.

- [ ] **Step 1: Write the failing test `tests/test_power_texts.lua`**

```lua
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
M.units.player = { name = "Tester", level = 60, class = "WARLOCK", className = "Warlock", isPlayer = true,
    health = M.Secret(900), healthMax = M.Secret(1000), healthPercent = M.Secret(0.9), healthMissing = M.Secret(100),
    power = M.Secret(400), powerMax = M.Secret(500), powerPercent = M.Secret(0.8), powerType = 0 }
ns.Single.CreateAll()
local f = ns.Frames.player

local _, _, ph = ns.Layout.Bars(46, 75, 25, true)
H.check("power height", f.power:GetHeight(), ph)
H.check("power value secret passthrough", f.power:GetValue(), M.units.player.power)
H.check("mana colour", f.power._color[3], ns.Power.COLORS[0][3])

-- Player defaults: health left NAME_LEVEL, health right CURRENT_MAX, power right CURRENT.
local t = f.texts
H.check("name level format", t.healthLeft._fmt, "%s %s")
H.check("name level level arg", t.healthLeft._args[1], "60")
H.check("current/max format", t.healthRight._fmt, "%s / %s")
H.check("current/max passes secret", t.healthRight._args[1], M.units.player.health)
H.check("power current secret", t.powerRight._text, M.units.player.power)
H.check("unused slot empty", t.powerLeft._text, "")

-- Readable values are abbreviated.
M.units.player.health, M.units.player.healthMax = 12345, 20000
M.FireEvent("UNIT_HEALTH", "player")
H.check("abbreviated when readable", t.healthRight._args[1], "12.3k")

-- Percent uses the curve and a format, never Lua maths.
ns.Config.Set("player", "textHealthRight", "PERCENT")
H.check("percent format", t.healthRight._fmt, "%.0f%%")

-- Deficit via TruncateWhenZero
ns.Config.Set("player", "textHealthRight", "DEFICIT")
H.check("deficit passes through", t.healthRight._text, M.units.player.healthMissing)

-- Level ?? for unknown (-1) level
M.units.target = { name = "Boss", level = -1, health = 1, healthMax = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("boss level", ns.Frames.target.texts.healthLeft._args[1], "??")

-- Power bar off hides it and health fills the frame.
ns.Config.Set("player", "powerEnabled", false)
H.check("power hidden", f.power:IsShown(), false)
H.check("health full height", f.health:GetHeight(), 46)

-- Fonts follow config
ns.Config.Set("general", "fontSize", 15)
H.check("font size applied", t.healthLeft._font[2], 15)
H.check("font outline applied", t.healthLeft._font[3], "OUTLINE")
```

- [ ] **Step 2: Run to see it fail**

Run: `tests/run` → Expected: failures/ERROR on `f.power` nil.

- [ ] **Step 3: Write `Elements/Power.lua`**

```lua
local _, ns = ...

local Power = { name = "Power", unitEvents = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" } }
ns.Power = Power

local Config = ns.Config

-- Own colours: Blizzard's PowerBarColor is only guaranteed on mainline
-- game types. Index = power type number.
Power.COLORS = {
    [0] = { 0.25, 0.5, 1.0 },   -- mana
    [1] = { 0.85, 0.2, 0.2 },   -- rage
    [2] = { 1.0, 0.5, 0.25 },   -- focus
    [3] = { 1.0, 0.85, 0.2 },   -- energy
}
local DEFAULT = { 0.6, 0.6, 0.6 }

function Power.Build(frame)
    frame.power = CreateFrame("StatusBar", nil, frame)
    frame.powerBg = frame.power:CreateTexture(nil, "BACKGROUND")
    frame.powerBg:SetAllPoints(frame.power)
end

function Power.Style(frame)
    local tex = ns.Media.StatusBar(Config.Get(frame.key, "barTexture"))
    frame.power:SetStatusBarTexture(tex)
    frame.powerBg:SetTexture(tex)
    local bg = Config.Get(frame.key, "backgroundColor")
    frame.powerBg:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
end

function Power.Update(frame)
    local unit = frame.unit
    local powerType = UnitPowerType(unit)
    local c = Power.COLORS[ns.Secrets.Number(powerType) or -1] or DEFAULT
    frame.power:SetStatusBarColor(c[1], c[2], c[3])
    frame.power:SetMinMaxValues(0, UnitPowerMax(unit))
    frame.power:SetValue(UnitPower(unit))
end

ns.RegisterElement(Power)
```

- [ ] **Step 4: Write `Elements/Texts.lua`**

```lua
local _, ns = ...

local Texts = {
    name = "Texts",
    unitEvents = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL" },
}
ns.Texts = Texts

local Config, Secrets = ns.Config, ns.Secrets

local SLOTS = {
    { field = "healthLeft", setting = "textHealthLeft", bar = "health", point = "LEFT", x = 4 },
    { field = "healthRight", setting = "textHealthRight", bar = "health", point = "RIGHT", x = -4 },
    { field = "powerLeft", setting = "textPowerLeft", bar = "power", point = "LEFT", x = 4 },
    { field = "powerRight", setting = "textPowerRight", bar = "power", point = "RIGHT", x = -4 },
}

local function levelText(unit)
    local level = Secrets.Number(UnitLevel(unit))
    if not level then return "" end
    if level <= 0 then return "??" end
    return tostring(level)
end

-- Values: health or power, depending on the bar the slot sits on.
local function current(unit, kind)
    if kind == "health" then return UnitHealth(unit) end
    return UnitPower(unit)
end
local function maximum(unit, kind)
    if kind == "health" then return UnitHealthMax(unit) end
    return UnitPowerMax(unit)
end

function Texts.Apply(fs, tag, unit, kind)
    if tag == "NONE" then
        fs:SetText("")
    elseif tag == "NAME" then
        fs:SetText(UnitName(unit))
    elseif tag == "NAME_LEVEL" then
        fs:SetFormattedText("%s %s", levelText(unit), UnitName(unit))
    elseif tag == "LEVEL" then
        fs:SetText(levelText(unit))
    elseif tag == "CURRENT" then
        fs:SetText(Secrets.Abbreviate(current(unit, kind)))
    elseif tag == "CURRENT_MAX" then
        fs:SetFormattedText("%s / %s", Secrets.Abbreviate(current(unit, kind)), Secrets.Abbreviate(maximum(unit, kind)))
    elseif tag == "PERCENT" then
        local pct
        if kind == "health" then
            pct = UnitHealthPercent(unit, true, Secrets.PercentCurve())
        else
            pct = UnitPowerPercent(unit, nil, false, Secrets.PercentCurve())
        end
        fs:SetFormattedText("%.0f%%", pct)
    elseif tag == "DEFICIT" then
        if kind == "health" then
            fs:SetText(C_StringUtil.TruncateWhenZero(UnitHealthMissing(unit)))
        else
            fs:SetText("")
        end
    end
end

function Texts.Build(frame)
    frame.texts = {}
    for _, slot in ipairs(SLOTS) do
        -- Parent to the bar so the text sits above it.
        frame.texts[slot.field] = frame[slot.bar]:CreateFontString(nil, "OVERLAY")
    end
end

function Texts.Style(frame)
    local scope = frame.key
    local font = ns.Media.Font(Config.Get(scope, "fontFace"))
    local size = Config.Get(scope, "fontSize")
    local outline = Config.Get(scope, "fontOutline")
    local flags = (outline == "NONE") and "" or outline
    local shadow = Config.Get(scope, "fontShadow")
    for _, slot in ipairs(SLOTS) do
        local fs = frame.texts[slot.field]
        fs:SetFont(font, size, flags)
        fs:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
        fs:ClearAllPoints()
        fs:SetPoint(slot.point, frame[slot.bar], slot.point, slot.x, 0)
        fs:SetJustifyH(slot.point)
    end
end

function Texts.Update(frame)
    for _, slot in ipairs(SLOTS) do
        Texts.Apply(frame.texts[slot.field], Config.Get(frame.key, slot.setting), frame.unit, slot.bar)
    end
end

ns.RegisterElement(Texts)
```

Mock additions (in `M.Reset()`): none needed — `SetFont`, `SetShadowOffset`, `SetJustifyH`, `SetFormattedText` already exist.

Note for `levelText`: `tostring(level)` is safe here because `Secrets.Number` has already proven `level` is a plain number.

- [ ] **Step 5: Update TOC order and run tests**

TOC order for this block: `Units\Units.lua`, `Elements\Health.lua`, `Elements\Power.lua`, `Elements\Texts.lua`, `Units\Single.lua`.
Run: `tests/run` → Expected: `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Add power bar and four configurable text slots

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Hide Blizzard frames

**Files:**
- Create: `Core/Blizzard.lua`
- Modify: `ForeverUnitFrames.toc` (append after `Units\Single.lua`)
- Test: `tests/test_blizzard.lua`

**Interfaces:**
- Produces: `ns.Blizzard.Conceal(frame)`; `ns.Blizzard.HideDefaults()` — conceals `PlayerFrame` when the player frame is enabled and `TargetFrame` (+ `ComboFrame` if present) when the target frame is enabled; runs via `ns.AfterCombat("hideBlizzard", …)`.

- [ ] **Step 1: Write the failing test `tests/test_blizzard.lua`**

```lua
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})

_G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
_G.PlayerFrame._protected = true
_G.PlayerFrame:RegisterEvent("UNIT_HEALTH")
_G.TargetFrame = M.newWidget("Frame", "TargetFrame")
local reparented
_G.TargetFrame.SetParent = function(self, p) reparented = p end

ns.Blizzard.HideDefaults()
H.check("protected: alpha 0", PlayerFrame:GetAlpha(), 0)
H.check("protected: mouse off", PlayerFrame._mouse, false)
H.check("protected: events off", next(PlayerFrame._events), nil)
H.check("protected: hidden out of combat", PlayerFrame:IsShown(), false)
H.checkTrue("unprotected: reparented", reparented ~= nil and reparented ~= UIParent)

-- A disabled frame keeps Blizzard's.
ns = H.LoadAddon()
ns.Config.Use({ player = { enabled = false } })
_G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
ns.Blizzard.HideDefaults()
H.check("kept when ours is disabled", PlayerFrame:GetAlpha(), 1)

-- Missing Blizzard frames are ignored.
ns = H.LoadAddon()
ns.Config.Use({})
_G.PlayerFrame, _G.TargetFrame = nil, nil
H.checkTrue("no error without frames", pcall(ns.Blizzard.HideDefaults))
```

- [ ] **Step 2: Run to see it fail**

Run: `tests/run` → Expected: ERROR `attempt to index field 'Blizzard' (a nil value)`.

- [ ] **Step 3: Write `Core/Blizzard.lua`**

```lua
local _, ns = ...

-- Hides Blizzard's own unit frames without hooking any of their methods
-- (hooking mixin methods breaks Blizzard code on this client).
local Blizzard = {}
ns.Blizzard = Blizzard

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

-- Edit Mode frames carry the original C Hide as a plain field "HideBase";
-- calling their overridden Hide would write into the Edit Mode manager.
local function hide(frame)
    local hideBase = rawget(frame, "HideBase")
    if hideBase then hideBase(frame) else frame:Hide() end
end

function Blizzard.Conceal(frame)
    if not frame then return end
    frame:UnregisterAllEvents()
    if frame:IsProtected() then
        -- Protected frames may not be reparented; make them invisible and
        -- inert instead.
        frame:SetAlpha(0)
        frame:EnableMouse(false)
        hide(frame)
    else
        hide(frame)
        frame:SetParent(hiddenParent)
    end
end

function Blizzard.HideDefaults()
    ns.AfterCombat("hideBlizzard", function()
        if ns.Config.Get("player", "enabled") then Blizzard.Conceal(_G.PlayerFrame) end
        if ns.Config.Get("target", "enabled") then
            Blizzard.Conceal(_G.TargetFrame)
            Blizzard.Conceal(_G.ComboFrame)
        end
    end)
end
```

Note: re-enabling a frame after its Blizzard counterpart was hidden needs `/reload`; the options window (plan 4) says so next to the Enabled checkbox.

- [ ] **Step 4: Append TOC line `Core\Blizzard.lua`, run tests**

Run: `tests/run` → Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Hide Blizzard player and target frames without hooks

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: Movers and `/fuf` commands

**Files:**
- Create: `Core/Movers.lua`, `Core/Commands.lua`
- Modify: `ForeverUnitFrames.toc` (append both), `Locales/enUS.lua`
- Test: `tests/test_movers_commands.lua`

**Interfaces:**
- Consumes: `ns.Frames`, `ns.Config`, `ns.Storage.Source`, `ns.AfterCombat`.
- Produces:
  - `ns.Movers.Attach(frame)` — creates `frame.mover` (plain Frame, same size, positioned from config x/y), re-anchors the unit frame to it.
  - `ns.Movers.Unlock() -> bool` (false in combat, prints `L.LOCKED_IN_COMBAT`), `ns.Movers.Lock()`, `ns.Movers.IsUnlocked()`.
  - `ns.Movers.Snap(v) -> int` (rounds to multiples of 8).
  - `ns.Movers.OnDragStop(mover)` — reads the mover centre relative to `UIParent` centre, snaps, `Config.Set(key, "x"/"y")`.
  - `/fuf` → prints help; `/fuf unlock|lock|status|reset <frame>|reset all|set <scope> <key> <value>`.

- [ ] **Step 1: Write the failing test `tests/test_movers_commands.lua`**

```lua
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
for _, f in pairs(ns.Frames) do ns.Movers.Attach(f) end

local f = ns.Frames.player
H.checkTrue("mover exists", f.mover)
local p, rel = f:GetPoint(1)
H.check("frame anchored to mover", rel, f.mover)

H.check("snap 13 -> 16", ns.Movers.Snap(13), 16)
H.check("snap -13 -> -16", ns.Movers.Snap(-13), -16)
H.check("snap 3 -> 0", ns.Movers.Snap(3), 0)

H.checkTrue("unlock", ns.Movers.Unlock())
H.checkTrue("mover shown", f.mover:IsShown())
-- Drag: mover centre moved to (960 + 101, 540 - 50) on a 1920x1080 UIParent.
f.mover._cx, f.mover._cy = 1061, 490
UIParent._cx, UIParent._cy = 960, 540
ns.Movers.OnDragStop(f.mover)
H.check("x saved snapped", ns.Config.Get("player", "x"), 104)
H.check("y saved snapped", ns.Config.Get("player", "y"), -48)
ns.Movers.Lock()
H.check("mover hidden after lock", f.mover:IsShown(), false)

M.combat = true
H.check("no unlock in combat", ns.Movers.Unlock(), false)
M.combat = false

-- Commands
local run = SlashCmdList.FOREVERUNITFRAMES
H.checkTrue("slash registered", run and SLASH_FOREVERUNITFRAMES1 == "/fuf")
run("set player width 300")
H.check("set via command", ns.Config.Get("player", "width"), 300)
run("set player width banana")
H.checkTrue("bad value reported", M.chat[#M.chat]:find("Invalid"))
run("reset player")
H.check("reset via command", ns.Config.Get("player", "width"), 220)
run("status")
H.checkTrue("status mentions storage", table.concat(M.chat, "\n"):find("Settings loaded from"))
```

- [ ] **Step 2: Run to see it fail**

Run: `tests/run` → Expected: ERROR `attempt to index field 'Movers' (a nil value)`.

- [ ] **Step 3: Add strings to `Locales/enUS.lua`** (append)

```lua
L.LOCKED_IN_COMBAT = "Frames cannot be moved in combat."
L.UNLOCKED = "Frames unlocked. Drag them, then type /fuf lock."
L.LOCKED = "Frames locked."
L.HELP = "Commands: /fuf unlock, /fuf lock, /fuf status, /fuf reset <frame|all>, /fuf set <scope> <setting> <value>"
L.INVALID_VALUE = "Invalid setting or value."
L.RESET_DONE = "Settings reset."
L.STATUS_SOURCE = "Settings loaded from: %s"
L.STATUS_BUILD = "Client %s (build %s), interface %d"
L.STATUS_PROJECT = "Project ID %d"
L.FRAME_player = "Player"
L.FRAME_target = "Target"
```

- [ ] **Step 4: Write `Core/Movers.lua`**

```lua
local _, ns = ...

-- Drag handles. Secure frames are anchored to their mover and never moved
-- themselves; moving happens only out of combat.
local Movers = {}
ns.Movers = Movers

local GRID = 8
local unlocked = false
local L = ns.L

function Movers.Snap(v)
    local sign = v < 0 and -1 or 1
    return sign * math.floor(math.abs(v) / GRID + 0.5) * GRID
end

local function position(frame)
    local mover = frame.mover
    mover:SetSize(frame:GetWidth(), frame:GetHeight())
    mover:ClearAllPoints()
    mover:SetPoint("CENTER", UIParent, "CENTER", ns.Config.Get(frame.key, "x"), ns.Config.Get(frame.key, "y"))
end

function Movers.OnDragStop(mover)
    mover:StopMovingOrSizing()
    local mx, my = mover:GetCenter()
    local ux, uy = UIParent:GetCenter()
    ns.Config.Set(mover.frameKey, "x", Movers.Snap(mx - ux))
    ns.Config.Set(mover.frameKey, "y", Movers.Snap(my - uy))
end

function Movers.Attach(frame)
    if frame.mover then return end
    local mover = CreateFrame("Frame", nil, UIParent)
    mover.frameKey = frame.key
    mover:SetMovable(true)
    mover:SetClampedToScreen(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mover:SetScript("OnDragStop", Movers.OnDragStop)
    mover.overlay = mover:CreateTexture(nil, "OVERLAY")
    mover.overlay:SetAllPoints(mover)
    mover.overlay:SetColorTexture(0.3, 0.76, 0.97, 0.35)
    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetFont(ns.Media.Font("Friz Quadrata"), 11, "OUTLINE")
    mover.label:SetPoint("CENTER", mover, "CENTER", 0, 0)
    mover.label:SetText(L["FRAME_" .. frame.key])
    frame.mover = mover
    position(frame)
    mover:EnableMouse(false)
    mover:Hide()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", mover, "CENTER", 0, 0)
end

function Movers.IsUnlocked() return unlocked end

function Movers.Unlock()
    if InCombatLockdown() then
        ns.Print(L.LOCKED_IN_COMBAT)
        return false
    end
    unlocked = true
    for _, frame in pairs(ns.Frames) do
        frame.mover:EnableMouse(true)
        frame.mover:Show()
    end
    ns.Print(L.UNLOCKED)
    return true
end

function Movers.Lock()
    unlocked = false
    for _, frame in pairs(ns.Frames) do
        frame.mover:EnableMouse(false)
        frame.mover:Hide()
    end
    ns.Print(L.LOCKED)
end

-- Keep movers in step with size/position changes.
ns.Listen("CONFIG_CHANGED", function()
    ns.AfterCombat("movers", function()
        for _, frame in pairs(ns.Frames) do
            if frame.mover then position(frame) end
        end
    end)
end)
```

Because `Single.place` anchors to `frame.mover` when it exists, restyles keep the frame on its mover.

Listener order matters: `Single`'s restyle listener (Task 8) runs before this one because `Units\Single.lua` loads first; the mover then takes the new size. Both run out of combat.

- [ ] **Step 5: Write `Core/Commands.lua`**

```lua
local _, ns = ...

local L = ns.L

local function parseValue(def, raw)
    if not def or not raw then return nil end
    if def.type == "int" then return tonumber(raw) end
    if def.type == "bool" then
        if raw == "on" or raw == "true" or raw == "1" then return true end
        if raw == "off" or raw == "false" or raw == "0" then return false end
        return nil
    end
    if def.type == "enum" then return raw:upper() end
    if def.type == "media" then return raw end
    return nil   -- colors are set in the options window
end

local function status()
    local version, build, _, interface = GetBuildInfo()
    ns.Print(L.STATUS_BUILD:format(version, build, interface))
    ns.Print(L.STATUS_PROJECT:format(WOW_PROJECT_ID or 0))
    ns.Print(L.STATUS_SOURCE:format(ns.Storage.Source()))
end

SLASH_FOREVERUNITFRAMES1 = "/fuf"
SlashCmdList.FOREVERUNITFRAMES = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "unlock" then
        ns.Movers.Unlock()
    elseif cmd == "lock" then
        ns.Movers.Lock()
    elseif cmd == "status" then
        status()
    elseif cmd == "reset" then
        if rest == "all" then
            ns.Config.ResetAll()
        elseif ns.Config.Profile()[rest] then
            ns.Config.ResetScope(rest)
        else
            ns.Print(L.INVALID_VALUE)
            return
        end
        ns.Storage.Save()
        ns.Print(L.RESET_DONE)
    elseif cmd == "set" then
        local scope, key, raw = rest:match("^(%S+)%s+(%S+)%s+(.+)$")
        local def = key and ns.Settings.Get(key)
        local value = parseValue(def, raw)
        if value == nil or not ns.Config.Set(scope, key, value) then
            ns.Print(L.INVALID_VALUE)
        else
            ns.Storage.Save()
        end
    else
        ns.Print(L.HELP)
    end
end
```

- [ ] **Step 6: Append TOC lines `Core\Movers.lua`, `Core\Commands.lua`; run tests**

Run: `tests/run` → Expected: `0 failed`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Add drag movers and /fuf commands

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: Boot wiring, full-load test, in-game check

**Files:**
- Create: `Core/Boot.lua`, `tests/test_boot.lua`
- Modify: `ForeverUnitFrames.toc` (final order below)

**Interfaces:**
- Consumes: everything above.
- Produces: on `ADDON_LOADED` for this addon → `Storage.Load(ForeverUnitFramesDB)`, `Config.Use`, `Storage.Attach(ForeverUnitFramesDB)`; on `PLAYER_LOGIN` → `Single.CreateAll`, `Movers.Attach` for each frame, `Blizzard.HideDefaults`; every `CONFIG_CHANGED` → `Storage.Save()`.

Final TOC file list:
```
Locales\enUS.lua
Core\Init.lua
Core\Secrets.lua
Core\Settings.lua
Core\Config.lua
Core\Codec.lua
Core\MacroBackup.lua
Core\Storage.lua
Core\Media.lua
Core\Layout.lua
Units\Units.lua
Elements\Health.lua
Elements\Power.lua
Elements\Texts.lua
Units\Single.lua
Core\Blizzard.lua
Core\Movers.lua
Core\Commands.lua
Core\Boot.lua
```

- [ ] **Step 1: Write the failing test `tests/test_boot.lua`**

```lua
local M = H.M
local ns = H.LoadAddon()
_G.PlayerFrame = M.newWidget("Frame", "PlayerFrame")
_G.ForeverUnitFramesDB = nil

M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
H.check("defaults without data", ns.Storage.Source(), "defaults")
M.FireEvent("PLAYER_LOGIN")
H.checkTrue("player frame built", ns.Frames.player)
H.checkTrue("mover attached", ns.Frames.player.mover)
H.check("blizzard hidden", PlayerFrame:IsShown(), false)

-- A change is saved everywhere.
ns.Config.Set("player", "width", 290)
H.check("SV table created", ForeverUnitFramesDB.profile.player.width, 290)
H.check("macro backup written", ns.MacroBackup.Read(), "1;pW290")

-- Next session: SV missing (beta bug), macro backup restores the setting.
local macros = M.macros
ns = H.LoadAddon()
M.macros = macros
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
H.check("restored from macro", ns.Storage.Source(), "macro backup")
H.check("width restored", ns.Config.Get("player", "width"), 290)

-- Other addons' ADDON_LOADED is ignored.
ns = H.LoadAddon()
M.FireEvent("ADDON_LOADED", "SomethingElse")
H.check("not initialised by others", ns.Config.Profile(), nil)
```

- [ ] **Step 2: Run to see it fail**

Run: `tests/run` → Expected: FAIL `defaults without data` (Source still default but Frames nil) / ERROR on `ns.Frames.player`.

- [ ] **Step 3: Write `Core/Boot.lua`**

```lua
local ADDON, ns = ...

-- Startup order: settings first (ADDON_LOADED), frames once the player
-- exists (PLAYER_LOGIN). Every settings change is persisted.

ns.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON or ns.booted then return end
    ns.booted = true
    ForeverUnitFramesDB = ForeverUnitFramesDB or {}
    local profile = ns.Storage.Load(ForeverUnitFramesDB)
    ns.Config.Use(profile)
    ns.Storage.Attach(ForeverUnitFramesDB)
end)

ns.On("PLAYER_LOGIN", function()
    ns.Single.CreateAll()
    ns.AfterCombat("attachMovers", function()
        for _, frame in pairs(ns.Frames) do ns.Movers.Attach(frame) end
    end)
    ns.Blizzard.HideDefaults()
end)

ns.Listen("CONFIG_CHANGED", function()
    ns.Storage.Save()
end)
```

Careful: `ForeverUnitFramesDB = ForeverUnitFramesDB or {}` creates an empty table when SV did not load; `Storage.Load` treats a table without `profile` as "no SV data" and moves on to providers/macro — as tested.

- [ ] **Step 4: Set the final TOC order, run tests**

Run: `tests/run` → Expected: `0 failed`.

- [ ] **Step 5: Syntax check every shipped file with the client's Lua version**

Run: `for f in $(grep -v '^#' ForeverUnitFrames.toc | grep -v '^$' | tr '\\' '/'); do luac5.1 -p "$f" || echo "FAIL $f"; done`
Expected: no output.

- [ ] **Step 6: Commit and push**

```bash
git add -A
git commit -m "Wire startup: load settings, build frames, persist changes

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
git push
```
The pre-push hook scans for private data; a refusal means a file contains something that must not be public — fix it, amend, push again.

- [ ] **Step 7: In-game check (with the user)**

Install into the beta client's AddOns folder with `./install "<AddOns folder>"`, start the game, and verify:

1. No Lua errors on login (`/console scriptErrors 1` beforehand).
2. Player frame visible, Blizzard player frame gone; target a mob → target frame appears, Blizzard target frame gone; clear target → frame disappears.
3. Left click on our target frame targets, right click opens the unit menu.
4. Take damage in combat: health bar and texts update, no errors (secret path).
5. `/fuf set player width 300` → frame widens; `/fuf unlock`, drag, `/fuf lock` → position kept.
6. `/fuf status` → build, interface 16001, project ID 1, settings source.
7. `/reload` → settings come back; `/fuf status` shows the source (SavedVariables or macro backup). Open the macro window: character macros `FUF Save 1` exist.
8. Enter combat and type `/fuf unlock` → refused with message.

Record findings (what worked, any error text with line numbers read against the `forever` branch) for the project notes.
