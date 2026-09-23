# Forever Unit Frames — Plan 2: Options window and test mode

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A polished, movable options window (`/fuf`) that exposes every existing setting through sliders with edit boxes, checkboxes, dropdowns and colour swatches, plus Unlock, Test mode, Copy from, Reset and profile export/import.

**Architecture:** A declarative schema (`Options/Schema.lua`) lists pages → tabs → sections → setting keys. The window (`Options/Window.lua`) renders a page by turning each key into a widget (`Options/Widgets.lua`) bound to `Config.Get/Set` for the selected scope. Widgets never know about settings; the window never hard-codes settings. Test mode (`Options/TestMode.lua`) shows every frame with the player's data. Saves are debounced so dragging a slider does not rewrite macros on every tick.

**Tech Stack:** Lua 5.1, WoW: Forever API (Interface 16001, build 1.60.1.69977), offline tests with `lua5.1` + `tests/mock.lua`.

Plan order (revised by the user on 2026-09-23): 1 Foundation (done) → **2 Options window (this plan)** → 3 remaining frames + castbar → 4 auras → 5 release. Every later plan adds its settings to the schema; the window picks them up without changes.

## Global Constraints

- Everything in English: UI strings, file names, identifiers, comments. All user-facing strings through `ns.L`.
- Target client: WoW: Forever, `## Interface: 16001`. API facts only from the `forever` branch of the UI source (build 69977).
- Never do arithmetic, comparisons, concatenation or `tostring` on values that may be secret. The options window only handles settings values (plain), never unit values.
- Never `hooksecurefunc` a frame's Lua mixin method. `HookScript` and hooks on plain tables are allowed.
- No secure snippets. The options window and its widgets are plain (non-secure) frames.
- Secure unit frames are only changed out of combat (existing `ns.AfterCombat` paths). While in combat the window is locked (controls disabled, notice shown).
- Every position is settable as numeric X / Y in addition to dragging (spec §7).
- Every numeric control is a slider with an edit box for exact values (spec §7).
- The window is movable, clamped to screen, remembers its position, closes with ESC, and must never be forced on top of the frame being edited (it is draggable anywhere).
- Setting short codes are permanent; this plan adds no new codes except where a task says so.
- Public repository: no local paths, host names, character names or anything about the author's machine in files or commit messages.
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01GdoRAmGdKzhaexe9N6CBKp`

## Visual style (applies to every widget)

Flat and dark, matching the frames:

| Token | Value |
|---|---|
| Window background | `0.07, 0.07, 0.08, 0.96` |
| Panel / nav background | `0.10, 0.10, 0.12, 1` |
| Row hover | `1, 1, 1, 0.04` |
| Border | `0, 0, 0, 1`, 1 px |
| Accent | `0.31, 0.76, 0.97` (same blue as the chat prefix) |
| Text | `0.90, 0.90, 0.90` |
| Muted text (inherited, hints) | `0.55, 0.55, 0.58` |
| Control background | `0.16, 0.16, 0.19, 1` |
| Font | `ns.Media.Font("Friz Quadrata")`, 12 px labels, 14 px headers, 16 px title |
| Texture for all fills | `Interface\Buttons\WHITE8X8` |

Window 780 × 560. Title bar 32 px. Navigation column 160 px. Tab row 30 px. Footer 40 px. Content rows 30 px high: label at x = 16, control at x = 240, control width 260, row right edge reserved for the "inherited / reset" marker (width 80).

## File structure after this plan

```
Options/Style.lua        colours, fonts, flat texture helpers (Style.Fill, Style.Border, Style.Text)
Options/Widgets.lua      Header, Slider(+EditBox), Checkbox, Dropdown, Color, Button, TextArea
Options/Schema.lua       pages / tabs / sections / keys; enum labels via ns.L
Options/Window.lua       window shell, navigation, tabs, page rendering, footer, combat lock, highlight
Options/TestMode.lua     test mode on/off
Core/Config.lua          + ClearOverride, CopyScope, Import
Core/Storage.lua         + RequestSave (debounced)
Core/Boot.lua            CONFIG_CHANGED -> RequestSave
Core/Commands.lua        /fuf (no args) opens the window; /fuf help prints help
Elements/Texts.lua       else-branch for unknown tags; power DEFICIT via UnitPowerMissing
Core/Movers.lua          Lock saves the position of a mover that is being dragged
Locales/enUS.lua         all new strings
tests/test_*.lua         one test file per task
```

TOC order (append after `Core\Commands.lua`, before `Core\Boot.lua`):
```
Options\Style.lua
Options\Widgets.lua
Options\Schema.lua
Options\TestMode.lua
Options\Window.lua
```

---

### Task 1: Config helpers, debounced saving, small fixes from plan 1

**Files:**
- Modify: `Core/Config.lua`, `Core/Storage.lua`, `Core/Boot.lua`, `Elements/Texts.lua`, `Core/Movers.lua`, `tests/mock.lua`
- Test: `tests/test_config_extras.lua`

**Interfaces:**
- Produces:
  - `ns.Config.ClearOverride(scope, key)` — removes `profile[scope][key]`, fires `CONFIG_CHANGED(scope, key)`.
  - `ns.Config.CopyScope(from, to)` — copies every override of `from` that applies to `to` (`Settings.AppliesTo`) into `to`, replacing `to`'s overrides; fires `CONFIG_CHANGED(to, nil)`. Position keys `x` and `y` are **not** copied (copying a frame's look must not stack two frames on the same spot).
  - `ns.Config.Import(profile)` — replaces every scope's overrides with the given (already decoded and sanitised) profile; fires `CONFIG_CHANGED(nil, nil)`.
  - `ns.Storage.RequestSave()` — coalesces saves: schedules one `Storage.Save()` 0.5 s later via `C_Timer.After`; further requests inside that window do nothing.
  - Boot's `CONFIG_CHANGED` listener calls `ns.Storage.RequestSave()` instead of `Save()`.
  - `ns.Storage.Flush()` — runs a pending save immediately (used on `PLAYER_LOGOUT`); Boot registers `ns.On("PLAYER_LOGOUT", ns.Storage.Flush)`.
  - Mock: `_G.C_Timer = { After = function(sec, fn) table.insert(M.timers, { sec = sec, fn = fn }) end }`, `M.timers = {}` in `M.Reset()`, and `M.RunTimers()` which runs and clears all queued timers.

- [ ] **Step 1: Write the failing test `tests/test_config_extras.lua`**

```lua
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
local C = ns.Config

