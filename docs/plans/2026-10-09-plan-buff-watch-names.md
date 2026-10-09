# Buff watch window: who misses a buff — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The raid buff watch window shows, under each watched buff, the names of the members who need it (missing
first, running out dimmed with time left, out of range grey), with a clearer header and count marks, and lets the
player switch buffs on and off from the window (gear menu, right-click).

**Architecture:** A new pure module `Raid/BuffWatchNames.lua` turns a buff state (Raid/BuffWatch.lua) into an
ordered list of names and packs it into at most two text lines with "+N". `Raid/BuffWatchWindow.lua` is reworked:
header (title, gear, next cast), one block per buff (secure row button + count marks + name lines), height per
block. Settings stay the existing `general` keys of Raid/Settings.lua.

**Tech Stack:** WoW addon Lua 5.1, mock client `tests/mock.lua`, harness `tests/harness.lua`, `tests/run <pattern>`.

Spec: `docs/specs/2026-10-09-buff-watch-names-design.md`.

## Global Constraints

- Everything on the window is built, sized, moved, shown, hidden **out of combat only** (`InCombatLockdown()`,
  `ns.AfterCombat`). In combat: greyed, no cast, gear and right-click do nothing.
- Every value read from the client goes through `ns.Secrets.Call` / `ns.Secrets.Plain`; never compare a secret.
- Words in all four locales (`Locales/enUS.lua`, `deDE`, `esES`, `frFR`) with the same keys and placeholders
  (`tests/test_locales*.lua` enforce it).
- `buffExpiring` default **3** (was 5).
- Focused tests while working (`tests/run buff`), the full suite (`tests/run`, several minutes, ~40k tests) once at
  the end only.
- Code style: comments say why, in the repo's tone; names in English; no credentials.
- Version **0.26.0**.

## File structure

- Create `Raid/BuffWatchNames.lua` — names of a state, colours, packing into lines. Pure apart from `UnitName`,
  `C_Spell.IsSpellInRange`, `RAID_CLASS_COLORS`.
- Modify `Raid/BuffWatchWindow.lua` — header, blocks, heights, tooltip, right-click, gear menu.
- Modify `ForeverUnitFrames.toc` — `Raid\BuffWatchNames.lua` right before `Raid\BuffWatchWindow.lua`.
- Modify `Raid/Settings.lua:750-751`, `Raid/BuffWatch.lua:257` — default 3.
- Modify `tests/mock.lua` (menu description) — `CreateCheckbox`, element `SetEnabled`, `M.ClickMenu` for checkboxes.
- Tests: create `tests/test_raid_buff_names.lua`, `tests/test_raid_buff_window_menu.lua`; modify
  `tests/test_raid_buff_window_rows.lua`, `tests/test_raid_buff_settings.lua`.
- Locales: 4 files. Wiki: `tools/make_wiki` regenerates `docs/wiki/Raid-Buffs.md`.

---

### Task 1: "Running out" defaults to 3 minutes

**Files:** Modify `Raid/Settings.lua:750-751`, `Raid/BuffWatch.lua:257`; Test `tests/test_raid_buff_settings.lua:36`

**Interfaces:** Produces: `general.buffExpiring` default 3.

- [ ] **Step 1: Change the test** — `tests/test_raid_buff_settings.lua:36`:
```lua
H.check("expiring: 3 minutes", def("buffExpiring").default, 3)
```
- [ ] **Step 2: Run, expect FAIL** — `tests/run buff_settings` → `FAIL expiring: 3 minutes -> 5 (want: 3)`.
- [ ] **Step 3: Implement** — `Raid/Settings.lua:751` `default = 5 })` → `default = 3 })`; `Raid/BuffWatch.lua:257`
  `(general("buffExpiring") or 5) * 60` → `(general("buffExpiring") or 3) * 60`.