-- ClearOverride
C.Set("target", "fontSize", 9)
H.checkTrue("override set", C.IsOverridden("target", "fontSize"))
C.ClearOverride("target", "fontSize")
H.check("override cleared", C.IsOverridden("target", "fontSize"), false)
H.check("falls back to general", C.Get("target", "fontSize"), 12)

-- CopyScope copies look, not position
C.Set("player", "width", 333); C.Set("player", "x", -500); C.Set("player", "fontSize", 15)
C.Set("target", "height", 60)
C.CopyScope("player", "target")
H.check("width copied", C.Get("target", "width"), 333)
H.check("font copied", C.Get("target", "fontSize"), 15)
H.check("x not copied", C.Get("target", "x"), 300)
H.check("target's own override replaced", C.Get("target", "height"), 46)

-- Import replaces everything
C.Import({ general = { fontSize = 10 }, player = {}, target = { width = 111 } })
H.check("import general", C.Get("player", "fontSize"), 10)
H.check("import target", C.Get("target", "width"), 111)
H.check("import cleared player width", C.Get("player", "width"), 220)

-- Debounced save
ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
local writes = 0
local realWrite = ns.MacroBackup.Write
ns.MacroBackup.Write = function(s) writes = writes + 1; return realWrite(s) end
for w = 230, 240 do ns.Config.Set("player", "width", w) end
H.check("nothing saved before the timer", writes, 0)
M.RunTimers()
H.check("one save after the timer", writes, 1)
H.check("last value saved", ns.MacroBackup.Read(), "1;pW240")
ns.Config.Set("player", "width", 250)
M.FireEvent("PLAYER_LOGOUT")
H.check("flush on logout", ns.MacroBackup.Read(), "1;pW250")

-- Texts: unknown tag clears, power deficit uses UnitPowerMissing
ns = H.LoadAddon()
ns.Config.Use({})
M.units.player = { name = "T", level = 60, health = 1, healthMax = 1, power = 30, powerMax = 100, powerMissing = 70 }
ns.Single.CreateAll()
local fs = ns.Frames.player.texts.powerLeft
fs:SetText("stale")
ns.Texts.Apply(fs, "SOMETHING_NEW", "player", "power")
H.check("unknown tag clears", fs._text, "")
ns.Texts.Apply(fs, "DEFICIT", "player", "power")
H.check("power deficit", fs._text, 70)
```

Mock additions for this test: `_G.UnitPowerMissing = function(unit) local d = M.units[unit]; return d and d.powerMissing or 0 end` in `M.Reset()`; `C_StringUtil.TruncateWhenZero` already passes values through.

- [ ] **Step 2: Run to see it fail** — `tests/run` → ERROR `attempt to call field 'ClearOverride' (a nil value)`.

- [ ] **Step 3: Add to `Core/Config.lua`** (after `Config.ResetAll`)

```lua
function Config.ClearOverride(scope, key)
    if not profile[scope] then return end
    profile[scope][key] = nil
    ns.Fire("CONFIG_CHANGED", scope, key)
end

-- Positions stay put: copying a frame's look must not stack two frames.
local NOT_COPIED = { x = true, y = true }

function Config.CopyScope(from, to)
    if not profile[from] or not profile[to] or from == to then return end
    local copy = {}
    for key, value in pairs(profile[from]) do
        local def = Settings.Get(key)
        if def and not NOT_COPIED[key] and Settings.AppliesTo(def, to) then
            copy[key] = type(value) == "table" and { value[1], value[2], value[3], value[4] } or value
        end
    end
    for key in pairs(NOT_COPIED) do copy[key] = profile[to][key] end
    profile[to] = copy
    ns.Fire("CONFIG_CHANGED", to, nil)
end

function Config.Import(p)
    for _, scope in ipairs(Settings.SCOPES) do
        profile[scope] = type(p[scope]) == "table" and p[scope] or {}
    end
    ns.Fire("CONFIG_CHANGED", nil, nil)
end
```

- [ ] **Step 4: Add to `Core/Storage.lua`** (after `Storage.Save`)

```lua
-- Sliders fire many changes per second; one save per half second is plenty.
local saveQueued = false

function Storage.RequestSave()
    if saveQueued then return end
    saveQueued = true
    C_Timer.After(0.5, function()
        saveQueued = false
        Storage.Save()
    end)
end

function Storage.Flush()
    Storage.Save()
end
```

`Flush` may run while a timer is still queued; the queued `Save` then finds an unchanged string and does nothing (Save already dedupes).

- [ ] **Step 5: `Core/Boot.lua`** — replace the `CONFIG_CHANGED` listener body with `ns.Storage.RequestSave()` and add `ns.On("PLAYER_LOGOUT", function() ns.Storage.Flush() end)`.

- [ ] **Step 6: `Elements/Texts.lua`** — in `Texts.Apply`: the `DEFICIT` branch for power becomes `fs:SetText(C_StringUtil.TruncateWhenZero(UnitPowerMissing(unit)))`; add a final `else fs:SetText("")` branch.

- [ ] **Step 7: `Core/Movers.lua`** — in `OnDragStart` set `self.dragging = true`; in `OnDragStop` clear it. In `Lock()`, for a mover with `dragging == true`, call `Movers.OnDragStop(mover)` (which stops moving and saves x/y) instead of only `StopMovingOrSizing()`. Add to the test file:

```lua
ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
for _, f in pairs(ns.Frames) do ns.Movers.Attach(f) end
ns.Movers.Unlock()
local mv = ns.Frames.player.mover
mv:GetScript("OnDragStart")(mv)
mv._cx, mv._cy = 960 + 64, 540 - 32
UIParent._cx, UIParent._cy = 960, 540
ns.Movers.Lock()
H.check("lock during drag saves x", ns.Config.Get("player", "x"), 64)
H.check("lock during drag saves y", ns.Config.Get("player", "y"), -32)
```

- [ ] **Step 8: Update existing tests that relied on immediate saving** — `tests/test_boot.lua` and `tests/test_storage.lua` assertions that read the macro/SV right after `Config.Set` must call `M.RunTimers()` first. Do not weaken any assertion otherwise.

- [ ] **Step 9: Run** `tests/run` → `0 failed`; `luac5.1 -p` on changed files.

- [ ] **Step 10: Commit** — "Add config copy/import helpers, debounce saving, small fixes"

---

### Task 2: Schema

**Files:**
- Create: `Options/Schema.lua`
- Modify: `ForeverUnitFrames.toc`, `Locales/enUS.lua`
- Test: `tests/test_schema.lua`

**Interfaces:**
- Produces:
  - `ns.Schema.GENERAL` — ordered tabs for the General page:
    `{ { id = "appearance", sections = { { id = "font", keys = {...} }, ... } }, { id = "colors", ... }, { id = "profile", custom = "profile" } }`
  - `ns.Schema.FRAME` — ordered tabs for every frame page (`layout`, `bars`, `text`).
  - `ns.Schema.Tabs(scope) -> tabs` — `GENERAL` for `"general"`, `FRAME` otherwise; tabs whose sections contain no key applicable to the scope are omitted (so later plans can add tabs that only some frames have).
  - `ns.Schema.EnumText(def, value) -> string` — `ns.L["ENUM_" .. def.key .. "_" .. value]`, falling back to `ns.L["ENUM_" .. value]`.
  - Labels: tab `L["TAB_" .. id]`, section `L["SECTION_" .. id]`, setting `L["SETTING_" .. key]`, optional hint `L["HINT_" .. key]` (shown muted under/after the label when present).

Exact schema:

```lua
Schema.GENERAL = {
    { id = "appearance", sections = {
        { id = "font", keys = { "fontFace", "fontSize", "fontOutline", "fontShadow" } },
        { id = "bars", keys = { "barTexture", "backgroundColor" } },
        { id = "border", keys = { "borderSize", "borderColor" } },
    } },
    { id = "colors", sections = {
        { id = "health", keys = { "healthColorMode", "healthColor" } },
    } },
    { id = "profile", custom = "profile" },
}

Schema.FRAME = {
    { id = "layout", sections = {
        { id = "frame", keys = { "enabled" } },
        { id = "size", keys = { "width", "height" } },
        { id = "barHeights", keys = { "healthPercent", "powerPercent", "powerEnabled" } },
        { id = "position", keys = { "x", "y" } },
    } },
    { id = "bars", sections = {
        { id = "health", keys = { "healthColorMode", "healthColor" } },
        { id = "textures", keys = { "barTexture", "backgroundColor" } },
        { id = "border", keys = { "borderSize", "borderColor" } },
    } },
    { id = "text", sections = {
        { id = "healthText", keys = { "textHealthLeft", "textHealthRight" } },
        { id = "powerText", keys = { "textPowerLeft", "textPowerRight" } },
        { id = "font", keys = { "fontFace", "fontSize", "fontOutline", "fontShadow" } },
    } },
}
```

Locale strings to add (exact):

```lua
L.TAB_appearance = "Appearance"; L.TAB_colors = "Colors"; L.TAB_profile = "Profile"
L.TAB_layout = "Layout"; L.TAB_bars = "Bars"; L.TAB_text = "Text"
L.SECTION_font = "Font"; L.SECTION_bars = "Bars"; L.SECTION_border = "Border"
L.SECTION_health = "Health bar"; L.SECTION_frame = "Frame"; L.SECTION_size = "Size"
L.SECTION_barHeights = "Bar heights"; L.SECTION_position = "Position"
L.SECTION_textures = "Textures"; L.SECTION_healthText = "Health bar text"
L.SECTION_powerText = "Power bar text"
L.HINT_healthPercent = "Share of the frame height"
L.HINT_powerPercent = "Share of the frame height; the rest becomes the gap"
L.HINT_x = "Offset from the screen centre"
L.HINT_y = "Offset from the screen centre"
L.HINT_enabled = "Re-enabling a frame needs /reload to hide Blizzard's again"
L.ENUM_NONE = "None"; L.ENUM_OUTLINE = "Outline"; L.ENUM_THICKOUTLINE = "Thick outline"
L.ENUM_MONOCHROME = "Monochrome"
L.ENUM_CLASS = "Class"; L.ENUM_REACTION = "Reaction"; L.ENUM_STATIC = "Static colour"
L.ENUM_GRADIENT = "Gradient by health"
L.ENUM_NAME = "Name"; L.ENUM_NAME_LEVEL = "Level and name"; L.ENUM_LEVEL = "Level"
L.ENUM_CURRENT = "Current"; L.ENUM_CURRENT_MAX = "Current / max"; L.ENUM_PERCENT = "Percent"
L.ENUM_DEFICIT = "Deficit"
L.ENUM_fontOutline_NONE = "None"
L.ENUM_textHealthLeft_NONE = "Empty"
```
(Only the last two show that key-specific labels win; `EnumText` tries the key-specific one first.)

- [ ] **Step 1: Write the failing test `tests/test_schema.lua`**

```lua
local ns = H.LoadAddon()
local S, Settings, L = ns.Schema, ns.Settings, ns.L

local function keysOf(tabs)
    local seen = {}
    for _, tab in ipairs(tabs) do
        for _, sec in ipairs(tab.sections or {}) do
            for _, key in ipairs(sec.keys) do
                H.checkTrue("known key " .. key, Settings.Get(key))
                seen[key] = (seen[key] or 0) + 1
            end
            H.checkTrue("section label " .. sec.id, L["SECTION_" .. sec.id] ~= "SECTION_" .. sec.id)
        end
        H.checkTrue("tab label " .. tab.id, L["TAB_" .. tab.id] ~= "TAB_" .. tab.id)
    end
    return seen
end

local general, frame = keysOf(S.GENERAL), keysOf(S.FRAME)
for _, def in ipairs(Settings.All()) do
    if Settings.AppliesTo(def, "general") then
        H.check("general shows " .. def.key .. " once", general[def.key], 1)
    end
    if Settings.AppliesTo(def, "player") then
        H.check("frame shows " .. def.key .. " once", frame[def.key], 1)
    end
    if def.type == "enum" then
        for _, v in ipairs(def.values) do
            local text = S.EnumText(def, v)
            H.checkTrue("enum label " .. def.key .. "." .. v, not text:match("^ENUM_"))
        end
    end