- [ ] **Step 4: Run** — `tests/run buff` → all pass (a test that relied on 5 sets its own value via `RC.Set`; if one
  fails because it assumed the default, set `RC.Set("general", "buffExpiring", 5)` in that test's setup).
- [ ] **Step 5: Commit** — `git commit -am "Buff watch: running out from 3 minutes by default"`.

### Task 2: Names of a buff state (`Raid/BuffWatchNames.lua`)

**Files:** Create `Raid/BuffWatchNames.lua`; Modify `ForeverUnitFrames.toc`; Test create `tests/test_raid_buff_names.lua`

**Interfaces:**
- Consumes: a state `st` of `ns.RaidBuffWatch.state.entries` (`st.entry.single.id`, `st.needs[i] = { unit, member =
  { class }, left }`, `st.unknown`, `st.preview`).
- Produces:
  - `ns.RaidBuffNames.Of(st) -> list` of `{ name = string, class = token|nil, missing = bool, left = number,
    reach = bool }`, missing first, each part alphabetical; `{}` for nil, preview or unknown states.
  - `ns.RaidBuffNames.Text(item) -> string` with colour codes: class colour (white without class), dimmed ×0.6 and
    `" " .. L.RAID_BUFF_MINUTES:format(ceil(left/60))` when running out, grey `ff808080` when `reach == false`.
  - `ns.RaidBuffNames.Plain(item) -> string` the same without colour codes (for measuring).
  - `ns.RaidBuffNames.Pack(list, width, measure) -> lines (array of up to MAX_LINES strings)` — names joined with
    `SPACE`, greedy; when names remain after the last line, it ends with `L.RAID_BUFF_MORE:format(n)` and fits.
    `measure(plainText) -> px`.
  - Constants `MAX_LINES = 2`, `SPACE = "  "`, `GREY = "ff808080"`, `DIM = 0.6`.

- [ ] **Step 1: Write the failing test** `tests/test_raid_buff_names.lua`:
```lua
-- The names under a buff (Raid/BuffWatchNames.lua): missing first, then
-- running out (dimmed, minutes left), each alphabetical; out of range
-- grey; unknown and preview states name nobody; packed into two lines
-- with "+N".
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "Priest", isPlayer = true, auras = {} }
M.known[1243] = true
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Names, L = ns.RaidBuffNames, ns.L

M.units.party1 = { name = "Zed", class = "WARRIOR", isPlayer = true, auras = {}, distance = 10 }
M.units.party2 = { name = "Ann", class = "DRUID", isPlayer = true, auras = {}, distance = 10 }
M.units.party3 = { name = "Bob", class = "WARLOCK", isPlayer = true, auras = {}, distance = 80 }
M.units.party4 = { name = "Cy", class = "WARRIOR", isPlayer = true, auras = {}, distance = 10 }
local entry = { single = { id = 1243 } }
local st = { entry = entry, needs = {
    { unit = "party4", member = { class = "WARRIOR" }, left = 90 },
    { unit = "party1", member = { class = "WARRIOR" }, left = -1 },
    { unit = "party3", member = { class = "WARLOCK" }, left = -1 },
    { unit = "party2", member = { class = "DRUID" }, left = -1 },
} }
local list = Names.Of(st)
local order = {}
for i, item in ipairs(list) do order[i] = item.name end
H.check("missing first, alphabetical; running out last", table.concat(order, ","), "Ann,Bob,Zed,Cy")
H.check("missing", list[1].missing, true)
H.check("running out", list[4].missing, false)
H.check("out of range", list[2].reach, false)
H.check("in range", list[1].reach, true)
H.check("unknown names nobody", #Names.Of({ entry = entry, unknown = true, needs = st.needs }), 0)
H.check("preview names nobody", #Names.Of({ entry = entry, preview = true }), 0)
H.check("nil names nobody", #Names.Of(nil), 0)

-- Words: plain for measuring; colours: class, grey out of range, dimmed with minutes when running out.
H.check("plain: running out has minutes", Names.Plain(list[4]), "Cy " .. L.RAID_BUFF_MINUTES:format(2))
H.check("plain: missing has none", Names.Plain(list[1]), "Ann")
H.checkTrue("grey out of range", Names.Text(list[2]):find("|cff808080Bob|r", 1, true))
local c = RAID_CLASS_COLORS.DRUID
H.checkTrue("class colour", Names.Text(list[1]):find(("|cff%02x%02x%02xAnn|r"):format(c.r * 255, c.g * 255,
    c.b * 255), 1, true))
local w = RAID_CLASS_COLORS.WARRIOR
H.checkTrue("dimmed when running out", Names.Text(list[4]):find(("|cff%02x%02x%02x"):format(w.r * 255 * 0.6,
    w.g * 255 * 0.6, w.b * 255 * 0.6), 1, true))

-- Packing: one character = 1 px here.
local function measure(text) return #text end
local many = {}
for i = 1, 12 do many[i] = { name = ("N%02d"):format(i), missing = true, left = -1, reach = true } end
local lines = Names.Pack(many, 20, measure)
H.check("at most two lines", #lines, 2)
H.checkTrue("first line fits", measure(lines[1]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) <= 20)
H.checkTrue("the rest as +N", lines[2]:find(L.RAID_BUFF_MORE:format(12 - 7), 1, true))
H.check("one short line", #Names.Pack({ many[1] }, 20, measure), 1)
H.check("nothing, no line", #Names.Pack({}, 20, measure), 0)
```
  (Line 1 holds `N01  N02  N03  N04` = 18 px ≤ 20, four names; line 2 holds `N05  N06` + `  +7`… the expected N in
  the check must equal 12 minus the names shown — compute it as the test does: if the packing puts 5 names before
  "+N", change `12 - 7` to `12 - 5`. Run it once, read the actual second line, and make the expectation the count
  of names *not* shown; the invariant to keep is: shown + N == 12.)
- [ ] **Step 2: Run, expect FAIL** — `tests/run buff_names` → `ERROR … attempt to index field 'RaidBuffNames' (a nil value)`.
- [ ] **Step 3: Implement** `Raid/BuffWatchNames.lua`:
```lua
local _, ns = ...

-- The names under a buff in the watch window (Raid/BuffWatchWindow.lua):
-- who needs it, from a state of Raid/BuffWatch.lua, read out of combat
-- only (the window renders then). Missing first, then running out
-- (dimmed, with the minutes left), each part alphabetical; a member the
-- buff's single form plainly does not reach is grey, so "missing, but
-- nobody in range" shows who. A name the client keeps secret is left out
-- of the line (it still counts). At most MAX_LINES lines, the rest "+N".
local Names = {}
ns.RaidBuffNames = Names

local Secrets, L = ns.Secrets, ns.L

Names.MAX_LINES, Names.SPACE, Names.GREY, Names.DIM = 2, "  ", "ff808080", 0.6

function Names.Of(st)
    local list = {}
    if not st or st.preview or st.unknown or not st.needs then return list end
    local spell = st.entry and st.entry.single and st.entry.single.id
    for _, need in ipairs(st.needs) do
        local name = Secrets.Plain(Secrets.Call(UnitName, need.unit), "string")
        if name and name ~= "" then
            -- Only a plain "no" is out of range (as BuffWatch's own check).
            local reach = not spell or Secrets.Call(C_Spell.IsSpellInRange, spell, need.unit) ~= false
            list[#list + 1] = { name = name, class = need.member and need.member.class, missing = need.left < 0,
                left = need.left, reach = reach }
        end
    end
    table.sort(list, function(a, b)
        if a.missing ~= b.missing then return a.missing end
        return a.name < b.name
    end)
    return list
end

function Names.Plain(item)
    if item.missing then return item.name end
    return item.name .. " " .. L.RAID_BUFF_MINUTES:format(math.ceil(item.left / 60))
end

local function hex(r, g, b)
    return ("ff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

local function colour(item)
    if not item.reach then return Names.GREY end
    local c = item.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[item.class]
    local r, g, b = 1, 1, 1
    if c then r, g, b = c.r, c.g, c.b end
    if not item.missing then r, g, b = r * Names.DIM, g * Names.DIM, b * Names.DIM end
    return hex(r, g, b)
end

function Names.Text(item)
    return "|c" .. colour(item) .. Names.Plain(item) .. "|r"
end

-- Greedy: as many names as fit on a line; on the last line, room is
-- kept for "+N" when names would remain.
function Names.Pack(list, width, measure)
    local lines, i = {}, 1
    for line = 1, Names.MAX_LINES do
        if i > #list then break end
        local plain, text = "", ""
        while i <= #list do
            local add = (plain == "" and "" or Names.SPACE) .. Names.Plain(list[i])
            local rest = #list - i
            local more = (line == Names.MAX_LINES and rest > 0) and (Names.SPACE .. L.RAID_BUFF_MORE:format(rest)) or ""
            if plain ~= "" and measure(plain .. add .. more) > width then break end
            plain = plain .. add
            text = text .. (text == "" and "" or Names.SPACE) .. Names.Text(list[i])
            i = i + 1
        end
        lines[line] = text
    end
    if i <= #list then
        lines[#lines] = lines[#lines] .. Names.SPACE .. L.RAID_BUFF_MORE:format(#list - i + 1)
    end
    return lines
end
```
  Add to `ForeverUnitFrames.toc` the line `Raid\BuffWatchNames.lua` directly before `Raid\BuffWatchWindow.lua`.
  Add locale keys (all four files, next to `RAID_BUFF_OUT_OF_RANGE`):
  enUS `L.RAID_BUFF_MINUTES = "%dm"` `L.RAID_BUFF_MORE = "+%d"`; deDE `"%d min"`, `"+%d"`; esES `"%d min"`, `"+%d"`;
  frFR `"%d min"`, `"+%d"`.
- [ ] **Step 4: Run** — `tests/run buff_names` → all pass (adjust the "+N" expectation as noted in Step 1, keeping
  shown + N == 12); `tests/run locale` → pass.
- [ ] **Step 5: Commit** — `git add Raid/BuffWatchNames.lua tests/test_raid_buff_names.lua ForeverUnitFrames.toc Locales && git commit -m "Buff watch: the names of who needs a buff, packed into two lines"`.

### Task 3: Window layout — header, count marks, name lines, height per block

**Files:** Modify `Raid/BuffWatchWindow.lua` (constants, `Window.Size`, `row`, `render`, `Window.Create`, `paint`,
`countText`); Locales; Test modify `tests/test_raid_buff_window_rows.lua`

**Interfaces:**
- Consumes: `ns.RaidBuffNames.Of`, `.Pack`.
- Produces: `Window.BlockHeight(lineCount) -> px` = `ROW_H + lineCount * NAME_LINE_H`; `Window.Size()` =
  `WIDTH, 2*PADDING + HEADER_H + LINE_GAP + Σ BlockHeight(lines of each shown state)`; `Window.CountText(st)`;
  rows have `r.lines[1..2]` (FontStrings); `Window.title`, `Window.gear`, `Window.next`, `Window.rule`.
- Constants: `WIDTH = 260, PADDING = 6, HEADER_H = 18, LINE_GAP = 4, ROW_H = 20, ICON = 18, GAP = 4,
  NAME_LINE_H = 14, NAME_SIZE = 10, NAMES_INDENT = ICON + GAP`. Remove `LINE_H` and `NAME_MIN` (update their tests).
- Count marks: atlases `UI-LFG-DeclineMark` (missing, red `ffe64d4d`), `UI-LFG-PendingMark` (running out, yellow
  `ffffd100`), `UI-LFG-ReadyMark` (nothing needed), inline as `"|A:<atlas>:12:12|a"`. Drop `L.RAID_BUFF_COUNTS` from
  all locales.

- [ ] **Step 1: Update the tests first** in `tests/test_raid_buff_window_rows.lua`:
  - delete the "counts: neutral" check and the per-language `RAID_BUFF_COUNTS` room loop (lines 24-35); keep
    `RAID_BUFF_UNKNOWN` leaving the name ≥ 80 px room: `room = Win.WIDTH - 2*Win.PADDING - Win.ICON - 2*Win.GAP`.
  - test mode height: `H.check("test mode: three blocks' height", f:GetHeight(), 2 * Win.PADDING + Win.HEADER_H + Win.LINE_GAP + 3 * Win.BlockHeight(0))`.
  - replace `H.check("counts", row.count:GetText(), L.RAID_BUFF_COUNTS:format(2, 0))` with:
```lua
H.check("counts: the missing mark", row.count:GetText(), Win.CountText({ missing = 2, expiring = 0 }))
H.checkTrue("counts: red number", Win.CountText({ missing = 2, expiring = 0 }):find("|cffe64d4d2|r", 1, true))
H.checkTrue("counts: decline mark", Win.CountText({ missing = 2, expiring = 0 }):find("UI-LFG-DeclineMark", 1, true))
H.check("counts: running out only", Win.CountText({ missing = 0, expiring = 1 }):find("DeclineMark", 1, true), nil)
H.checkTrue("counts: nothing needed, a check", Win.CountText({ missing = 0, expiring = 0 }):find("UI-LFG-ReadyMark", 1, true))
H.check("counts: unknown", Win.CountText({ unknown = true }), L.RAID_BUFF_UNKNOWN)
H.check("counts: preview none", Win.CountText({ preview = true }), "")
-- The names under the row: who misses it (you and Ann miss Fortitude here).
H.checkTrue("names: a line", row.lines[1]:IsShown())
H.checkTrue("names: Ann", row.lines[1]:GetText():find("Ann", 1, true))
H.check("names: one line only", row.lines[2]:IsShown(), false)
H.check("height: the block grows by its line", row:GetHeight(), Win.BlockHeight(1))
-- The header: title and the next cast.
H.check("title", Win.title:GetText(), L.RAID_BUFF_WATCH_TITLE)
H.checkTrue("next cast in the header", Win.next:GetText() ~= nil)
```
  - the window-size checks that used `Win.ROW_H`/`Win.LINE_H` compute via `Win.Size()` instead.
- [ ] **Step 2: Run, expect FAIL** — `tests/run buff_window` → failures on `CountText`, `lines`, `BlockHeight`, `title`.
- [ ] **Step 3: Implement** in `Raid/BuffWatchWindow.lua`:
  - constants as above; `local Names = ns.RaidBuffNames`.
  - header in `Window.Create` (replaces the single `Window.next` line):
```lua
    Window.title = Style.Text(f, 12, "text")
    Window.title:SetPoint("TOPLEFT", f, "TOPLEFT", Window.PADDING, -Window.PADDING)
    Window.title:SetText(L.RAID_BUFF_WATCH_TITLE)
    -- Task 5 makes this a menu; here only its place and look.
    local gear = CreateFrame("Button", nil, f)
    gear:SetSize(14, 14)
    gear:SetPoint("LEFT", Window.title, "RIGHT", Window.GAP, 0)
    gear.icon = gear:CreateTexture(nil, "ARTWORK")
    gear.icon:SetAllPoints(gear)
    gear.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    Window.gear = gear
    Window.next = Style.Text(f, 11, "text")
    Window.next:SetPoint("LEFT", gear, "RIGHT", Window.GAP, 0)
    Window.next:SetPoint("RIGHT", f, "TOPRIGHT", -Window.PADDING, -(Window.PADDING + Window.HEADER_H / 2))
    Window.next:SetJustifyH("RIGHT")
    Window.next:SetWordWrap(false)
    Window.rule = f:CreateTexture(nil, "ARTWORK")
    Window.rule:SetColorTexture(1, 1, 1, 0.15)
    Window.rule:SetHeight(1)
    Window.rule:SetPoint("TOPLEFT", f, "TOPLEFT", Window.PADDING, -(Window.PADDING + Window.HEADER_H + Window.LINE_GAP / 2))
    Window.rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -Window.PADDING, -(Window.PADDING + Window.HEADER_H + Window.LINE_GAP / 2))
```
  - `Window.CountText(st)`:
```lua
local MARK = "|A:%s:12:12|a"
function Window.CountText(st)
    if st.preview then return "" end
    if st.unknown then return L.RAID_BUFF_UNKNOWN end
    if st.missing == 0 and st.expiring == 0 then return MARK:format("UI-LFG-ReadyMark") end
    local parts = {}
    if st.missing > 0 then parts[#parts + 1] = MARK:format("UI-LFG-DeclineMark") .. " |cffe64d4d" .. st.missing .. "|r" end
    if st.expiring > 0 then parts[#parts + 1] = MARK:format("UI-LFG-PendingMark") .. " |cffffd100" .. st.expiring .. "|r" end
    return table.concat(parts, "  ")
end
```
  - `row(i)`: no fixed anchor at creation (render places it); icon `ICON`; add
```lua
    r.lines = {}
    for n = 1, Names.MAX_LINES do
        local line = Style.Text(r, Window.NAME_SIZE, "text")
        line:SetPoint("TOPLEFT", r, "TOPLEFT", Window.NAMES_INDENT, -(Window.ROW_H + (n - 1) * Window.NAME_LINE_H))
        line:SetPoint("RIGHT", r, "RIGHT", 0, 0)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        r.lines[n] = line
    end
```
    The icon, name and count anchor to the row's top band: icon `SetPoint("TOPLEFT", r, "TOPLEFT", 0, -(ROW_H - ICON) / 2)`,
    name `LEFT` of icon's `RIGHT` (+GAP), count `SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, -(ROW_H - 11) / 2)`, name `RIGHT` to count `LEFT` (-GAP).
  - a scratch font string for measuring (made once in `Create`: `Window.measure = Style.Text(f, Window.NAME_SIZE, "text"); Window.measure:Hide()`),
    `local function measure(text) Window.measure:SetText(text); return Window.measure:GetStringWidth() end`.
  - `render()` computes each shown state's lines and places rows top-down:
```lua
local function linesOf(st)
    return Names.Pack(Names.Of(st), Window.WIDTH - 2 * Window.PADDING - Window.NAMES_INDENT, measure)
end
```
    In the loop, for a shown row: `local lines = linesOf(st)`; set `r.lines[n]:SetText(lines[n] or "")`,
    `r.lines[n]:SetShown(lines[n] ~= nil)`; `r:SetHeight(Window.BlockHeight(#lines))`;
    `r:ClearAllPoints(); r:SetPoint("TOPLEFT", Window.frame, "TOPLEFT", Window.PADDING, -y)`; `y = y + Window.BlockHeight(#lines)`
    starting at `y = Window.PADDING + Window.HEADER_H + Window.LINE_GAP`. Keep `Window.blockLines[i] = #lines` so
    `Window.Size()` sums the same heights (`Size` calls `linesOf` itself when render has not run, e.g. in tests: compute
    from `states()` directly so both always agree).
    `r.count:SetText(Window.CountText(st))`. `Window.next`: unchanged text logic.
  - `paint(colorKey)`: also paints `Window.title`; name lines keep their colour codes (in combat they stay as they
    are: the codes override; acceptable, the row texts grey).
  - `r:SetWidth(Window.WIDTH - 2 * Window.PADDING)`.
  Locales: delete `L.RAID_BUFF_COUNTS` in all four files.
- [ ] **Step 4: Run** — `tests/run buff_window` → pass; `tests/run buff` → pass; `tests/run locale` → pass.
- [ ] **Step 5: Commit** — `git commit -am "Buff watch window: header, count marks, the names under each buff"`.

### Task 4: Tooltip with all names; right-click stops watching a buff

**Files:** Modify `Raid/BuffWatchWindow.lua` (`tooltip`, `row`, `render`); Locales; Test modify `tests/test_raid_buff_window_rows.lua`

**Interfaces:** Produces: `Window.SwitchOff(st)` (sets `general[buff key] = false` out of combat); row attribute
`type2 = ATTRIBUTE_NOOP` (`""`), `PostClick` handler. Buff key of an entry: `Data.BUFFS[i].key` where
`buff.id == st.entry.id`; a blessing entry (`entry.classes`) → `Data.BLESSINGS_KEY`.

Facts (Blizzard_FrameXML/SecureTemplates.lua, Forever 70291): `SecureButton_GetModifiedAttribute` turns
`ATTRIBUTE_NOOP` (`""`) into nil, so `type2 = ""` makes the right button do nothing secure while `type` (left)
still casts.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_raid_buff_window_rows.lua`, in the party section):
```lua
-- Right-click: nothing secure, and the buff is no longer watched.
H.check("right button casts nothing", row:GetAttribute("type2"), "")
local before = #M.casts
H.check("right-click: no secure action", M.SecureClick(row, "RightButton"), nil)
H.check("right-click: no cast", #M.casts, before)
row:GetScript("PostClick")(row, "RightButton", false)
M.Tick(1)
H.check("right-click: switched off", ns.RaidConfig.Get("general", "buffFortitude"), false)
ns.RaidConfig.Set("general", "buffFortitude", true)
M.Tick(1)
-- The tooltip: the cast, then every name, then the hint.
row = Win.rows[1]
row:GetScript("OnEnter")(row)
local all = table.concat(M.tooltipLines or {}, "\n")
H.checkTrue("tooltip: Ann", all:find("Ann", 1, true))
H.checkTrue("tooltip: the right-click hint", all:find(L.RAID_BUFF_RIGHT_CLICK, 1, true))
row:GetScript("OnLeave")(row)
-- In combat a right-click does nothing.
M.SetCombat(true)
row:GetScript("PostClick")(row, "RightButton", false)
H.check("in combat: still watched", ns.RaidConfig.Get("general", "buffFortitude"), true)
M.SetCombat(false)
M.Tick(1)
```
  (Check the mock's combat helper name with `grep -n "function M.SetCombat\|M.combat = v" tests/mock.lua`; line 3325
  sets `M.combat = v` inside it. Check `M.tooltipLines` collects `AddLine` too: `grep -n tooltipLines tests/mock.lua`.)
- [ ] **Step 2: Run, expect FAIL** — `tests/run buff_window_rows`.
- [ ] **Step 3: Implement**:
```lua
local Data = ns.RaidBuffData

local function keyOf(entry)
    if entry.classes then return Data.BLESSINGS_KEY end
    for _, buff in ipairs(Data.BUFFS) do
        if buff.id == entry.id then return buff.key end
    end
end

-- Out of combat: the buff is no longer watched (the options' switch).
function Window.SwitchOff(st)
    if InCombatLockdown() or not st or st.preview then return end
    local key = keyOf(st.entry)
    if key then ns.RaidConfig.Set("general", key, false) end
end
```
  In `row(i)`: `r:SetAttribute("type2", "")` (comment: ATTRIBUTE_NOOP, the right button casts nothing) and
```lua
    -- After the secure click; only the up stroke (rows take both).
    r:SetScript("PostClick", function(self, button, down)
        if button == "RightButton" and not down then Window.SwitchOff(self.state) end
    end)
```
  `SmartBuff.Set` clears `type` only; make sure `render` re-sets `type2 = ""` is not cleared (SmartBuff.Set touches
  `type`, `spell`, `unit` only — confirm). In `tooltip`: after `GameTooltip:SetText(...)`, for a live state add every
  name: `for _, item in ipairs(Names.Of(st)) do GameTooltip:AddLine(Names.Text(item)) end`, then
  `GameTooltip:AddLine(L.RAID_BUFF_RIGHT_CLICK, 0.6, 0.6, 0.6)` (not on preview rows).
  Locales: enUS `L.RAID_BUFF_RIGHT_CLICK = "Right-click: stop watching this buff"`; deDE
  `"Rechtsklick: diesen Buff nicht mehr überwachen"`; esES `"Clic derecho: dejar de vigilar este beneficio"`;
  frFR `"Clic droit : ne plus surveiller cette amélioration"`.
- [ ] **Step 4: Run** — `tests/run buff` → pass.
- [ ] **Step 5: Commit** — `git commit -am "Buff watch window: all names in the tooltip, right-click stops watching a buff"`.

### Task 5: Gear menu — switch your class's buffs on and off

**Files:** Modify `Raid/BuffWatchWindow.lua`; `tests/mock.lua` (menu description); Locales; Test create
`tests/test_raid_buff_window_menu.lua`

**Interfaces:**
- Produces: `Window.OpenMenu(owner)`; menu = title `L.RAID_BUFF_WATCH_TITLE`, then per `Data.BUFFS` entry of your
  class a checkbox `L["RAID_SETTING_" .. buff.key]` (not learned: `.. " (" .. L.RAID_BUFF_NOT_LEARNED .. ")"`,
  `SetEnabled(false)`); a paladin who knows a blessing: checkbox `L.RAID_SETTING_buffBlessings`. Toggle =
  `RaidConfig.Set("general", key, not current)`. Out of combat only (in combat the gear does nothing).
- Mock: menu description gets `CreateCheckbox(text, isSelected, setSelected, data)` → element
  `{ kind = "checkbox", text, isSelected, setSelected, data, enabled = true, SetEnabled = function(e, v) e.enabled = v end }`;
  `M.ClickMenu` accepts `checkbox` (calls `setSelected(data)` unless `enabled == false`); `M.MenuSelected` works for it.

- [ ] **Step 1: Extend the mock** (`tests/mock.lua`, in `menuDescription`'s `methods`):
```lua
        -- Blizzard_Menu: CreateCheckbox(text, isSelected, setSelected, data);
        -- the element's SetEnabled greys it (a click then does nothing).
        CreateCheckbox = function(self, text, isSelected, setSelected, data)
            assert(type(text) == "string", "CreateCheckbox: text")
            assert(type(isSelected) == "function" and type(setSelected) == "function", "CreateCheckbox: functions")
            local e = { kind = "checkbox", text = text, isSelected = isSelected, setSelected = setSelected, data = data,
                enabled = true }
            function e:SetEnabled(v) self.enabled = v end
            table.insert(self.elements, e)
            return e
        end,
```
  and in `M.ClickMenu`: accept `element.kind == "checkbox"`; `if element.kind == "checkbox" then if element.enabled == false then return end return element.setSelected(element.data) end`.
- [ ] **Step 2: Write the failing test** `tests/test_raid_buff_window_menu.lua`:
```lua
-- The buff watch window's gear: a check per buff of your class; one the
-- spell book does not know is greyed; a click switches it; in combat the
-- gear does nothing.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "Priest", isPlayer = true, auras = {} }
M.known[1243], M.known[976] = true, true   -- Fortitude, Shadow Protection; no Divine Spirit (level < 30)
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, Win, L = ns.RaidConfig, ns.RaidBuffWindow, ns.L
M.units.party1 = { name = "Ann", class = "MAGE", isPlayer = true, auras = {}, distance = 10 }
M.SetGroup({ "party1" })
M.Tick(1)
Win.OpenMenu(Win.gear)
local menu = M.menu
H.check("title", menu.elements[1].text, L.RAID_BUFF_WATCH_TITLE)
local function find(text)
    for _, e in ipairs(menu.elements) do if e.text == text then return e end end
end
local fort = find(L.RAID_SETTING_buffFortitude)
H.checkTrue("fortitude listed", fort)
H.check("fortitude on", M.MenuSelected(fort), true)
local spirit = find(L.RAID_SETTING_buffSpirit .. " (" .. L.RAID_BUFF_NOT_LEARNED .. ")")
H.checkTrue("spirit listed, not learned", spirit)
H.check("spirit greyed", spirit.enabled, false)
H.check("no mage buff for a priest", find(L.RAID_SETTING_buffIntellect), nil)
M.ClickMenu(fort)
H.check("click: off", RC.Get("general", "buffFortitude"), false)
M.ClickMenu(fort)
H.check("click: on again", RC.Get("general", "buffFortitude"), true)
-- The gear's click opens it; in combat it does not.
M.menu = nil
Win.gear:GetScript("OnClick")(Win.gear, "LeftButton")
H.checkTrue("gear opens the menu", M.menu)
M.menu = nil
M.SetCombat(true)
Win.gear:GetScript("OnClick")(Win.gear, "LeftButton")
H.check("in combat: no menu", M.menu, nil)
M.SetCombat(false)
```
- [ ] **Step 3: Run, expect FAIL** — `tests/run buff_window_menu` → `OpenMenu` nil.
- [ ] **Step 4: Implement** in `Raid/BuffWatchWindow.lua`:
```lua
local function generalSwitch(key)
    return function() return ns.RaidConfig.Get("general", key) == true end,
        function() ns.RaidConfig.Set("general", key, not (ns.RaidConfig.Get("general", key) == true)) end
end

-- The gear's menu: every group buff of your class, as the options'
-- Buffs tab lists them; one the spell book does not know yet greyed.
function Window.OpenMenu(owner)
    if InCombatLockdown() then return end
    local class = Watch.PlayerClass()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L.RAID_BUFF_WATCH_TITLE)
        for _, buff in ipairs(Data.BUFFS) do
            if buff.class == class then
                local learned = Data.Highest(buff.single) ~= nil
                local text = L["RAID_SETTING_" .. buff.key]
                if not learned then text = text .. " (" .. L.RAID_BUFF_NOT_LEARNED .. ")" end
                local box = root:CreateCheckbox(text, generalSwitch(buff.key))
                if not learned then box:SetEnabled(false) end
            end
        end
        if class == "PALADIN" then
            local known = false
            for _, spells in pairs(Data.BLESSING) do
                if Data.Highest(spells.single) then known = true end
            end
            local box = root:CreateCheckbox(L.RAID_SETTING_buffBlessings, generalSwitch(Data.BLESSINGS_KEY))
            if not known then box:SetEnabled(false) end
        end
    end)