end

H.check("general has profile tab", S.Tabs("general")[3].id, "profile")
H.check("frame tab count", #S.Tabs("player"), 3)
H.check("key-specific enum text wins", S.EnumText(Settings.Get("textHealthLeft"), "NONE"), "Empty")
```

- [ ] **Step 2: Run to see it fail** — `attempt to index field 'Schema'`.
- [ ] **Step 3: Write `Options/Schema.lua`** with the tables above plus:

```lua
local _, ns = ...
local Schema = {}
ns.Schema = Schema
-- (GENERAL and FRAME tables exactly as above)

local function applicable(tab, scope)
    if tab.custom then return scope == "general" end
    for _, sec in ipairs(tab.sections) do
        for _, key in ipairs(sec.keys) do
            if ns.Settings.AppliesTo(ns.Settings.Get(key), scope) then return true end
        end
    end
    return false
end

function Schema.Tabs(scope)
    local source = scope == "general" and Schema.GENERAL or Schema.FRAME
    local tabs = {}
    for _, tab in ipairs(source) do
        if applicable(tab, scope) then tabs[#tabs + 1] = tab end
    end
    return tabs
end

function Schema.EnumText(def, value)
    local specific = "ENUM_" .. def.key .. "_" .. value
    if ns.L[specific] ~= specific then return ns.L[specific] end
    return ns.L["ENUM_" .. value]
end
```

- [ ] **Step 4:** add locale strings, TOC line `Options\Schema.lua` (placed per the TOC order above; `Options\Style.lua` and `Options\Widgets.lua` come in Task 3, so for now insert `Options\Schema.lua` after `Core\Commands.lua`), run tests, commit "Add options schema".

---

### Task 3: Style and widgets

**Files:**
- Create: `Options/Style.lua`, `Options/Widgets.lua`
- Modify: `ForeverUnitFrames.toc` (insert `Options\Style.lua`, `Options\Widgets.lua` before `Options\Schema.lua`), `tests/mock.lua`
- Test: `tests/test_widgets.lua`

**Interfaces:**
- `ns.Style` — `COLORS` table (keys: `bg`, `panel`, `hover`, `border`, `accent`, `text`, `muted`, `control`), `Fill(frame, colorKey, layer?) -> texture`, `Border(frame)` (1 px black edges, same technique as unit frames), `Text(parent, size, colorKey) -> FontString` using `ns.Media.Font("Friz Quadrata")`.
- `ns.Widgets` — every constructor returns a row frame `row` with `row:Refresh()` (re-reads `get()`) and `row:SetEnabled(bool)`; `opts.label` text left; optional `opts.hint` muted text.
  - `Widgets.Header(parent, text) -> row` (14 px accent text + 1 px accent line under it).
  - `Widgets.Slider(parent, { label, hint, min, max, step, get, set })` — own flat slider (track 4 px, thumb 10×16 accent) plus an edit box (60 px) right of it. Dragging calls `set(value)` with the value rounded to `step` only when the value actually changed. The edit box commits on Enter or focus loss: a number within `[min, max]` → `set`; anything else → revert to `get()` and flash the box border red for 0.6 s. Mouse wheel over the slider steps ±`step`.
  - `Widgets.Checkbox(parent, { label, hint, get, set })` — 16 px flat box, accent check mark texture, label clickable.
  - `Widgets.Dropdown(parent, { label, hint, items = function() return { {value=, text=, font=?}, ... } end, get, set })` — button (width 260) showing the current item's text and a ▾ glyph; click opens a list (strata `FULLSCREEN_DIALOG`, max 12 rows visible, mouse wheel scrolls, current item marked in accent). Items with `font` render in that font (font preview). Selecting calls `set(value)` and closes; clicking the button again, pressing ESC or hiding the window closes the list. Only one list open at a time.
  - `Widgets.Color(parent, { label, hint, get, set })` — 40×16 swatch; click opens `ColorPickerFrame:SetupColorPickerAndShow{ r, g, b, opacity = a, hasOpacity = true, swatchFunc, opacityFunc, cancelFunc }`; swatch/opacity callbacks read `ColorPickerFrame:GetColorRGB()` and `ColorPickerFrame:GetColorAlpha()` and call `set({ r, g, b, a })`; cancel restores the previous value via `set`.
  - `Widgets.Button(parent, { text, width, onClick }) -> button` with `button:SetEnabled(bool)` and hover accent.
  - `Widgets.TextArea(parent, { width, height, readOnly }) -> area` with `area:SetText(s)`, `area:GetText()`, select-all on focus when `readOnly`.
  - Inherit marker: `opts.inherit = { isOverridden = fn() -> bool, clear = fn() }` → when not overridden the label is followed by muted "(inherited)"; when overridden a small "Reset" text button appears at the row's right edge and calls `clear()`.
- Mock additions: widget kinds `Slider`, `EditBox`, `CheckButton`, `Button`, `ScrollFrame` via the existing generic widget; add recorders `SetMinMaxValues/GetMinMaxValues` (already), `SetValueStep`, `SetObeyStepOnDrag`, `SetOrientation`, `SetThumbTexture`, `SetAutoFocus`, `ClearFocus`, `HasFocus`, `SetCursorPosition`, `HighlightText`, `SetMaxLetters`, `SetMultiLine`, `SetEnabled`/`IsEnabled` (`_enabled`), `Enable`/`Disable`, `SetFontObject`, `EnableMouseWheel`, `SetFrameStrata`/`GetFrameStrata` (already), `SetScrollChild`, `SetVerticalScroll`/`GetVerticalScroll`; `_G.ColorPickerFrame` stub with `SetupColorPickerAndShow(self, info)` storing `M.colorPicker = info`, `GetColorRGB` returning `M.pickRGB` components and `GetColorAlpha` returning `M.pickA`. Firing a script in tests: `w:GetScript("OnClick")(w)` etc.

- [ ] **Step 1: Write the failing test `tests/test_widgets.lua`**

```lua
local M = H.M
local ns = H.LoadAddon()
local W = ns.Widgets
local parent = CreateFrame("Frame", nil, UIParent)

-- Slider + edit box
local value = 100
local sl = W.Slider(parent, { label = "Width", min = 40, max = 600, step = 1,
    get = function() return value end, set = function(v) value = v; return true end })
sl:Refresh()
H.check("slider shows value", sl.slider:GetValue(), 100)
H.check("edit box shows value", sl.edit:GetText(), "100")
sl.slider:GetScript("OnValueChanged")(sl.slider, 250.4, true)
H.check("drag sets rounded value", value, 250)
sl.edit:SetText("333")
sl.edit:GetScript("OnEnterPressed")(sl.edit)
H.check("edit box commits", value, 333)
sl.edit:SetText("abc")
sl.edit:GetScript("OnEnterPressed")(sl.edit)
H.check("invalid text keeps value", value, 333)
H.check("invalid text reverts box", sl.edit:GetText(), "333")
sl.edit:SetText("9999")
sl.edit:GetScript("OnEnterPressed")(sl.edit)
H.check("out of range keeps value", value, 333)
sl:SetEnabled(false)
H.check("disabled slider", sl.slider._enabled, false)

-- Checkbox
local on = true
local cb = W.Checkbox(parent, { label = "Enabled", get = function() return on end, set = function(v) on = v; return true end })
cb:Refresh()
cb.box:GetScript("OnClick")(cb.box)
H.check("checkbox toggles", on, false)

-- Dropdown
local pick = "OUTLINE"
local dd = W.Dropdown(parent, { label = "Style",
    items = function() return { { value = "NONE", text = "None" }, { value = "OUTLINE", text = "Outline" } } end,
    get = function() return pick end, set = function(v) pick = v; return true end })
dd:Refresh()
H.check("dropdown shows current text", dd.button.text:GetText(), "Outline")
dd.button:GetScript("OnClick")(dd.button)
H.checkTrue("list opened", dd.list:IsShown())
dd.list.rows[1]:GetScript("OnClick")(dd.list.rows[1])
H.check("dropdown selects", pick, "NONE")
H.check("list closed after select", dd.list:IsShown(), false)

-- Color
local col = { 1, 0, 0, 1 }
local cw = W.Color(parent, { label = "Colour", get = function() return col end, set = function(v) col = v; return true end })
cw:Refresh()
cw.swatch:GetScript("OnClick")(cw.swatch)
H.check("picker opened with r", M.colorPicker.r, 1)
M.pickRGB, M.pickA = { 0, 0.5, 1 }, 0.4
M.colorPicker.swatchFunc()
H.check("picked g", col[2], 0.5)
H.check("picked alpha", col[4], 0.4)
M.colorPicker.cancelFunc()
H.check("cancel restores", col[1], 1)

-- Inherit marker
local over = false
local cleared = false
local inh = W.Slider(parent, { label = "Font size", min = 6, max = 32, step = 1,
    get = function() return 12 end, set = function() return true end,
    inherit = { isOverridden = function() return over end, clear = function() cleared = true end } })
inh:Refresh()
H.checkTrue("inherited marker shown", inh.inherited:IsShown())
H.check("reset hidden", inh.reset:IsShown(), false)
over = true; inh:Refresh()
H.checkTrue("reset shown when overridden", inh.reset:IsShown())
inh.reset:GetScript("OnClick")(inh.reset)
H.checkTrue("reset clears", cleared)
```

- [ ] **Step 2: Run to see it fail.**
- [ ] **Step 3: Implement `Options/Style.lua`.**

```lua
local _, ns = ...
local Style = {}
ns.Style = Style

Style.COLORS = {
    bg = { 0.07, 0.07, 0.08, 0.96 }, panel = { 0.10, 0.10, 0.12, 1 },
    hover = { 1, 1, 1, 0.04 }, border = { 0, 0, 0, 1 },
    accent = { 0.31, 0.76, 0.97, 1 }, text = { 0.90, 0.90, 0.90, 1 },
    muted = { 0.55, 0.55, 0.58, 1 }, control = { 0.16, 0.16, 0.19, 1 },
    error = { 0.90, 0.30, 0.30, 1 },
}
Style.TEXTURE = "Interface\\Buttons\\WHITE8X8"

function Style.Fill(frame, colorKey, layer)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(frame)
    local c = Style.COLORS[colorKey]
    t:SetColorTexture(c[1], c[2], c[3], c[4])
    return t
end

function Style.Border(frame, colorKey)
    local c = Style.COLORS[colorKey or "border"]
    local edges = {}
    for i = 1, 4 do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(c[1], c[2], c[3], c[4])
        edges[i] = t
    end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
    frame.edges = edges
    return edges
end

function Style.SetBorderColor(frame, colorKey)
    local c = Style.COLORS[colorKey]
    for _, t in ipairs(frame.edges or {}) do t:SetColorTexture(c[1], c[2], c[3], c[4]) end
end

function Style.Text(parent, size, colorKey, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(ns.Media.Font("Friz Quadrata"), size, "")
    local c = Style.COLORS[colorKey or "text"]
    fs:SetTextColor(c[1], c[2], c[3], c[4])
    fs:SetShadowOffset(1, -1)
    return fs
end
```

- [ ] **Step 4: Implement `Options/Widgets.lua`.** Row layout constants: `ROW_H = 30`, `LABEL_X = 16`, `CONTROL_X = 240`, `CONTROL_W = 260`. Shared row builder:

```lua
local _, ns = ...
local Widgets = {}
ns.Widgets = Widgets
local Style, L = ns.Style, ns.L

Widgets.ROW_H, Widgets.CONTROL_X, Widgets.CONTROL_W = 30, 240, 260

local function newRow(parent, opts)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(Widgets.ROW_H)
    row.hover = Style.Fill(row, "hover")
    row.hover:Hide()
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) self.hover:Show() end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    row.label = Style.Text(row, 12, "text")
    row.label:SetPoint("LEFT", row, "LEFT", 16, opts.hint and 5 or 0)
    row.label:SetText(opts.label or "")
    if opts.hint then
        row.hintText = Style.Text(row, 10, "muted")
        row.hintText:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -1)
        row.hintText:SetText(opts.hint)
    end
    if opts.inherit then
        row.inherited = Style.Text(row, 10, "muted")
        row.inherited:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
        row.inherited:SetText(L.INHERITED)
        row.reset = CreateFrame("Button", nil, row)
        row.reset:SetSize(60, 18)
        row.reset:SetPoint("RIGHT", row, "RIGHT", -12, 0)
        row.reset.text = Style.Text(row.reset, 11, "accent")
        row.reset.text:SetPoint("CENTER")
        row.reset.text:SetText(L.RESET_OVERRIDE)
        row.reset:SetScript("OnClick", function() opts.inherit.clear() end)
    end
    function row:RefreshInherit()
        if not opts.inherit then return end
        local over = opts.inherit.isOverridden()
        row.inherited:SetShown(not over)
        row.reset:SetShown(over)
    end
    return row
end
Widgets.NewRow = newRow
```

Then each widget as specified in the Interfaces block. Reference implementation of the slider (the other widgets follow the same pattern: build controls on `row`, set `row.Refresh` to read `opts.get()`, call `row:RefreshInherit()`, and implement `row:SetEnabled`):

```lua
local function round(v, step) return math.floor(v / step + 0.5) * step end

function Widgets.Slider(parent, opts)
    local row = newRow(parent, opts)
    local step = opts.step or 1
    local s = CreateFrame("Slider", nil, row)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(Widgets.CONTROL_W - 70, 16)
    s:SetPoint("LEFT", row, "LEFT", Widgets.CONTROL_X, 0)
    s:SetMinMaxValues(opts.min, opts.max)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(unpack(Style.COLORS.control))
    track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(4)
    s:SetThumbTexture(Style.TEXTURE)
    local thumb = s:GetThumbTexture()
    if thumb then thumb:SetSize(10, 16); thumb:SetVertexColor(unpack(Style.COLORS.accent)) end
    s:EnableMouseWheel(true)
    row.slider = s

    local e = CreateFrame("EditBox", nil, row)
    e:SetSize(60, 20)
    e:SetPoint("LEFT", s, "RIGHT", 10, 0)
    e:SetAutoFocus(false)
    e:SetFont(ns.Media.Font("Friz Quadrata"), 12, "")
    e:SetJustifyH("CENTER")
    e:SetMaxLetters(6)
    Style.Fill(e, "control")
    Style.Border(e)
    row.edit = e

    local updating = false
    local function show(v)
        updating = true
        s:SetValue(v)
        e:SetText(tostring(v))
        updating = false
    end
    local function commit(v)
        if v ~= opts.get() then opts.set(v) end
    end

    s:SetScript("OnValueChanged", function(_, v, userInput)
        if updating or userInput == false then return end
        local r = round(v, step)
        e:SetText(tostring(r))
        commit(r)
    end)
    s:SetScript("OnMouseWheel", function(_, delta)
        local v = math.max(opts.min, math.min(opts.max, opts.get() + delta * step))
        commit(v); show(v)
    end)
    local function editCommit(self)
        local n = tonumber(self:GetText())
        if n and n == n and n >= opts.min and n <= opts.max then
            commit(round(n, step))
            show(opts.get())
        else
            show(opts.get())
            Style.SetBorderColor(self, "error")
            C_Timer.After(0.6, function() Style.SetBorderColor(self, "border") end)
        end
        self:ClearFocus()
    end
    e:SetScript("OnEnterPressed", editCommit)
    e:SetScript("OnEditFocusLost", function(self) if self:GetText() ~= tostring(opts.get()) then editCommit(self) end end)
    e:SetScript("OnEscapePressed", function(self) show(opts.get()); self:ClearFocus() end)

    function row:Refresh() show(opts.get()); row:RefreshInherit() end
    function row:SetEnabled(on) s:SetEnabled(on); e:SetEnabled(on); row:SetAlpha(on and 1 or 0.45) end
    return row
end
```

Note on `tostring(v)`: settings values are plain numbers (never unit values), so `tostring` is allowed here.

The dropdown list must be a single shared frame (`Widgets.list`) re-populated per dropdown, parented to `UIParent`, strata `FULLSCREEN_DIALOG`, 12 visible rows of 22 px, closed by `Widgets.CloseList()`; `dd.list` refers to that shared frame and `dd.list.rows` to its row buttons. Tests address it through `dd.list`.

- [ ] **Step 5: Locale** — `L.INHERITED = "(inherited)"`, `L.RESET_OVERRIDE = "Reset"`.
- [ ] **Step 6: Run tests, `luac5.1 -p`, commit** "Add options style and widgets".

---

### Task 4: Test mode

**Files:**
- Create: `Options/TestMode.lua`
- Modify: `ForeverUnitFrames.toc`, `Locales/enUS.lua`
- Test: `tests/test_testmode.lua`

**Interfaces:**
- `ns.TestMode.IsOn() -> bool`
- `ns.TestMode.Set(on) -> bool` — returns false (and prints `L.TEST_MODE_COMBAT`) in combat. On: for every frame in `ns.Frames` whose `enabled` setting is true: remember `frame.unit`; if the unit does not exist, set `frame.unit = "player"` and `frame:SetAttribute("unit", "player")`; `UnregisterUnitWatch(frame)`; `frame:Show()`; `ns.Single.UpdateAll(frame)`. Off: restore the remembered unit and attribute, `RegisterUnitWatch(frame)` (if enabled), `ns.Single.UpdateAll(frame)`. Fires `ns.Fire("TEST_MODE", on)`.
- Leaves test mode automatically on `PLAYER_REGEN_DISABLED` (fires before lockdown).
- A restyle (`CONFIG_CHANGED`) during test mode must keep frames shown: `Single.StyleAll`'s `applyEnabled` re-registers the unit watch — so TestMode listens to `CONFIG_CHANGED` and re-applies itself through `ns.AfterCombat("testmode", ...)` after the restyle (queue order: the restyle keys are queued first because Single's listener is registered earlier).

- [ ] **Step 1: Failing test `tests/test_testmode.lua`**

```lua
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10 }
ns.Single.CreateAll()
local t = ns.Frames.target