end
```
  (`generalSwitch` returns two functions; `CreateCheckbox(text, isSelected, setSelected)` takes them in that order.)
  In `Window.Create`: `gear:SetScript("OnClick", function(self) Window.OpenMenu(self) end)` and a tooltip
  `L.RAID_BUFF_MENU_TIP` on `OnEnter`/`OnLeave`.
  Locales: enUS `L.RAID_BUFF_NOT_LEARNED = "not learned yet"`, `L.RAID_BUFF_MENU_TIP = "Which buffs to watch"`;
  deDE `"noch nicht gelernt"`, `"Welche Buffs überwacht werden"`; esES `"aún no aprendido"`,
  `"Qué beneficios vigilar"`; frFR `"pas encore appris"`, `"Quelles améliorations surveiller"`.
- [ ] **Step 5: Run** — `tests/run buff` → pass; `tests/run locale` → pass.
- [ ] **Step 6: Commit** — `git add -A tests/test_raid_buff_window_menu.lua && git commit -am "Buff watch window: a gear menu to switch the buffs"`.

### Task 6: Test mode preview names, wiki, version, full run, docs

**Files:** Modify `Raid/BuffWatchWindow.lua` (preview names), `ForeverUnitFrames.toc` (Version 0.26.0), `Core/News.lua`
if the addon lists what is new per version (check: `grep -n "0.25" Core/News.lua`), wiki via `tools/make_wiki`.

- [ ] **Step 1: Preview names** — in test mode a preview block shows two sample names so the window has a realistic
  size: `Names.Of` returns `{}` for previews, so in `linesOf(st)` use, for `st.preview`, the list
  `{ { name = L.RAID_BUFF_SAMPLE_MISSING, missing = true, left = -1, reach = true },
     { name = L.RAID_BUFF_SAMPLE_EXPIRING, missing = false, left = 120, reach = true } }`.
  Locales: enUS `"Missing"`, `"Running out"`; deDE `"Fehlt"`, `"Läuft ab"`; esES `"Falta"`, `"Se agota"`;
  frFR `"Manque"`, `"Expire"`. Update the test-mode height check: `3 * Win.BlockHeight(1)`.
- [ ] **Step 2: Version and what's new** — `## Version: 0.26.0`; if `Core/News.lua` carries per-version entries,
  add 0.26.0: "Buff watch: the names of who misses a buff, a gear to choose the buffs, right-click to stop watching
  one; running out from 3 minutes" in all four languages (follow the existing entries' shape).
- [ ] **Step 3: Wiki** — `tools/make_wiki` (regenerates `docs/wiki/*.md` from the options); check the Buffs page
  shows default 3 and mention the window's names/gear/right-click in its intro if the intro text comes from a
  locale string (`grep -n "The buff watch: your class" Locales/enUS.lua`), updating all four languages.
- [ ] **Step 4: Full run once** — `tests/run` → `N passed, 0 failed`.
- [ ] **Step 5: Commit** — `git commit -am "Forever Unit Frames 0.26.0: who misses a buff, in the buff watch window"`.

## Self-review notes

- Spec 2.1 layout → Tasks 3; 2.1 names/grey/+N → Tasks 2-3; 2.2 default 3 → Task 1; 2.3 tooltip → Task 4;
  2.4 gear + right-click → Tasks 4-5; 2.5 height → Task 3; 2.6 names via UnitName/Secrets → Task 2;
  2.7 preview → Task 6; tests and languages throughout; wiki → Task 6.
- In-game check after Task 6 (not automatable): the atlases render, the right button casts nothing in the real
  client, the gear menu opens.