H.checkTrue("target watched before", t._unitWatch)
H.checkTrue("test mode on", ns.TestMode.Set(true))
H.check("target shows player data", t:GetAttribute("unit"), "player")
H.check("target unit field", t.unit, "player")
H.check("watch removed", t._unitWatch, nil)
H.checkTrue("target shown", t:IsShown())
ns.Config.Set("target", "width", 300)
H.check("still in test after restyle", t._unitWatch, nil)
H.checkTrue("still shown after restyle", t:IsShown())
ns.TestMode.Set(false)
H.check("unit restored", t:GetAttribute("unit"), "target")
H.checkTrue("watch restored", t._unitWatch)

ns.TestMode.Set(true)
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat ends test mode", ns.TestMode.IsOn(), false)
M.combat = true
H.check("no test mode in combat", ns.TestMode.Set(true), false)
M.combat = false
```

- [ ] **Step 2–4:** implement, locale `L.TEST_MODE_COMBAT = "Test mode is not available in combat."`, `L.TEST_MODE_ON = "Test mode"`; TOC line `Options\TestMode.lua` after `Options\Schema.lua`; run; commit "Add test mode".

---

### Task 5: Options window

**Files:**
- Create: `Options/Window.lua`
- Modify: `ForeverUnitFrames.toc` (`Options\Window.lua` after `Options\TestMode.lua`), `Core/Commands.lua`, `Locales/enUS.lua`
- Test: `tests/test_window.lua`

**Interfaces:**
- `ns.Options.Toggle()`, `ns.Options.Open(scope?, tabId?)`, `ns.Options.Close()`, `ns.Options.IsOpen()`.
- `ns.Options.frame` — the window (named `ForeverUnitFramesOptions`, inserted into `UISpecialFrames` so ESC closes it).
- `ns.Options.Select(scope)` — selects a navigation entry (`"general"` or a frame key), keeps the tab if the new scope has a tab with the same id, else the first tab; highlights the real frame (see below).
- `ns.Options.SelectTab(id)`.
- `ns.Options.rows` — list of the rows on the current page (tests use it: setting rows have `row.key`, headers do not).
- `ns.Options.combatNotice`, `ns.Options.exportArea`, `ns.Options.importArea`, `ns.Options.importButton`, `ns.Options.currentScope`, `ns.Options.currentTab` — exposed for tests.
- `/fuf` without arguments toggles the window; `/fuf help` prints `L.HELP`; all existing subcommands keep working.

Layout (see Visual style):
- Title bar (drag handle): title "Forever Unit Frames" (16 px) + version from `C_AddOns.GetAddOnMetadata(ns.name, "Version")` (muted, 11 px) + close button "×" at the right.
- Left navigation (160 px): "General", then a separator line, then one entry per `ns.Units.List` (`L["FRAME_" .. key]`). Selected entry: accent bar 3 px on the left + text in accent colour.
- Tab row: one text button per `ns.Schema.Tabs(scope)` entry; selected tab accent-coloured with a 2 px accent underline.
- Content: a `ScrollFrame` with a scroll child; mouse wheel scrolls 40 px per notch; content height = sum of rows. Per section: `Widgets.Header(L["SECTION_" .. id])`, then one row per applicable key:
  - `int` → `Widgets.Slider` with `min/max` from the definition, `step = 1`;
  - `bool` → `Widgets.Checkbox`;
  - `enum` → `Widgets.Dropdown` with items `{ value = v, text = Schema.EnumText(def, v) }`;
  - `media` → `Widgets.Dropdown` with items from `ns.Media.List(def.mediaKind)`; for fonts, each item's `font = ns.Media.Font(name)` (preview);
  - `color` → `Widgets.Color`.
  - `get = function() return Config.Get(scope, key) end`, `set = function(v) return Config.Set(scope, key, v) end`.
  - On frame scopes, settings with `def.scope == "inherit"` get `inherit = { isOverridden = function() return Config.IsOverridden(scope, key) end, clear = function() Config.ClearOverride(scope, key) end }`.
  - Labels `L["SETTING_" .. key]`, hints `L["HINT_" .. key]` when that key exists in the locale table (check `L[k] ~= k`).
- Profile tab (custom page, General only): header "Export", read-only `TextArea` (full width, 70 px) filled with `ns.Codec.Encode(ns.Config.Profile())` whenever the tab is shown; header "Import", editable `TextArea` + button "Import" → `ns.Codec.Decode(text)`; success → `ns.Config.Import(profile)` + message `L.IMPORT_DONE`; failure → message `L["IMPORT_" .. errKey]` in red under the button. Header "Reset", button "Reset all settings" → a confirm step: the button text becomes "Click again to confirm" for 3 s; second click → `ns.Config.ResetAll()`.
- Footer (40 px): left: button "Unlock frames" / "Lock frames" (toggles `ns.Movers`), button "Test mode" (toggles `ns.TestMode`, shows accent border while on); right (frame pages only): dropdown-like button "Copy from…" listing the other frames (`Config.CopyScope(other, scope)`), button "Reset frame" with the same two-click confirmation (`Config.ResetScope(scope)`).
- Live refresh: `ns.Listen("CONFIG_CHANGED", ...)` → if the window is shown, call `row:Refresh()` on every visible row (values can change through dragging movers, Copy, Import, /fuf set).
- Combat lock: `PLAYER_REGEN_DISABLED` → every row `SetEnabled(false)`, footer buttons disabled, a notice bar at the top of the content in accent colour with `L.COMBAT_LOCKED`; `PLAYER_REGEN_ENABLED` → re-enable. Opening the window in combat shows it locked.
- Position: dragging the title bar moves the window (`StartMoving`/`StopMovingOrSizing`, `SetClampedToScreen(true)`). On stop, save `{ point, x, y }` to `ForeverUnitFramesDB.window` (SavedVariables only — not part of the codec). On first open without a saved position: anchored `TOPLEFT` of `UIParent` at (60, -120) so it starts beside the default frame positions instead of on top of them.
- Frame highlight: `ns.Options.Select(frameKey)` shows an accent 2 px outline around `ns.Frames[frameKey]` (textures created on the unit frame at strata-level above its border) for 1.5 s, fading out (alpha steps via `C_Timer.After`), so the user sees which frame they are editing even with the window beside it.
- Strata `HIGH`, `SetToplevel(true)`, frame level above the movers is not required (movers are `DIALOG`; the window must not cover movers).

- [ ] **Step 1: Failing test `tests/test_window.lua`**

```lua
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

SlashCmdList.FOREVERUNITFRAMES("")
H.checkTrue("slash opens window", ns.Options.IsOpen())
local found = false
for _, name in ipairs(UISpecialFrames) do if name == "ForeverUnitFramesOptions" then found = true end end
H.checkTrue("ESC closes window", found)

-- General page, Appearance tab shows font settings
ns.Options.Select("general")
ns.Options.SelectTab("appearance")
local keys = {}
for _, row in ipairs(ns.Options.rows) do if row.key then keys[#keys + 1] = row.key end end
H.check("first general row", keys[1], "fontFace")

-- Frame page, Layout tab; slider edits config
ns.Options.Select("player")
ns.Options.SelectTab("layout")
local widthRow
for _, row in ipairs(ns.Options.rows) do if row.key == "width" then widthRow = row end end
H.checkTrue("width row exists", widthRow)
widthRow.edit:SetText("310")
widthRow.edit:GetScript("OnEnterPressed")(widthRow.edit)
H.check("width set through window", ns.Config.Get("player", "width"), 310)

-- Inherited font on frame page
ns.Options.SelectTab("text")
local sizeRow
for _, row in ipairs(ns.Options.rows) do if row.key == "fontSize" then sizeRow = row end end
H.checkTrue("font size inherited marker", sizeRow.inherited:IsShown())

-- Tab kept when switching frames
ns.Options.Select("target")
H.check("tab kept", ns.Options.currentTab, "text")

-- Live refresh from outside
ns.Options.SelectTab("layout")
SlashCmdList.FOREVERUNITFRAMES("set target width 280")
for _, row in ipairs(ns.Options.rows) do
    if row.key == "width" then H.check("row refreshed", row.edit:GetText(), "280") end
end

-- Combat lock
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
local wr
for _, row in ipairs(ns.Options.rows) do if row.key == "width" then wr = row end end
H.check("slider disabled in combat", wr.slider._enabled, false)
H.check("edit box disabled in combat", wr.edit._enabled, false)
H.checkTrue("combat notice shown", ns.Options.combatNotice:IsShown())
M.SetCombat(false)
H.check("slider enabled after combat", wr.slider._enabled, true)
H.check("combat notice hidden", ns.Options.combatNotice:IsShown(), false)

-- Export / import
ns.Options.Select("general")
ns.Options.SelectTab("profile")
H.checkTrue("export filled", ns.Options.exportArea:GetText():match("^1;"))
ns.Options.importArea:SetText("1;pW222")
ns.Options.importButton:GetScript("OnClick")(ns.Options.importButton)
H.check("import applied", ns.Config.Get("player", "width"), 222)
ns.Options.importArea:SetText("9;xx")
ns.Options.importButton:GetScript("OnClick")(ns.Options.importButton)
H.check("bad import keeps settings", ns.Config.Get("player", "width"), 222)

-- Position saved
local f = ns.Options.frame
f._points = { { "TOPLEFT", UIParent, "TOPLEFT", 100, -200 } }
f.titleBar:GetScript("OnDragStop")(f.titleBar)
H.check("window x saved", ForeverUnitFramesDB.window.x, 100)

SlashCmdList.FOREVERUNITFRAMES("")
H.check("slash toggles closed", ns.Options.IsOpen(), false)
SlashCmdList.FOREVERUNITFRAMES("help")
H.checkTrue("help printed", M.chat[#M.chat]:find("/fuf"))
```

Mock additions: `_G.UISpecialFrames = {}`, `_G.C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end }`, frame `GetPoint` already returns recorded points (the window's `OnDragStop` must read its position with `GetPoint(1)` after `StopMovingOrSizing`).

- [ ] **Step 2–5:** implement, locale strings:

```lua
L.GENERAL = "General"
L.UNLOCK_FRAMES = "Unlock frames"; L.LOCK_FRAMES = "Lock frames"
L.COPY_FROM = "Copy from…"; L.RESET_FRAME = "Reset frame"
L.CONFIRM = "Click again to confirm"
L.COMBAT_LOCKED = "In combat — changes are possible again after the fight."
L.EXPORT = "Export"; L.IMPORT = "Import"; L.RESET_ALL = "Reset all settings"
L.EXPORT_HINT = "Copy this text to share or back up your profile."
L.IMPORT_DONE = "Profile imported."
L.IMPORT_CODEC_EMPTY = "Nothing to import."
L.IMPORT_CODEC_VERSION = "This profile was made by a newer version."
L.IMPORT_CODEC_FORMAT = "This is not a Forever Unit Frames profile."
L.HELP = "/fuf opens the options. Also: /fuf unlock, /fuf lock, /fuf status, /fuf reset <frame|all>, /fuf set <scope> <setting> <value>"
```

`Core/Commands.lua`: empty message → `ns.Options.Toggle()`; `help` → `ns.Print(L.HELP)`; unknown → `ns.Print(L.HELP)`.

Run tests, `luac5.1 -p`, commit "Add options window".

---

### Task 6: In-game verification (controller)

Install with `./install "<AddOns folder>"`, `/reload`, and check with screenshots — UI actions only (no movement, no casting):

1. `/fuf` opens the window at the top left, beside the frames; title, navigation, tabs, footer render with the flat style; no Lua errors.
2. Drag the window by its title; `/reload`; it reopens at the new position.
3. General → Appearance: change font, font size (slider and edit box), outline, shadow, bar texture (dropdown shows font previews), background colour (colour picker incl. opacity), border size/colour — each change is visible on both frames immediately.
4. Player → Layout: width/height, health %/power %, power bar off/on, X/Y — frame follows; selecting Player/Target highlights the real frame.
5. Player → Text: pick each tag in each slot; font override shows "Reset", Reset returns to "(inherited)".
6. Test mode: target frame appears without a target, with the player's data; leaving test mode hides it again.
7. Unlock frames → movers visible above the frames; lock.
8. Copy from Player to Target; Reset frame (two clicks).
9. Profile: export text present; import a modified string; reset all (two clicks).
10. ESC closes the window; `/fuf` reopens on the last page.

Record results in the project notes and fix anything found through the normal review loop.
