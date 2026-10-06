# Forever Unit Frames — Raid plan R4b: window actions, test mode, wiki and release

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The raid options window does everything spec §6 asks for: copy the edited size from another size or another character (after a second click), reset it (after a second click), export and import it as a text with clear messages, and switch a test mode that shows a pretend raid of the edited size at that size's position — ended by closing the window or by combat. The unit frames' window leads to it and the raid window back (the raid frames' own minimap button and addon compartment entry came with R4c). The wiki gets a page per raid tab, the CurseForge description a raid section, and the version becomes 0.22.0 (no upload).

**Architecture:** The raid window's footer (`Raid/Options/Window.lua`) gets Test mode, Unit frames…, Export / Import, Copy from… and Reset this size; export and import show in a panel over the tab's page. `Raid/TestMode.lua` gets a switch of its own beside the unit frames' test mode and a preview size: while the window is open the pretend raid shows the edited size (`Raid/Cell.lua`'s `Cell.Size()` asks `RaidTestMode.PreviewSize()`), so the panel's layout, cells and mover all use that size's profile. `tools/make_wiki.lua` writes `docs/wiki/Raid-*.md` from `Raid/Options/Schema.lua`.

**Tech Stack:** Lua 5.1, WoW: Forever API (Interface 16001, build 1.60.1.70205), offline tests with `lua5.1` + `tests/mock.lua` (`tests/run`).

Spec: `docs/specs/2026-10-06-raid-frames-design.md` (part 1; §6 Options window, §7 Test mode, §10 Release). Raid plan order: R1 … R3b, R4a Options menu and window (all done) → R4c Cells of their own, dispel square, raid minimap button (`docs/plans/2026-10-06-plan-raid-4c-cells-dispel-square-minimap.md`) → **R4b Window actions, test mode, wiki and release (this plan)**.

Base: the last commit of R4c ("Raid: damage block sorted by role, clearer words, a unit frames' string refused"); `tests/run` there: `23614 passed, 0 failed`. Every task below was replayed in order on a scratch worktree after R4c; the outputs under "Expected" are what `tests/run` printed there.

## Global Constraints

- Everything in English: file names, identifiers, comments. Every new user-facing string is a locale key in all four languages, `Locales/enUS.lua`, `deDE.lua`, `esES.lua`, `frFR.lua` (`tests/test_locale.lua` requires each English key in every language with the same `%` placeholders); German in the style of the existing `deDE` strings.
- Target client: WoW: Forever, `## Interface: 16001`. Client facts only from the Forever UI source (game type `camelot`); the ones used are in the table below. Never write the name of the local lookup tool into the repository.
- The unit frames and their options window stay the same for users: no unit-frame setting, key, code, scope letter or default changes.
- Raid setting codes are permanent once released and unique within the raid registry; enums are stored by index, append only.
- No secret-value maths, comparisons or truth tests: a value that may be secret is checked with `ns.Secrets.IsSecret` (or `type(x) == "nil"`) before anything else touches it (the mock's secret is a table and would pass a truth test unnoticed). No secure snippets. Protected frames change only out of combat (`ns.AfterCombat`).
- `ns.On` throws on unknown event names in the client: no new game event is used (the ones below are in use already).
- The mock stays faithful: it may be stricter than the client source, never more permissive.
- Public repository: no local paths, host names, character names or anything about the author's machine in files or commit messages. Test names are neutral.
- Every commit message ends with:
  `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
- Do not push. Every task ends with `tests/run` green and one commit (`git add` only the files the task lists).
- A full `tests/run` takes about a minute and a half and several GB of memory (as before).
- No new setting. New locale keys (7): `RAID_RESET_SIZE`, `RAID_SHARE`, `RAID_COPY_CHARACTER`, `RAID_EXPORT_HINT`, `RAID_IMPORT_HINT` (Task 1); `RAID_FRAMES_BUTTON`, `UNIT_FRAMES_BUTTON` (Task 3).
- No existing test is edited. The unit window gains one button in its navigation column; nothing else of it changes. The unit frames' minimap button stays as it is (no Shift-click: the raid frames have their own button since R4c).
- Game events in use, none new: `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`. New internal event: `RAID_TEST_MODE (state)` (Task 2).
- Do not run `tools/release`, `tools/publish_wiki` or anything that uploads, tags or pushes: the maintainer releases separately.

## Client facts this plan relies on (build 1.60.1.70205)

Nothing beyond R4a's, R4c's and the earlier plans'. `IsShiftKeyDown()` is a plain global, true while Shift is held (already used by `Options/Widgets.lua`); Task 3's test holds it to show that the unit frames' minimap button and addon compartment entry ignore it.

## Design decisions

- **Where the actions sit:** the header bar holds the sizes and the size switch (no room for more at 780 px); the actions on the edited size as a whole sit in the footer, always visible, as in the unit window: left *Test mode* and *Unit frames…*, right *Export / Import*, *Copy from…*, *Reset this size*. Deviation from spec §6's wording "header bar", same function.
- **Copy from:** the other sizes, then every size of every other character with a raid profile (`RaidProfiles.Characters()`), as "Name-Realm: 20 players". Picking one arms the button (it reads "Click again to confirm" in red for three seconds); the second click copies. Selecting another size or closing the window disarms. Reset is the unit window's two-click button.
- **Export / Import:** one panel over the tab's page with the edited size's export (read-only) and an import field; the import trims the text and puts it on the edited size; messages: the codec's errors (`IMPORT_CODEC_*`), `IMPORT_RAID_NO_SIZE`, `IMPORT_DONE`, or `IMPORT_SKIPPED` with the count of entries left out. Choosing a tab hides the panel; another size updates it.
- **Test mode:** the raid window's switch is separate from the unit frames' test mode (which shows every unit frame too); the pretend raid shows while either is on. While the window is open the pretend raid shows the edited size at that size's position (`Cell.Size()`), also with the unit frames' test mode. Closing the window ends its switch and the preview; entering combat ends the switch (combat already ends the unit frames' test mode); turning it on in combat is refused with the unit frames' message. Pretend cells are secure buttons on the player: as before they change only out of combat (`ns.AfterCombat("raidLayout")`).
- **Entry points:** `/fuf raid` (R4a); the raid frames' own minimap button and their addon compartment entry (R4c); a *Raid frames…* button above the language in the unit window's navigation (closes it, opens the raid window); *Unit frames…* in the raid window leads back. Shift-click on the unit frames' minimap button is not added: it would be a second way to do what the raid button does.
- **Wiki:** one generated page per raid tab, `Raid-<Tab>.md` (`&` written as "and"), four columns (option, what it does, choices, default; a default that differs per size listed per size), the size switch as "Header bar" on the General page, the Cell tab's note; the sidebar lists them under **Raid frames**. The pages are made from the raid menu, so R4c's settings (fonts, colours, border, heals, dispel square, minimap button) are on them; the test checks every setting by its label. `Home.md` is written by hand.
- **Release prep:** `## Version: 0.22.0` and a raid section in `docs/curseforge/description.md`; the upload stays with the maintainer, after the in-game check (spec §10).

---

### Task 1: Raid options window: copy, reset, export and import of the edited size

**Files:**
- Modify: `Raid/Options/Window.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_raid_window_actions.lua`

**Interfaces:**
- Consumes: `ns.RaidOptions` (R4a), `ns.Options.ConfirmButton`, `ns.Widgets.Dropdown` / `Button` / `TextArea` / `Header`, `ns.RaidProfiles.Characters`, `CopySize`, `CopyFromCharacter`, `ResetSize`, `Export`, `Import` (R4a Task 1), locale `COPY_FROM`, `CONFIRM`, `EXPORT`, `IMPORT`, `IMPORT_DONE`, `IMPORT_CODEC_*`, `IMPORT_RAID_NO_SIZE`, `IMPORT_SKIPPED`.
- Produces: `ns.RaidOptions.copyRow` (`button`, `pending`, `Disarm()`), `resetButton` (`Disarm()`), `shareButton`, `share`, `exportHint`, `exportArea`, `importHint`, `importArea`, `importButton`, `importMessage`, `ShowShare(on)`; locale keys `RAID_RESET_SIZE`, `RAID_SHARE`, `RAID_COPY_CHARACTER` (two `%s`), `RAID_EXPORT_HINT`, `RAID_IMPORT_HINT` (one `%s` each).

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_window_actions.lua`:

```lua
-- What the raid options window does with the edited size as a whole
-- (Raid/Options/Window.lua): copy from another size or another
-- character after a second click, reset after a second click, export and
-- import as a string, locked in combat.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = { raid = { ["Healer-Testrealm"] = { r20 = { cellWidth = 140 } } } }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, L = ns.RaidOptions, ns.RaidConfig, ns.L

local function click(button) button:GetScript("OnClick")(button) end
local list
local function pick(text)
    click(RO.copyRow.button)
    for _, r in ipairs(list.rows) do
        if r:IsShown() and r.text:GetText() == text then return click(r) end
    end
    error("no item " .. text)
end

RO.Open(40)
list = ns.Widgets.list
H.check("copy button", RO.copyRow.button.text:GetText(), "Copy from…")
H.check("reset button", RO.resetButton.text:GetText(), "Reset this size")
H.check("share button", RO.shareButton.text:GetText(), "Export / Import")

-- Copy from: the other sizes, then every size of the other characters.
click(RO.copyRow.button)
local texts = {}
for i, item in ipairs(list.items) do texts[i] = item.text end
H.check("copy choices", table.concat(texts, ","), "10 players,20 players,Healer-Testrealm: 10 players,"
    .. "Healer-Testrealm: 20 players,Healer-Testrealm: 40 players")
ns.Widgets.CloseList()

-- A pick arms the button; the second click copies.
RC.Set("r20", "cellHeight", 50)
pick("20 players")
H.check("armed", RO.copyRow.button.text:GetText(), L.CONFIRM)
H.check("armed in red", RO.copyRow.button.text._color[1], ns.Style.COLORS.error[1])
H.check("nothing copied yet", RC.Get("r40", "cellHeight"), 38)
click(RO.copyRow.button)
H.check("copied", RC.Get("r40", "cellHeight"), 50)
H.check("disarmed", RO.copyRow.button.text:GetText(), "Copy from…")
H.check("no list opened by the confirming click", list:IsShown(), false)

-- Left armed, it disarms after a few seconds.
pick("10 players")
M.RunTimers()
H.check("disarmed by time", RO.copyRow.button.text:GetText(), "Copy from…")
H.check("not copied", RC.Get("r40", "cellHeight"), 50)
click(RO.copyRow.button)
H.checkTrue("a click opens the list again", list:IsShown())
ns.Widgets.CloseList()

-- Another character's size.
pick("Healer-Testrealm: 20 players")
click(RO.copyRow.button)
H.check("copied from the character", RC.Get("r40", "cellWidth"), 140)
H.check("the character untouched", ForeverUnitFramesDB.raid["Healer-Testrealm"].r40, nil)

-- Another edited size disarms.
pick("20 players")
RO.SelectSize(10)
H.check("size change disarms", RO.copyRow.button.text:GetText(), "Copy from…")
RO.SelectSize(40)

-- Reset this size: two clicks.
click(RO.resetButton)
H.check("reset armed", RC.Get("r40", "cellWidth"), 140)
click(RO.resetButton)
H.check("reset", RC.Get("r40", "cellWidth"), 80)
H.check("other sizes kept", RC.Get("r20", "cellHeight"), 50)

-- Export and import, in place of the tab's page.
RC.Set("r40", "cellWidth", 90)
click(RO.shareButton)
H.checkTrue("panel shown", RO.share:IsShown())
H.check("export of the edited size", RO.exportArea:GetText(), ns.RaidProfiles.Export(40))
H.check("export hint names it", RO.exportHint:GetText(), "Copy this text to share or back up the 40 players profile.")
RO.SelectSize(20)
H.check("export follows the size", RO.exportArea:GetText(), ns.RaidProfiles.Export(20))
H.check("import hint follows", RO.importHint:GetText(), "Paste a raid size here: it replaces the 20 players profile.")
RO.importArea:SetText("  " .. ns.RaidProfiles.Export(40) .. "  ")
click(RO.importButton)
H.check("imported onto 20", RC.Get("r20", "cellWidth"), 90)
H.check("as 40 shows it, its height included", RC.Get("r20", "cellHeight"), 38)
H.check("done", RO.importMessage:GetText(), L.IMPORT_DONE)
H.check("area cleared", RO.importArea:GetText(), "")
H.check("export shows the new state", RO.exportArea:GetText(), ns.RaidProfiles.Export(20))
RO.importArea:SetText("1;gSM2")
click(RO.importButton)
H.check("no size: refused", RO.importMessage:GetText(), L.IMPORT_RAID_NO_SIZE)
H.check("refusal in red", RO.importMessage._color[1], ns.Style.COLORS.error[1])
H.check("size kept", RC.Get("r20", "cellWidth"), 90)
RO.importArea:SetText("1;bCW100;junk")
click(RO.importButton)
H.check("skipped entries counted", RO.importMessage:GetText(),
    "Imported; 1 entries could not be read and were left out.")
H.check("readable part imported", RC.Get("r20", "cellWidth"), 100)
RO.importArea:SetText("")
click(RO.importButton)
H.check("empty", RO.importMessage:GetText(), L.IMPORT_CODEC_EMPTY)
click(RO.shareButton)
H.check("button hides it again", RO.share:IsShown(), false)
click(RO.shareButton)
RO.SelectTab("layout")
H.check("a tab hides it", RO.share:IsShown(), false)

-- Combat locks what changes the profile.
click(RO.shareButton)
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("copy locked", RO.copyRow.button:IsEnabled(), false)
H.check("reset locked", RO.resetButton:IsEnabled(), false)
H.check("import locked", RO.importButton:IsEnabled(), false)
H.check("import area locked", RO.importArea.edit:IsEnabled(), false)
H.check("export still readable", RO.shareButton:IsEnabled(), true)
M.SetCombat(false)
H.check("copy unlocked", RO.copyRow.button:IsEnabled(), true)
H.check("import unlocked", RO.importButton:IsEnabled(), true)

-- Closing disarms.
click(RO.resetButton)
RO.Close()
H.check("closing disarms reset", RO.resetButton.text:GetText(), "Reset this size")
H.check("nothing blocked", #M.blocked, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_window_actions.lua`

Expected:

```text
test_raid_window_actions.lua
  ERROR test_raid_window_actions.lua:25: attempt to index field 'copyRow' (a nil value)
0 passed, 1 failed
```

- [ ] **Step 3: Copy from, reset, export and import in the footer**

In `Raid/Options/Window.lua`:

Replace

```lua
-- The raid options window, in the style of the unit frames' (the same
-- widgets and colours): a header bar with the raid size whose profile is
-- edited (the one shown now is marked) and which size the panel shows,
-- the tabs of the raid menu (Raid/Options/Schema.lua) and their rows. A
-- plain (non-secure) frame: every change goes through ns.RaidConfig,
-- whose RAID_CONFIG_CHANGED listeners restyle the raid panel out of
-- combat. In combat the window stays open but its controls lock.
local RaidOptions = {}
ns.RaidOptions = RaidOptions

```

with

```lua
-- The raid options window, in the style of the unit frames' (the same
-- widgets and colours): a header bar with the raid size whose profile is
-- edited (the one shown now is marked) and which size the panel shows,
-- the tabs of the raid menu (Raid/Options/Schema.lua) and their rows; a
-- footer with what acts on the edited size as a whole: copy from another
-- size or character, export and import it, reset it. A plain
-- (non-secure) frame: every change goes through ns.RaidConfig, whose
-- RAID_CONFIG_CHANGED listeners restyle the raid panel out of combat. In
-- combat the window stays open but its controls lock.
local RaidOptions = {}
ns.RaidOptions = RaidOptions

```

In `Raid/Options/Window.lua`:

Replace

```lua
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET, NOTE_H = 4, 16, 8, 16, 34
local BUTTON_H, DROPDOWN_W, GAP = 24, 160, 8
local DEFAULT_POSITION = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 90, y = -150 }

local frame
```

with

```lua
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET, NOTE_H = 4, 16, 8, 16, 34
local BUTTON_H, DROPDOWN_W, GAP, WIDE_BUTTON_W, SHARE_BUTTON_W = 24, 160, 8, 160, 140
local TEXT_AREA_H, MESSAGE_H, CONFIRM_SECONDS = 70, 20, 3
local DEFAULT_POSITION = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 90, y = -150 }

local frame
```

In `Raid/Options/Window.lua`:

Replace

```lua
    return bar
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    frame.footer = footer
    return footer
end
```

with

```lua
    return bar
end

-- Copy from: the other sizes, and every size of the other characters
-- that have a raid profile. Picking one arms the button; a second click
-- within a few seconds copies onto the edited size.
local function copyItems()
    local items = {}
    for _, size in ipairs(Raid.SIZES) do
        if size ~= RaidOptions.Size() then items[#items + 1] = { value = "size:" .. size, text = sizeText(size) } end
    end
    for _, key in ipairs(ns.RaidProfiles.Characters()) do
        for _, size in ipairs(Raid.SIZES) do
            local text = L.RAID_COPY_CHARACTER:format(key, sizeText(size))
            items[#items + 1] = { value = "char:" .. key .. ":" .. size, text = text }
        end
    end
    return items
end

local function runCopy(value)
    local to = RaidOptions.Size()
    local size = tonumber(value:match("^size:(%d+)$"))
    if size then
        ns.RaidProfiles.CopySize(size, to)
        return
    end
    local key, from = value:match("^char:(.+):(%d+)$")
    if key then ns.RaidProfiles.CopyFromCharacter(key, tonumber(from), to) end
end

local function copyFromRow(footer)
    local row
    local function disarm()
        row.pending = nil
        row.button.text:SetText(L.COPY_FROM)
        Style.Paint(row.button.text, "text")
    end
    row = Widgets.Dropdown(footer, {
        items = copyItems,
        get = function() return nil end,
        set = function(value)
            local token = {}
            row.pending, row.token = value, token
            C_Timer.After(CONFIRM_SECONDS, function() if row.token == token and row.pending then disarm() end end)
        end,
    })
    row:SetSize(WIDE_BUTTON_W, BUTTON_H)
    row:EnableMouse(false)
    row.hover:SetAlpha(0)
    row.button:ClearAllPoints()
    row.button:SetAllPoints(row)
    local open = row.button:GetScript("OnClick")
    row.button:SetScript("OnClick", function(self)
        local value = row.pending
        if not value then return open(self) end
        disarm()
        runCopy(value)
    end)
    local refresh = row.Refresh
    function row:Refresh()
        refresh(self)
        if self.pending then
            self.button.text:SetText(L.CONFIRM)
            Style.Paint(self.button.text, "error")
        else
            self.button.text:SetText(L.COPY_FROM)
        end
    end
    row.Disarm = disarm
    row:Refresh()
    return row
end

-- Export and import of the edited size, over the tabs' pages.
local function showImportMessage(text, colorKey)
    RaidOptions.importMessage:SetText(text)
    Style.Paint(RaidOptions.importMessage, colorKey)
end

local function runImport()
    local text = (RaidOptions.importArea:GetText() or ""):match("^%s*(.-)%s*$")
    local ok, result = ns.RaidProfiles.Import(text, RaidOptions.Size())
    if not ok then
        showImportMessage(L["IMPORT_" .. result], "error")
        return
    end
    RaidOptions.importArea:SetText("")
    showImportMessage(result > 0 and L.IMPORT_SKIPPED:format(result) or L.IMPORT_DONE, "accent")
end

local function refreshShare()
    local size = sizeText(RaidOptions.Size())
    RaidOptions.exportHint:SetText(L.RAID_EXPORT_HINT:format(size))
    RaidOptions.importHint:SetText(L.RAID_IMPORT_HINT:format(size))
    RaidOptions.exportArea:SetText(ns.RaidProfiles.Export(RaidOptions.Size()))
end

local function textArea(panel, readOnly, anchor, y)
    local area = Widgets.TextArea(panel, { width = CONTENT_W - 2 * INSET, height = TEXT_AREA_H, readOnly = readOnly })
    area:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -y)
    return area
end

local function createShare(body)
    local panel = CreateFrame("Frame", nil, body)
    panel:SetAllPoints(body)
    panel:SetFrameLevel(body:GetFrameLevel() + 10)
    panel:EnableMouse(true)
    Style.Fill(panel, "bg")
    local export = Widgets.Header(panel, L.EXPORT)
    export:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -PAGE_TOP)
    export:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -PAGE_TOP)
    local exportHint = Style.Text(panel, 11, "muted")
    exportHint:SetPoint("TOPLEFT", export, "BOTTOMLEFT", INSET, -4)
    local exportArea = textArea(panel, true, exportHint, 6)
    local import = Widgets.Header(panel, L.IMPORT)
    import:SetPoint("TOPLEFT", exportArea, "BOTTOMLEFT", -INSET, -SECTION_GAP)
    import:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    local importHint = Style.Text(panel, 11, "muted")
    importHint:SetPoint("TOPLEFT", import, "BOTTOMLEFT", INSET, -4)
    local importArea = textArea(panel, false, importHint, 6)
    local button = Widgets.Button(panel, { text = L.IMPORT, width = 120, onClick = runImport })
    button:SetPoint("TOPLEFT", importArea, "BOTTOMLEFT", 0, -GAP)
    local message = Style.Text(panel, 11, "muted")
    message:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -6)
    message:SetJustifyH("LEFT")
    panel:Hide()
    RaidOptions.share, RaidOptions.exportHint, RaidOptions.exportArea = panel, exportHint, exportArea
    RaidOptions.importHint, RaidOptions.importArea = importHint, importArea
    RaidOptions.importButton, RaidOptions.importMessage = button, message
end

-- Shows or hides export and import in place of the tab's page.
function RaidOptions.ShowShare(on)
    Widgets.CloseList()
    if on then
        refreshShare()
        showImportMessage("", "muted")
    end
    RaidOptions.share:SetShown(on)
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    local reset = ns.Options.ConfirmButton(footer, L.RAID_RESET_SIZE,
        function() ns.RaidProfiles.ResetSize(RaidOptions.Size()) end)
    reset:SetPoint("RIGHT", footer, "RIGHT", -12, 0)
    local copy = copyFromRow(footer)
    copy:SetPoint("RIGHT", reset, "LEFT", -GAP, 0)
    local share = Widgets.Button(footer, { text = L.RAID_SHARE, width = SHARE_BUTTON_W,
        onClick = function() RaidOptions.ShowShare(not RaidOptions.share:IsShown()) end })
    share:SetPoint("RIGHT", copy, "LEFT", -GAP, 0)
    RaidOptions.resetButton, RaidOptions.copyRow, RaidOptions.shareButton = reset, copy, share
    frame.footer = footer
    return footer
end
```

In `Raid/Options/Window.lua`:

Replace

```lua
    createNotice(body)
    createScroll(body)
    anchorScroll()
end

-- Window ------------------------------------------------------------------------
```

with

```lua
    createNotice(body)
    createScroll(body)
    anchorScroll()
    createShare(body)
end

-- Window ------------------------------------------------------------------------
```

In `Raid/Options/Window.lua`:

Replace

```lua
    local footer = createFooter(frame)
    createBody(frame, frame.sizeBar, footer)
    -- Locked in combat with the rows.
    frame.lockedControls = { RaidOptions.sizeModeRow }
    -- Hiding the window (ESC, close button, /fuf raid) takes an open
    -- dropdown list with it.
    frame:SetScript("OnHide", function() Widgets.CloseList() end)
    frame:Hide()
    for _, name in ipairs(UISpecialFrames) do
        if name == WINDOW_NAME then return end
```

with

```lua
    local footer = createFooter(frame)
    createBody(frame, frame.sizeBar, footer)
    -- Locked in combat with the rows.
    frame.lockedControls = { RaidOptions.sizeModeRow, RaidOptions.copyRow, RaidOptions.resetButton,
        RaidOptions.importButton, RaidOptions.importArea.edit }
    -- Hiding the window (ESC, close button, /fuf raid) takes an open
    -- dropdown list and armed confirmations with it.
    frame:SetScript("OnHide", function()
        Widgets.CloseList()
        RaidOptions.resetButton.Disarm()
        RaidOptions.copyRow.Disarm()
    end)
    frame:Hide()
    for _, name in ipairs(UISpecialFrames) do
        if name == WINDOW_NAME then return end
```

In `Raid/Options/Window.lua`:

Replace

```lua
    forEachRow(function(row) row:Refresh() end)
    RaidOptions.sizeModeRow:Refresh()
    renderSizeTabs()
end

-- Public API ----------------------------------------------------------------------
```

with

```lua
    forEachRow(function(row) row:Refresh() end)
    RaidOptions.sizeModeRow:Refresh()
    renderSizeTabs()
    if RaidOptions.share:IsShown() then refreshShare() end
end

-- Public API ----------------------------------------------------------------------
```

In `Raid/Options/Window.lua`:

Replace

```lua
    ensureWindow()
    for _, tab in ipairs(Schema.TABS) do
        if tab.id == id then
            Widgets.CloseList()
            if RaidOptions.page then RaidOptions.page:Hide() end
            local page = pageFor(tab)
            RaidOptions.page, RaidOptions.currentTab, RaidOptions.rows = page, id, page.rows
```

with

```lua
    ensureWindow()
    for _, tab in ipairs(Schema.TABS) do
        if tab.id == id then
            RaidOptions.ShowShare(false)
            if RaidOptions.page then RaidOptions.page:Hide() end
            local page = pageFor(tab)
            RaidOptions.page, RaidOptions.currentTab, RaidOptions.rows = page, id, page.rows
```

In `Raid/Options/Window.lua`:

Replace

```lua
    end
end

-- Edits another size's profile: the rows read it from now on.
function RaidOptions.SelectSize(size)
    ensureWindow()
    Raid.Scope(size)
    Widgets.CloseList()
    RaidOptions.size = size
    refreshAll()
end
```

with

```lua
    end
end

-- Edits another size's profile: the rows (and export) read it from now
-- on; a copy or reset armed for the size before is not.
function RaidOptions.SelectSize(size)
    ensureWindow()
    Raid.Scope(size)
    Widgets.CloseList()
    RaidOptions.resetButton.Disarm()
    RaidOptions.copyRow.Disarm()
    RaidOptions.size = size
    refreshAll()
end
```

- [ ] **Step 4: The words in English**

These lines continue R4a's block "the options window" at the end of each locale file.

Append to the end of `Locales/enUS.lua`:

```lua
L.RAID_RESET_SIZE = "Reset this size"
L.RAID_SHARE = "Export / Import"
L.RAID_COPY_CHARACTER = "%s: %s"
L.RAID_EXPORT_HINT = "Copy this text to share or back up the %s profile."
L.RAID_IMPORT_HINT = "Paste a raid size here: it replaces the %s profile."
```

- [ ] **Step 5: German**

Append to the end of `Locales/deDE.lua`:

```lua
L.RAID_RESET_SIZE = "Größe zurücksetzen"
L.RAID_SHARE = "Export / Import"
L.RAID_COPY_CHARACTER = "%s: %s"
L.RAID_EXPORT_HINT = "Diesen Text kopieren, um das Profil %s zu teilen oder zu sichern."
L.RAID_IMPORT_HINT = "Eine Schlachtzugsgröße hier einfügen: Sie ersetzt das Profil %s."
```

- [ ] **Step 6: Spanish**

Append to the end of `Locales/esES.lua`:

```lua
L.RAID_RESET_SIZE = "Restablecer tamaño"
L.RAID_SHARE = "Exportar / Importar"
L.RAID_COPY_CHARACTER = "%s: %s"
L.RAID_EXPORT_HINT = "Copia este texto para compartir o guardar el perfil de %s."
L.RAID_IMPORT_HINT = "Pega aquí un tamaño de banda: sustituye el perfil de %s."
```

- [ ] **Step 7: French**

Append to the end of `Locales/frFR.lua`:

```lua
L.RAID_RESET_SIZE = "Réinitialiser la taille"
L.RAID_SHARE = "Exporter / Importer"
L.RAID_COPY_CHARACTER = "%s : %s"
L.RAID_EXPORT_HINT = "Copiez ce texte pour partager ou sauvegarder le profil %s."
L.RAID_IMPORT_HINT = "Collez ici une taille de raid : elle remplace le profil %s."
```

- [ ] **Step 8: Run the tests**

Run: `tests/run test_raid_window_actions.lua` → `46 passed, 0 failed`
Run: `tests/run` → Expected: `23705 passed, 0 failed`

- [ ] **Step 9: Commit**

```bash
git add Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Raid/Options/Window.lua tests/test_raid_window_actions.lua
git commit -m "Raid options window: copy, reset, export and import of the edited size

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Raid test mode: the size the raid window edits, ended by closing it

**Files:**
- Modify: `Raid/TestMode.lua`
- Modify: `Raid/Cell.lua`
- Modify: `Raid/Options/Window.lua`
- Test: `tests/test_raid_window_testmode.lua`

**Interfaces:**
- Consumes: `Raid/TestMode.lua` (R2b–R3b), `ns.RaidHeader.Refresh` / `UpdateVisibility` / `Enabled`, `ns.RaidOptions` (Task 1), `ns.AfterCombat`, locale `TEST_MODE_ON`, `TEST_MODE_COMBAT`.
- Produces: `ns.RaidTestMode.Set(state)` (the raid window's switch; refused in combat → false), `IsOwnOn()`, `Preview(size or nil)`, `PreviewSize()` (the previewed size while test mode is on, else nil); internal event `RAID_TEST_MODE (state)`; `ns.RaidCell.Size()` returns the preview size while test mode is on; `ns.RaidOptions.testButton`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_window_testmode.lua`:

```lua
-- Test mode from the raid options window (Raid/TestMode.lua, Raid/Cell.lua,
-- Raid/Options/Window.lua): the pretend raid shows the size the window
-- edits, at that size's position; closing the window or entering combat
-- ends it; the unit frames' test mode stays its own.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", className = "Mage", isPlayer = true, level = 60,
    health = 100, healthMax = 100, healthMissing = 0, power = 50, powerMax = 100 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, Test, Cell, Header = ns.RaidOptions, ns.RaidConfig, ns.RaidTestMode, ns.RaidCell, ns.RaidHeader

local function click(button) button:GetScript("OnClick")(button) end
local function shown()
    local n = 0
    for _, f in ipairs(Cell.fakes) do if f:IsShown() then n = n + 1 end end
    return n
end
local function moverPoint()
    local p, _, relPoint, x, y = Header.anchor.mover:GetPoint(1)
    return table.concat({ p, relPoint, x, y }, " ")
end
local function outlined(button) return button.edges[1]._color[1] == ns.Style.COLORS.accent[1] end

-- Solo the panel shows 10; the window edits 20.
RC.Set("r20", "x", -304)
RO.Open(20)
H.check("button", RO.testButton.text:GetText(), "Test mode")
H.check("off", Test.IsOn(), false)
H.check("nothing previewed while off", Cell.Size(), 10)
click(RO.testButton)
H.checkTrue("on", Test.IsOn())
H.check("the window's switch", Test.IsOwnOn(), true)
H.check("unit frames' test mode untouched", ns.TestMode.IsOn(), false)
H.checkTrue("button outlined", outlined(RO.testButton))
H.check("the edited size", Cell.Size(), 20)
H.check("twenty pretend cells", shown(), 20)
H.check("cells of the 20 profile", Cell.fakes[1]:GetWidth(), 88)
H.check("at the 20 profile's place", moverPoint(), "TOPLEFT CENTER -304 150")
H.checkTrue("panel shown solo", Header.panel:IsShown())

-- Another size in the window: the pretend raid follows.
click(RO.sizeTabs[40])
H.check("forty", shown(), 40)
H.check("cells of the 40 profile", Cell.fakes[1]:GetWidth(), 80)
H.check("at the 40 profile's place", moverPoint(), "TOPLEFT CENTER -600 150")
RC.Set("r40", "cellWidth", 90)
H.check("an edit shows at once", Cell.fakes[1]:GetWidth(), 90)
RC.Set("r10", "cellWidth", 70)
H.check("another size's edit does not", Cell.fakes[1]:GetWidth(), 90)

-- Closing the window ends it: the real headers of the active size.
RO.Close()
H.check("closed: off", Test.IsOn(), false)
H.check("closed: switch off", Test.IsOwnOn(), false)
H.check("closed: no pretend cells", shown(), 0)
H.check("closed: active size again", Cell.Size(), 10)
H.checkTrue("closed: headers back", Header.headers[1]:IsShown())
H.check("closed: mover at the active size's place", moverPoint(), "TOPLEFT CENTER -600 150")

-- Entering combat ends it.
RO.Open(20)
click(RO.testButton)
H.check("on again", shown(), 20)
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: off", Test.IsOn(), false)
H.check("combat: no pretend cells", shown(), 0)
H.check("combat: button plain", outlined(RO.testButton), false)
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("locked in combat", RO.testButton:IsEnabled(), false)
H.check("refused in combat", Test.Set(true), false)
H.check("says why", M.chat[#M.chat]:find(ns.L.TEST_MODE_COMBAT, 1, true) ~= nil, true)
H.check("still off", Test.IsOn(), false)
M.SetCombat(false)
H.check("unlocked after combat", RO.testButton:IsEnabled(), true)

-- Lockdown had begun: the panel goes at once, the cells after combat.
click(RO.testButton)
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("lockdown: off", Test.IsOn(), false)
H.check("lockdown: panel hidden at once", Header.panel:IsShown(), false)
H.check("lockdown: cells wait", shown(), 20)
M.SetCombat(false)
H.check("after combat: cells gone", shown(), 0)

-- The unit frames' test mode with the raid window open shows the edited
-- size too; closing the window hands it back to the active size.
ns.TestMode.Set(true)
H.check("unit test mode: the edited size", shown(), 20)
H.check("the window's switch stays off", Test.IsOwnOn(), false)
RO.Close()
H.checkTrue("unit test mode stays on", ns.TestMode.IsOn())
H.check("the active size", shown(), 10)
ns.TestMode.Set(false)
H.check("all off", shown(), 0)
H.check("nothing blocked", #M.blocked, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_window_testmode.lua`

Expected:

```text
test_raid_window_testmode.lua
  ERROR test_raid_window_testmode.lua:28: attempt to index field 'testButton' (a nil value)
0 passed, 1 failed
```

- [ ] **Step 3: A switch of its own and the preview size**

In `Raid/TestMode.lua`:

Replace

```lua
local _, ns = ...

-- Test mode for the raid panel (Options/TestMode.lua fires TEST_MODE): a
-- pretend raid of the active size where the blocks are, laid out exactly
-- like the real ones (Raid/Layout.lua). The pretend cells are secure
-- buttons on the player, so clicks target you, each with a sample of its
-- own (Elements/Health.lua: Health.Sample): a class (name and colour; the
-- name is Blizzard's class name), health, a role, and one dead, one
```

with

```lua
local _, ns = ...

-- Test mode for the raid panel: a pretend raid where the blocks are,
-- laid out exactly like the real ones (Raid/Layout.lua). On with the unit
-- frames' test mode (Options/TestMode.lua fires TEST_MODE) or with the
-- raid options window's own switch (Test.Set). While the raid window is
-- open it shows the size the window edits, at that size's position
-- (Test.Preview; Raid/Cell.lua asks Test.PreviewSize); otherwise the
-- active size. The pretend cells are secure
-- buttons on the player, so clicks target you, each with a sample of its
-- own (Elements/Health.lua: Health.Sample): a class (name and colour; the
-- name is Blizzard's class name), health, a role, and one dead, one
```

In `Raid/TestMode.lua`:

Replace

```lua
    [4] = { ready = "notready" }, [5] = { ready = "waiting" },
}

local on = false

function Test.IsOn()
    return on and Header.Enabled()
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
```

with

```lua
    [4] = { ready = "notready" }, [5] = { ready = "waiting" },
}

local on = false     -- the unit frames' test mode
local own = false    -- the raid window's switch
local preview        -- the size the raid window edits, while it is open

function Test.IsOn()
    return (on or own) and Header.Enabled()
end

-- The raid window's switch is on.
function Test.IsOwnOn()
    return own
end

-- The size test mode shows instead of the active one: the raid window's,
-- while test mode is on; else nil.
function Test.PreviewSize()
    if preview and Test.IsOn() then return preview end
    return nil
end

-- The panel follows a change of test mode: the plain panel at once in
-- combat, the cells with the next layout, after combat if it had already
-- begun.
local function relayout()
    if not Header.anchor then return end
    if InCombatLockdown() then Header.UpdateVisibility() end
    ns.AfterCombat("raidLayout", Header.Refresh)
end

-- The raid window's switch (RAID_TEST_MODE tells the window). Turning it
-- on is refused in combat; off always works.
function Test.Set(state)
    state = state and true or false
    if state and InCombatLockdown() then
        ns.Print(ns.L.TEST_MODE_COMBAT)
        return false
    end
    if state == own then return true end
    own = state
    relayout()
    ns.Fire("RAID_TEST_MODE", own)
    return true
end

-- The raid window opened on a size or switched to another (nil: closed).
function Test.Preview(size)
    if size == preview then return end
    preview = size
    if Test.IsOn() then relayout() end
end

-- The pretend raid of a size: { subgroup, class, assignedRole, name,
```

In `Raid/TestMode.lua`:

Replace

```lua

ns.Listen("TEST_MODE", function(state)
    on = state and true or false
    if not Header.anchor then return end
    -- The panel is a plain frame: in combat it follows at once, the
    -- cells with the layout after combat.
    if InCombatLockdown() then Header.UpdateVisibility() end
    ns.AfterCombat("raidLayout", Header.Refresh)
end)
```

with

```lua

ns.Listen("TEST_MODE", function(state)
    on = state and true or false
    relayout()
end)

-- Entering combat ends the raid window's test mode, as the unit frames'
-- does its own.
ns.On("PLAYER_REGEN_DISABLED", function()
    if own then Test.Set(false) end
end)
```

- [ ] **Step 4: The cells show the previewed size**

In `Raid/Cell.lua`:

Replace

```lua
-- Test mode's pretend cells (Raid/TestMode.lua).
Cell.fakes = {}

-- The size whose profile the cells show; 10 until the size is known.
function Cell.Size()
    return ns.RaidSize.Current() or 10
end

-- A setting of the raid profile the cells show.
```

with

```lua
-- Test mode's pretend cells (Raid/TestMode.lua).
Cell.fakes = {}

-- The size whose profile the cells show: the active one, 10 until it is
-- known; in test mode the one the raid options window edits.
function Cell.Size()
    local test = ns.RaidTestMode
    return test and test.PreviewSize() or ns.RaidSize.Current() or 10
end

-- A setting of the raid profile the cells show.
```

- [ ] **Step 5: The window's test mode button, preview and close**

In `Raid/Options/Window.lua`:

Replace

```lua
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET, NOTE_H = 4, 16, 8, 16, 34
local BUTTON_H, DROPDOWN_W, GAP, WIDE_BUTTON_W, SHARE_BUTTON_W = 24, 160, 8, 160, 140
local TEXT_AREA_H, MESSAGE_H, CONFIRM_SECONDS = 70, 20, 3
local DEFAULT_POSITION = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 90, y = -150 }

```

with

```lua
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET, NOTE_H = 4, 16, 8, 16, 34
local BUTTON_H, BUTTON_W, DROPDOWN_W, GAP, WIDE_BUTTON_W, SHARE_BUTTON_W = 24, 120, 160, 8, 160, 140
local TEXT_AREA_H, MESSAGE_H, CONFIRM_SECONDS = 70, 20, 3
local DEFAULT_POSITION = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 90, y = -150 }

```

In `Raid/Options/Window.lua`:

Replace

```lua
    frame.scroll:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -SCROLLBAR_W, 0)
end

local function applyLock()
    local on = not inCombat
    forEachRow(function(row) row:SetEnabled(on) end)
    for _, control in ipairs(frame.lockedControls) do control:SetEnabled(on) end
    RaidOptions.combatNotice:SetShown(inCombat)
    anchorScroll()
end

-- Title bar, footer, body ---------------------------------------------------------
```

with

```lua
    frame.scroll:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -SCROLLBAR_W, 0)
end

local paintTestButton

local function applyLock()
    local on = not inCombat
    forEachRow(function(row) row:SetEnabled(on) end)
    for _, control in ipairs(frame.lockedControls) do control:SetEnabled(on) end
    RaidOptions.combatNotice:SetShown(inCombat)
    anchorScroll()
    paintTestButton()
end

-- Title bar, footer, body ---------------------------------------------------------
```

In `Raid/Options/Window.lua`:

Replace

```lua
    RaidOptions.share:SetShown(on)
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    local reset = ns.Options.ConfirmButton(footer, L.RAID_RESET_SIZE,
        function() ns.RaidProfiles.ResetSize(RaidOptions.Size()) end)
    reset:SetPoint("RIGHT", footer, "RIGHT", -12, 0)
```

with

```lua
    RaidOptions.share:SetShown(on)
end

-- Test mode's button: outlined while the window's test mode is on.
function paintTestButton()
    local button = RaidOptions.testButton
    local testOn = ns.RaidTestMode.IsOwnOn()
    Style.SetBorderColor(button, testOn and "accent" or "border")
    local idle = button:IsEnabled() and "text" or "muted"
    Style.Paint(button.text, testOn and "accent" or idle)
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    local test = Widgets.Button(footer, { text = L.TEST_MODE_ON, width = BUTTON_W,
        onClick = function() ns.RaidTestMode.Set(not ns.RaidTestMode.IsOwnOn()) end })
    test:SetPoint("LEFT", footer, "LEFT", 12, 0)
    test:HookScript("OnLeave", paintTestButton)
    RaidOptions.testButton = test
    local reset = ns.Options.ConfirmButton(footer, L.RAID_RESET_SIZE,
        function() ns.RaidProfiles.ResetSize(RaidOptions.Size()) end)
    reset:SetPoint("RIGHT", footer, "RIGHT", -12, 0)
```

In `Raid/Options/Window.lua`:

Replace

```lua
    createBody(frame, frame.sizeBar, footer)
    -- Locked in combat with the rows.
    frame.lockedControls = { RaidOptions.sizeModeRow, RaidOptions.copyRow, RaidOptions.resetButton,
        RaidOptions.importButton, RaidOptions.importArea.edit }
    -- Hiding the window (ESC, close button, /fuf raid) takes an open
    -- dropdown list and armed confirmations with it.
    frame:SetScript("OnHide", function()
        Widgets.CloseList()
        RaidOptions.resetButton.Disarm()
        RaidOptions.copyRow.Disarm()
    end)
    frame:Hide()
    for _, name in ipairs(UISpecialFrames) do
```

with

```lua
    createBody(frame, frame.sizeBar, footer)
    -- Locked in combat with the rows.
    frame.lockedControls = { RaidOptions.sizeModeRow, RaidOptions.copyRow, RaidOptions.resetButton,
        RaidOptions.importButton, RaidOptions.importArea.edit, RaidOptions.testButton }
    -- Hiding the window (ESC, close button, /fuf raid) takes an open
    -- dropdown list and armed confirmations with it, and ends its test
    -- mode: the panel shows the active size again.
    frame:SetScript("OnHide", function()
        Widgets.CloseList()
        RaidOptions.resetButton.Disarm()
        RaidOptions.copyRow.Disarm()
        ns.RaidTestMode.Set(false)
        ns.RaidTestMode.Preview(nil)
    end)
    frame:Hide()
    for _, name in ipairs(UISpecialFrames) do
```

In `Raid/Options/Window.lua`:

Replace

```lua
    RaidOptions.copyRow.Disarm()
    RaidOptions.size = size
    refreshAll()
end

function RaidOptions.Open(size, tabId)
```

with

```lua
    RaidOptions.copyRow.Disarm()
    RaidOptions.size = size
    refreshAll()
    if frame:IsShown() then ns.RaidTestMode.Preview(size) end
end

function RaidOptions.Open(size, tabId)
```

In `Raid/Options/Window.lua`:

Replace

```lua
ns.Listen("RAID_SIZE_CHANGED", function()
    if RaidOptions.IsOpen() then renderSizeTabs() end
end)

-- Every label is set once, when its widget is built: a new language gets a
-- new window (as the unit frames' window does), on the same size and tab.
```

with

```lua
ns.Listen("RAID_SIZE_CHANGED", function()
    if RaidOptions.IsOpen() then renderSizeTabs() end
end)
ns.Listen("RAID_TEST_MODE", function()
    if frame then paintTestButton() end
end)

-- Every label is set once, when its widget is built: a new language gets a
-- new window (as the unit frames' window does), on the same size and tab.
```

- [ ] **Step 6: Run the tests**

Run: `tests/run test_raid_window_testmode.lua` → `42 passed, 0 failed`
Run: `tests/run` → Expected: `23747 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add Raid/Cell.lua Raid/Options/Window.lua Raid/TestMode.lua tests/test_raid_window_testmode.lua
git commit -m "Raid test mode: the size the raid window edits, ended by closing it

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Raid options window: from the unit frames' window and back

The raid frames' own minimap button, their addon compartment entry and `Commands.ToggleRaidOptions` came with R4c; this task adds the way from the unit frames' window and back.

**Files:**
- Modify: `Options/Window.lua`
- Modify: `Raid/Options/Window.lua`
- Modify: `Locales/deDE.lua`
- Modify: `Locales/enUS.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/frFR.lua`
- Test: `tests/test_raid_window_entry.lua`

**Interfaces:**
- Consumes: `ns.RaidOptions.Open` / `Close` / `IsOpen`, `ns.Options.Open` / `Close` / `IsOpen`, the unit window's `Options.languageRow` and `Options.navButtons`, `ns.Widgets.Button`, the raid window's footer (Task 2's `testButton`, `BUTTON_W`, `GAP`).
- Produces: `ns.Options.raidButton`, `ns.RaidOptions.unitButton`; locale keys `RAID_FRAMES_BUTTON`, `UNIT_FRAMES_BUTTON`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_raid_window_entry.lua`:

```lua
-- The ways between the unit frames' options window and the raid one: a
-- button in the unit window's navigation, one in the raid window's
-- footer. (The raid frames' own minimap button and addon compartment
-- entry: tests/test_raid_minimap_button.lua.)
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local O, RO = ns.Options, ns.RaidOptions

local function click(button, mouseButton) button:GetScript("OnClick")(button, mouseButton) end

-- From the unit frames' window, above the language.
O.Open()
H.check("raid button", O.raidButton.text:GetText(), "Raid frames…")
H.check("in the navigation", O.raidButton:GetParent(), O.navButtons.general:GetParent())
local p, rel, relPoint = O.raidButton:GetPoint(1)
H.check("above the language", table.concat({ p, rel == O.languageRow and "language" or "?", relPoint }, " "),
    "BOTTOMLEFT language TOPLEFT")
click(O.raidButton)
H.check("unit window closed", O.IsOpen(), false)
H.checkTrue("raid window open", RO.IsOpen())

-- And back.
H.check("unit button", RO.unitButton.text:GetText(), "Unit frames…")
click(RO.unitButton)
H.check("raid window closed", RO.IsOpen(), false)
H.checkTrue("unit window open", O.IsOpen())
O.Close()

-- The unit frames' minimap button stays theirs: Shift does not lead to
-- the raid window (the raid frames have a button of their own).
M.shiftDown = true
click(ns.MinimapButton.button, "LeftButton")
H.checkTrue("shift-click: still the unit window", O.IsOpen())
H.check("not the raid window", RO.IsOpen(), false)
O.Close()
ForeverUnitFrames_OnAddonCompartmentClick("ForeverUnitFrames", "LeftButton")
H.checkTrue("compartment shift-click: still the unit window", O.IsOpen())
H.check("compartment: not the raid window", RO.IsOpen(), false)
O.Close()
M.shiftDown = false

-- In combat the way across works too; the raid window opens locked.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
O.Open()
click(O.raidButton)
H.checkTrue("combat: opens", RO.IsOpen())
H.checkTrue("combat: locked", RO.combatNotice:IsShown())
RO.Close()
M.SetCombat(false)
H.check("nothing blocked", #M.blocked, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_raid_window_entry.lua`

Expected:

```text
test_raid_window_entry.lua
  ERROR test_raid_window_entry.lua:16: attempt to index field 'raidButton' (a nil value)
0 passed, 1 failed
```

- [ ] **Step 3: The unit window's button**

In `Options/Window.lua`:

Replace

```lua
    return row
end

local function createNav(parent)
    local nav = CreateFrame("Frame", nil, parent)
    nav:SetWidth(NAV_W)
```

with

```lua
    return row
end

-- The raid frames have a window of their own: a button above the
-- language opens it in place of this one.
local RAID_BUTTON_GAP = 10

local function raidButton(nav)
    local button = Widgets.Button(nav, { text = L.RAID_FRAMES_BUTTON, width = NAV_W - 2 * INSET, onClick = function()
        Options.Close()
        ns.RaidOptions.Open()
    end })
    button:SetPoint("BOTTOMLEFT", Options.languageRow, "TOPLEFT", 0, RAID_BUTTON_GAP)
    Options.raidButton = button
    return button
end

local function createNav(parent)
    local nav = CreateFrame("Frame", nil, parent)
    nav:SetWidth(NAV_W)
```

In `Options/Window.lua`:

Replace

```lua
        y = y + NAV_ROW_H
    end
    languageRow(nav)
    return nav
end

```

with

```lua
        y = y + NAV_ROW_H
    end
    languageRow(nav)
    raidButton(nav)
    return nav
end

```

- [ ] **Step 4: The way back**

In `Raid/Options/Window.lua`:

Replace

```lua
        onClick = function() ns.RaidTestMode.Set(not ns.RaidTestMode.IsOwnOn()) end })
    test:SetPoint("LEFT", footer, "LEFT", 12, 0)
    test:HookScript("OnLeave", paintTestButton)
    RaidOptions.testButton = test
    local reset = ns.Options.ConfirmButton(footer, L.RAID_RESET_SIZE,
        function() ns.RaidProfiles.ResetSize(RaidOptions.Size()) end)
    reset:SetPoint("RIGHT", footer, "RIGHT", -12, 0)
```

with

```lua
        onClick = function() ns.RaidTestMode.Set(not ns.RaidTestMode.IsOwnOn()) end })
    test:SetPoint("LEFT", footer, "LEFT", 12, 0)
    test:HookScript("OnLeave", paintTestButton)
    local units = Widgets.Button(footer, { text = L.UNIT_FRAMES_BUTTON, width = BUTTON_W, onClick = function()
        RaidOptions.Close()
        ns.Options.Open()
    end })
    units:SetPoint("LEFT", test, "RIGHT", GAP, 0)
    RaidOptions.testButton, RaidOptions.unitButton = test, units
    local reset = ns.Options.ConfirmButton(footer, L.RAID_RESET_SIZE,
        function() ns.RaidProfiles.ResetSize(RaidOptions.Size()) end)
    reset:SetPoint("RIGHT", footer, "RIGHT", -12, 0)
```

- [ ] **Step 5: The words in English**

Append to the end of `Locales/enUS.lua`:

```lua

-- Raid frames: the ways between the two options windows.
L.RAID_FRAMES_BUTTON = "Raid frames…"
L.UNIT_FRAMES_BUTTON = "Unit frames…"
```

- [ ] **Step 6: German**

Append to the end of `Locales/deDE.lua`:

```lua

-- Schlachtzugsrahmen: die Wege zwischen den beiden Optionsfenstern.
L.RAID_FRAMES_BUTTON = "Schlachtzugsrahmen…"
L.UNIT_FRAMES_BUTTON = "Einheitenrahmen…"
```

- [ ] **Step 7: Spanish**

Append to the end of `Locales/esES.lua`:

```lua

-- Marcos de banda: los accesos entre las dos ventanas de opciones.
L.RAID_FRAMES_BUTTON = "Marcos de banda…"
L.UNIT_FRAMES_BUTTON = "Marcos de unidad…"
```

- [ ] **Step 8: French**

Append to the end of `Locales/frFR.lua`:

```lua

-- Cadres de raid : les accès entre les deux fenêtres d'options.
L.RAID_FRAMES_BUTTON = "Cadres de raid…"
L.UNIT_FRAMES_BUTTON = "Cadres d'unité…"
```

- [ ] **Step 9: Run the tests**

Run: `tests/run test_raid_window_entry.lua` → `15 passed, 0 failed`
Run: `tests/run` → Expected: `23780 passed, 0 failed`

- [ ] **Step 10: Commit**

```bash
git add Locales/deDE.lua Locales/enUS.lua Locales/esES.lua Locales/frFR.lua Options/Window.lua Raid/Options/Window.lua tests/test_raid_window_entry.lua
git commit -m "Raid options window: from the unit frames' window and back

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---
### Task 4: Wiki: a page per raid options tab

**Files:**
- Modify: `tools/make_wiki.lua`
- Modify: `docs/wiki/Home.md`
- Generate: `docs/wiki/Raid-Cell.md` (by `tools/make_wiki`)
- Generate: `docs/wiki/Raid-Debuffs.md` (by `tools/make_wiki`)
- Generate: `docs/wiki/Raid-General.md` (by `tools/make_wiki`)
- Generate: `docs/wiki/Raid-Icons-and-states.md` (by `tools/make_wiki`)
- Generate: `docs/wiki/Raid-Indicators.md` (by `tools/make_wiki`)
- Generate: `docs/wiki/Raid-Layout.md` (by `tools/make_wiki`)
- Generate: `docs/wiki/Raid-Texts.md` (by `tools/make_wiki`)
- Generate: `docs/wiki/_Sidebar.md` (by `tools/make_wiki`)
- Test: `tests/test_wiki_raid.lua`

**Interfaces:**
- Consumes: `ns.RaidSchema` (R4a), `ns.RaidSettings.Default`, `ns.Raid.SIZES`, the generator's `valueText`, `choices`, `cell`, `anchor`, `write`.
- Produces: `docs/wiki/Raid-General.md`, `Raid-Layout.md`, `Raid-Cell.md`, `Raid-Texts.md`, `Raid-Debuffs.md`, `Raid-Indicators.md`, `Raid-Icons-and-states.md`; the sidebar's **Raid frames** list; `WIKI_PAGES` lists the raid pages after the settings pages (so `tests/test_wiki_current.lua` checks them); `Home.md` links them.

- [ ] **Step 1: Write the failing test**

Create `tests/test_wiki_raid.lua`:

```lua
-- The wiki's raid pages (tools/make_wiki.lua): one per tab of the raid
-- options window, every raid setting on the page of its tab, the size
-- switch with the General tab, defaults per size, listed in the sidebar.
local dir = os.tmpname()
os.remove(dir)
os.execute("mkdir -p '" .. dir .. "'")
_G.WIKI_OUT = dir
local ok, err = pcall(dofile, ADDONDIR .. "/tools/make_wiki.lua")
_G.WIKI_OUT = nil
H.checkTrue("generator runs", ok, err)
local function read(name)
    local fh = io.open(dir .. "/" .. name)
    if not fh then return "" end
    local text = fh:read("*a")
    fh:close()
    return text
end

local raid = {}
for _, page in ipairs(WIKI_PAGES or {}) do
    if page[1]:match("^Raid%-") then raid[#raid + 1] = page[1] end
end
H.check("raid pages", table.concat(raid, ","),
    "Raid-General,Raid-Layout,Raid-Cell,Raid-Texts,Raid-Debuffs,Raid-Indicators,Raid-Icons-and-states")

-- Every setting on its tab's page, by its label.
local ns = H.LoadShipped()
local Schema, RS = ns.RaidSchema, ns.RaidSettings
for i, tab in ipairs(Schema.TABS) do
    local text = read(raid[i] .. ".md")
    H.checkTrue(tab.id .. ": title", text:find("# Raid frames: " .. Schema.TabTitle(tab.id), 1, true))
    for _, sec in ipairs(tab.sections) do
        H.checkTrue(tab.id .. ": section " .. sec.id, text:find("## " .. Schema.SectionTitle(sec.id), 1, true))
        for _, key in ipairs(sec.keys) do
            H.checkTrue(tab.id .. ": " .. key, text:find("<b>" .. Schema.Label(key) .. "</b>", 1, true))
        end
    end
end
local general = read("Raid-General.md")
H.checkTrue("size switch on General", general:find("<b>Raid size shown</b>", 1, true))
H.checkTrue("its choices", general:find("Automatic, 10 players, 20 players, 40 players", 1, true))
H.checkTrue("defaults per size", read("Raid-Cell.md"):find("10 players: 96; 20 players: 88; 40 players: 80", 1, true))
H.checkTrue("the cell's note", read("Raid-Cell.md"):find(ns.L.RAID_NOTE_cell, 1, true))
H.checkTrue("raid words for choices", read("Raid-Texts.md"):find("Missing health", 1, true))
H.checkTrue("the cell's own fonts", read("Raid-Texts.md"):find("<b>Second line size</b>", 1, true))
H.checkTrue("the dispel square", read("Raid-Debuffs.md"):find("Icon in the center, Square in a corner", 1, true))
H.checkTrue("the raid minimap button", general:find("<b>Show the button</b>", 1, true))

local sidebar = read("_Sidebar.md")
H.checkTrue("sidebar: raid heading", sidebar:find("**Raid frames**", 1, true))
H.checkTrue("sidebar: raid page", sidebar:find("[[Icons & states|Raid-Icons-and-states]]", 1, true))
H.checkTrue("sidebar: settings kept", sidebar:find("[[General|Settings-General]]", 1, true))
os.execute("rm -rf '" .. dir .. "'")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run test_wiki_raid.lua`

Expected:

```text
test_wiki_raid.lua
  FAIL raid pages ->  (want Raid-General,Raid-Layout,Raid-Cell,Raid-Texts,Raid-Debuffs,Raid-Indicators,Raid-Icons-and-states)
  ERROR test_wiki_raid.lua:30: attempt to concatenate field '?' (a nil value)
1 passed, 2 failed
```

- [ ] **Step 3: Raid pages in the generator**

The table head moves into `tableStart`, used by both kinds of page: the existing pages come out identical.

In `tools/make_wiki.lua`:

Replace

```lua
-- Writes the settings reference of the GitHub wiki (docs/wiki/Settings-*.md
-- and _Sidebar.md) from the same sources the options window reads: the
-- menu (Options/Schema.lua), the English labels and hints, and the
-- defaults of the addon as shipped (preset included). Home.md and FAQ.md
-- are written by hand.
--
-- Run from the repository root:  tools/make_wiki
-- (loads the addon the way the tests do: tests/mock.lua, no game needed).
```

with

```lua
-- Writes the settings reference of the GitHub wiki (docs/wiki/Settings-*.md,
-- docs/wiki/Raid-*.md and _Sidebar.md) from the same sources the options
-- windows read: the menus (Options/Schema.lua, Raid/Options/Schema.lua),
-- the English labels and hints, and the defaults of the addon as shipped
-- (preset included). Home.md and FAQ.md are written by hand.
--
-- Run from the repository root:  tools/make_wiki
-- (loads the addon the way the tests do: tests/mock.lua, no game needed).
```

In `tools/make_wiki.lua`:

Replace

```lua
local H = _G.H
local ns = H.LoadShipped()
local S, L, Schema = ns.Settings, ns.L, ns.Schema

-- WIKI_OUT (optional): another folder, e.g. for the test that checks the
-- committed pages are current.
```

with

```lua
local H = _G.H
local ns = H.LoadShipped()
local S, L, Schema = ns.Settings, ns.L, ns.Schema
local RS, RaidSchema = ns.RaidSettings, ns.RaidSchema

-- WIKI_OUT (optional): another folder, e.g. for the test that checks the
-- committed pages are current.
```

In `tools/make_wiki.lua`:

Replace

```lua

local function frameName(scope) return label("FRAME_" .. scope, scope) end

-- A value as the options window shows it.
local function valueText(def, v)
    if v == nil or v == "" then return "(none)" end
    local t = def.type
    if t == "bool" then return v and "On" or "Off" end
    if t == "enum" then return Schema.EnumText(def, v) or tostring(v) end
    if t == "color" then
        local hex = ("#%02x%02x%02x"):format(math.floor(v[1] * 255 + 0.5), math.floor(v[2] * 255 + 0.5),
            math.floor(v[3] * 255 + 0.5))
```

with

```lua

local function frameName(scope) return label("FRAME_" .. scope, scope) end

-- A value as the options window shows it; enumText (optional): the words
-- of an enum's choices, the unit frames' by default.
local function valueText(def, v, enumText)
    if v == nil or v == "" then return "(none)" end
    local t = def.type
    if t == "bool" then return v and "On" or "Off" end
    if t == "enum" then return (enumText or Schema.EnumText)(def, v) or tostring(v) end
    if t == "color" then
        local hex = ("#%02x%02x%02x"):format(math.floor(v[1] * 255 + 0.5), math.floor(v[2] * 255 + 0.5),
            math.floor(v[3] * 255 + 0.5))
```

In `tools/make_wiki.lua`:

Replace

```lua
    return tostring(v)
end

-- What can be chosen: a range, or the enum's choices.
local function choices(def)
    local t = def.type
    if t == "int" then
        local range = ("%d – %d"):format(def.min or 0, def.max or 0)
        if def.zeroText then range = range .. (" (0: %s)"):format(label(def.zeroText, "0")) end
```

with

```lua
    return tostring(v)
end

-- What can be chosen: a range, or the enum's choices. The raid's own
-- words for its choices and texts (raid = true).
local function choices(def, raid)
    local t = def.type
    local enumText = raid and RaidSchema.EnumText or Schema.EnumText
    if t == "int" then
        local range = ("%d – %d"):format(def.min or 0, def.max or 0)
        if def.zeroText then range = range .. (" (0: %s)"):format(label(def.zeroText, "0")) end
```

In `tools/make_wiki.lua`:

Replace

```lua
    end
    if t == "enum" then
        local list = {}
        for _, v in ipairs(def.values) do list[#list + 1] = Schema.EnumText(def, v) or v end
        return table.concat(list, ", ")
    end
    if t == "color" then return "Color" end
    if t == "media" then return def.mediaKind == "font" and "Font" or "Texture" end
    if t == "text" then return "Text (a spell name or ID)" end
    if t == "bool" then return "On, Off" end
    return ""
end
```

with

```lua
    end
    if t == "enum" then
        local list = {}
        for _, v in ipairs(def.values) do list[#list + 1] = enumText(def, v) or v end
        return table.concat(list, ", ")
    end
    if t == "color" then return "Color" end
    if t == "media" then return def.mediaKind == "font" and "Font" or "Texture" end
    if t == "text" then return raid and "Text" or "Text (a spell name or ID)" end
    if t == "bool" then return "On, Off" end
    return ""
end
```

In `tools/make_wiki.lua`:

Replace

```lua

local GENERATED = "<!-- Generated by tools/make_wiki from the addon's own options. Do not edit by hand. -->"

-- One table per section: option, what it does, choices, default, frames.
local function section(lines, sec, keys, scopesFor, showFrames, level)
    lines[#lines + 1] = level .. " " .. label("SECTION_" .. sec.id, sec.id)
```

with

```lua

local GENERATED = "<!-- Generated by tools/make_wiki from the addon's own options. Do not edit by hand. -->"

-- A table's start: its fixed column widths and headings, up to <tbody>.
local function tableStart(lines, columns)
    lines[#lines + 1] = "<table>"
    local head = {}
    for i, w in ipairs(WIDTHS[columns]) do
        head[#head + 1] = ('<th align="left" width="%d">%s</th>'):format(w, HEADINGS[i])
    end
    lines[#lines + 1] = "<thead><tr>" .. table.concat(head) .. "</tr></thead>"
    lines[#lines + 1] = "<tbody>"
end

-- One table per section: option, what it does, choices, default, frames.
local function section(lines, sec, keys, scopesFor, showFrames, level)
    lines[#lines + 1] = level .. " " .. label("SECTION_" .. sec.id, sec.id)
```

In `tools/make_wiki.lua`:

Replace

```lua
        lines[#lines + 1] = ("Button: **%s**."):format(label("ACTION_" .. sec.action, sec.action))
        lines[#lines + 1] = ""
    end
    local widths = WIDTHS[showFrames and 5 or 4]
    lines[#lines + 1] = "<table>"
    local head = {}
    for i, w in ipairs(widths) do head[#head + 1] = ('<th align="left" width="%d">%s</th>'):format(w, HEADINGS[i]) end
    lines[#lines + 1] = "<thead><tr>" .. table.concat(head) .. "</tr></thead>"
    lines[#lines + 1] = "<tbody>"
    for _, key in ipairs(keys) do
        local def = S.Get(key)
        local scopes = scopesFor(def)
```

with

```lua
        lines[#lines + 1] = ("Button: **%s**."):format(label("ACTION_" .. sec.action, sec.action))
        lines[#lines + 1] = ""
    end
    tableStart(lines, showFrames and 5 or 4)
    for _, key in ipairs(keys) do
        local def = S.Get(key)
        local scopes = scopesFor(def)
```

In `tools/make_wiki.lua`:

Replace

```lua
    end
end

-- Sidebar ---------------------------------------------------------------------------
do
    local lines = { GENERATED, "", "**[[Home]]**", "", "**[[FAQ]]**", "", "**Settings**", "" }
    for _, page in ipairs(pages) do lines[#lines + 1] = ("- [[%s|%s]]"):format(page[2], page[1]) end
    write("_Sidebar.md", lines)
end

WIKI_PAGES = pages
if not rawget(_G, "WIKI_OUT") then
    print(("wrote %d settings pages and the sidebar to docs/wiki/"):format(#pages))
end
```

with

```lua
    end
end

-- Raid tabs: one page per tab of the raid options window ---------------------------

-- What each raid tab is for (the page's first line).
local RAID_TAB_INTRO = {
    general = "The raid frames as a whole: on or off, the raid view in a 5-player group, Blizzard's raid frames,"
        .. " the raid frames' minimap button.",
    layout = "How the panel is made of blocks, how cells and blocks are arranged, the panel's position and borders.",
    cell = "The size of a cell, its bars and colors, its border and corners, heals and shields.",
    texts = "The name and the second line in the middle of each cell: their colors and fonts.",
    debuffs = "The most important dispellable debuff, as an icon in the centre or a square in a corner, and a"
        .. " row of further debuffs.",
    indicators = "Up to five small squares at the corners and the top edge, each for spells of your choice"
        .. " (heals over time, shields).",
    icons = "Role, raid target marker, leader, master looter and ready check icons, and the states: range,"
        .. " aggro, your target.",
}

-- The default per raid size when the sizes differ.
local function raidDefault(def)
    if def.scope == "general" then return valueText(def, RS.Default(def, "general"), RaidSchema.EnumText) end
    local groups, order = {}, {}
    for _, size in ipairs(ns.Raid.SIZES) do
        local text = valueText(def, RS.Default(def, ns.Raid.Scope(size)), RaidSchema.EnumText)
        if not groups[text] then groups[text] = {}; order[#order + 1] = text end
        table.insert(groups[text], RaidSchema.EnumText(RS.Get("sizeMode"), tostring(size)))
    end
    if #order == 1 then return order[1] end
    local parts = {}
    for _, text in ipairs(order) do parts[#parts + 1] = ("%s: %s"):format(table.concat(groups[text], ", "), text) end
    return table.concat(parts, "; ")
end

-- One table of raid settings under a heading.
local function raidSection(lines, title, keys)
    lines[#lines + 1] = "## " .. title
    lines[#lines + 1] = ""
    tableStart(lines, 4)
    for _, key in ipairs(keys) do
        local def = RS.Get(key)
        local row = { "<b>" .. cell(RaidSchema.Label(key)) .. "</b>", cell(RaidSchema.Hint(key) or ""),
            cell(choices(def, true)), cell(raidDefault(def)) }
        lines[#lines + 1] = "<tr><td>" .. table.concat(row, "</td><td>") .. "</td></tr>"
    end
    lines[#lines + 1] = "</tbody>"
    lines[#lines + 1] = "</table>"
    lines[#lines + 1] = ""
end

local raidPages = {}
for _, tab in ipairs(RaidSchema.TABS) do
    local title = RaidSchema.TabTitle(tab.id)
    local lines = { GENERATED, "", "# Raid frames: " .. title, "", RAID_TAB_INTRO[tab.id] or "", "",
        ("The **%s** tab of the raid options window (`/fuf raid`). Each raid size (10, 20, 40) has a profile of"
            .. " its own: the size tabs at the top choose which one you edit; a default that differs per size"
            .. " is listed per size."):format(title), "" }
    if tab.note then
        lines[#lines + 1] = RaidSchema.Note(tab.note)
        lines[#lines + 1] = ""
    end
    local body, names = {}, {}
    if tab.id == "general" then
        -- The size switch sits in the window's header bar.
        raidSection(body, "Header bar", RaidSchema.HEADER_KEYS)
        names[#names + 1] = "[Header bar](#header-bar)"
    end
    for _, sec in ipairs(tab.sections) do
        local name = RaidSchema.SectionTitle(sec.id)
        raidSection(body, name, sec.keys)
        names[#names + 1] = ("[%s](#%s)"):format(name, anchor(name))
    end
    lines[#lines + 1] = "**On this page:** " .. table.concat(names, " · ")
    lines[#lines + 1] = ""
    for _, l in ipairs(body) do lines[#lines + 1] = l end
    local name = "Raid-" .. title:gsub("&", "and"):gsub("%s+", "-")
    write(name .. ".md", lines)
    raidPages[#raidPages + 1] = { name, title }
end

-- Sidebar ---------------------------------------------------------------------------
do
    local lines = { GENERATED, "", "**[[Home]]**", "", "**[[FAQ]]**", "", "**Settings**", "" }
    for _, page in ipairs(pages) do lines[#lines + 1] = ("- [[%s|%s]]"):format(page[2], page[1]) end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "**Raid frames**"
    lines[#lines + 1] = ""
    for _, page in ipairs(raidPages) do lines[#lines + 1] = ("- [[%s|%s]]"):format(page[2], page[1]) end
    write("_Sidebar.md", lines)
end

local all = {}
for _, page in ipairs(pages) do all[#all + 1] = page end
for _, page in ipairs(raidPages) do all[#all + 1] = page end
WIKI_PAGES = all
if not rawget(_G, "WIKI_OUT") then
    print(("wrote %d settings pages, %d raid pages and the sidebar to docs/wiki/"):format(#pages, #raidPages))
end
```

- [ ] **Step 4: Home, by hand**

In `docs/wiki/Home.md`:

Replace

```markdown
# Forever Unit Frames

Clean, fully configurable unit frames for **WoW: Forever**: player, target, target of target, focus,
pet and party, with auras that keep updating in combat, threat, range and dispel indicators.
English, Deutsch, Español, Français.

Download: [CurseForge](https://www.curseforge.com/projects/1708698) ·
```

with

```markdown
# Forever Unit Frames

Clean, fully configurable unit frames for **WoW: Forever**: player, target, target of target, focus,
pet and party, with auras that keep updating in combat, threat, range and dispel indicators, and raid
frames for 10, 20 and 40 players.
English, Deutsch, Español, Français.

Download: [CurseForge](https://www.curseforge.com/projects/1708698) ·
```

In `docs/wiki/Home.md`:

Replace

```markdown
- **Scrolling:** the mouse wheel scrolls the page. To change a slider with the wheel, hold **Shift**.
  You can also drag a slider or type a value into the box next to it.

## Profiles

**General** > **Profile**: *Export* gives a text you can copy to share or back up your whole setup,
```

with

```markdown
- **Scrolling:** the mouse wheel scrolls the page. To change a slider with the wheel, hold **Shift**.
  You can also drag a slider or type a value into the box next to it.

## Raid frames

- **`/fuf raid`** opens the raid options window (also: the **Raid frames…** button in `/fuf`, the raid
  frames' own minimap button, or their entry in the addon compartment).
- Each character has **three raid profiles**, one per raid size: 10, 20 and 40. The size tabs at the
  top of the window choose the profile you edit; the one shown right now is marked *(shown)*.
  **Raid size shown** next to them follows the raid instance (outside one the group's size), or fixes
  one size.
- **Test mode** in the raid window shows a pretend raid of the size you edit, at that size's place,
  with every option you switched on; closing the window or entering combat ends it.
- **Copy from…** takes another size, or a size of another of your characters (two clicks).
  **Export / Import** shares one size as a text; **Reset this size** goes back to its defaults.
- Corner indicators take spell IDs or spell names from your spell book; a name stands for every rank
  you know. A name or class the window cannot use is named in the chat.
- The cells have a look of their own per raid size (texture, colors, fonts, border): changing the party
  frame does not change them.

## Profiles

**General** > **Profile**: *Export* gives a text you can copy to share or back up your whole setup,
```

In `docs/wiki/Home.md`:

Replace

```markdown
| Command | What it does |
|---|---|
| `/fuf` | Opens the options |
| `/fuf unlock`, `/fuf lock` | Lets you drag the frames, and locks them again |
| `/fuf status` | Prints the client version and where the settings came from |
| `/fuf reset <frame\|all>` | Resets one frame (player, target, targettarget, pet, focus, party) or everything |
```

with

```markdown
| Command | What it does |
|---|---|
| `/fuf` | Opens the options |
| `/fuf raid` | Opens the raid frames' options |
| `/fuf unlock`, `/fuf lock` | Lets you drag the frames, and locks them again |
| `/fuf status` | Prints the client version and where the settings came from |
| `/fuf reset <frame\|all>` | Resets one frame (player, target, targettarget, pet, focus, party) or everything |
```

In `docs/wiki/Home.md`:

Replace

```markdown
  highlights, range and out-of-combat fading
- [[Castbar|Settings-Castbar]] – castbars and the threat bar

Questions that come up often: [[FAQ]].

## Feedback
```

with

```markdown
  highlights, range and out-of-combat fading
- [[Castbar|Settings-Castbar]] – castbars and the threat bar

The raid frames have pages of their own, one per tab of the raid window:

- [[General|Raid-General]] – raid frames on or off, the raid view in a party, Blizzard's raid frames,
  the raid size shown, the raid minimap button
- [[Layout|Raid-Layout]] – grouping, sorting, class order, how blocks and cells are arranged, position,
  borders
- [[Cell|Raid-Cell]] – cell size, bar texture and colors, power strip, border and corners, heals and
  shields
- [[Texts|Raid-Texts]] – the name and the second line, their colors and fonts
- [[Debuffs|Raid-Debuffs]] – the dispellable debuff in the centre or as a square in a corner, the debuff
  row
- [[Indicators|Raid-Indicators]] – the five corner indicators
- [[Icons & states|Raid-Icons-and-states]] – role, raid marker, leader, master looter, ready check,
  range, aggro, your target

Questions that come up often: [[FAQ]].

## Feedback
```

- [ ] **Step 5: Generate the wiki pages**

Run: `tools/make_wiki`
Expected: `wrote 8 settings pages, 7 raid pages and the sidebar to docs/wiki/`

It writes `docs/wiki/Raid-Cell.md`, `docs/wiki/Raid-Debuffs.md`, `docs/wiki/Raid-General.md`, `docs/wiki/Raid-Icons-and-states.md`, `docs/wiki/Raid-Indicators.md`, `docs/wiki/Raid-Layout.md`, `docs/wiki/Raid-Texts.md`, `docs/wiki/_Sidebar.md` (and rewrites the unchanged `Settings-*.md` pages identically).

- [ ] **Step 6: Run the tests**

Run: `tests/run test_wiki_raid.lua` → `142 passed, 0 failed`
Run: `tests/run` → Expected: `23929 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add docs/wiki/Home.md docs/wiki/Raid-Cell.md docs/wiki/Raid-Debuffs.md docs/wiki/Raid-General.md docs/wiki/Raid-Icons-and-states.md docs/wiki/Raid-Indicators.md docs/wiki/Raid-Layout.md docs/wiki/Raid-Texts.md docs/wiki/_Sidebar.md tests/test_wiki_raid.lua tools/make_wiki.lua
git commit -m "Wiki: a page per raid options tab

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Version 0.22.0: raid frames in the CurseForge description

No test: text only. Do not run `tools/release` or `tools/publish_wiki`.

**Files:**
- Modify: `ForeverUnitFrames.toc`
- Modify: `docs/curseforge/description.md`

**Interfaces:**
- Consumes: —
- Produces: `## Version: 0.22.0`; a **Raid frames** section, the summary and the commands of `docs/curseforge/description.md` (English).

- [ ] **Step 1: The version**

In `ForeverUnitFrames.toc`:

Replace

```text
## Title: Forever Unit Frames
## Notes: Clean, flat and fully configurable unit frames for WoW: Forever.
## Author: StephanRosin
## Version: 0.21.0
## IconTexture: Interface\AddOns\ForeverUnitFrames\Media\MinimapIcon.tga
## AddonCompartmentFunc: ForeverUnitFrames_OnAddonCompartmentClick
## AddonCompartmentFuncOnEnter: ForeverUnitFrames_OnAddonCompartmentEnter
```

with

```text
## Title: Forever Unit Frames
## Notes: Clean, flat and fully configurable unit frames for WoW: Forever.
## Author: StephanRosin
## Version: 0.22.0
## IconTexture: Interface\AddOns\ForeverUnitFrames\Media\MinimapIcon.tga
## AddonCompartmentFunc: ForeverUnitFrames_OnAddonCompartmentClick
## AddonCompartmentFuncOnEnter: ForeverUnitFrames_OnAddonCompartmentEnter
```

- [ ] **Step 2: The description**

In `docs/curseforge/description.md`:

Replace

```markdown
**Summary**

Clean, fully configurable unit frames for WoW: Forever. Player, target, target of target, focus, pet and party, with auras that update in combat, threat, range and dispel indicators. English, Deutsch, Español, Français.

---

```

with

```markdown
**Summary**

Clean, fully configurable unit frames for WoW: Forever. Player, target, target of target, focus, pet and party, with auras that update in combat, threat, range and dispel indicators, and raid frames for 10, 20 and 40 players. English, Deutsch, Español, Français.

---

```

In `docs/curseforge/description.md`:

Replace

```markdown
- Damage and heal numbers on the frame (combat feedback).
- Combat and resting icons on the player frame, with Blizzard's own art: crossed swords while you are in combat, the animated "Zzz" while you rest in an inn or a city. Centred on the health bar by default, side by side when both show. Each can be turned off; size, anchor point on the health bar and X/Y offset are configurable.
- 2D or 3D portraits, for players and creatures.

## Status
In a "Status" tab per frame.
```

with

```markdown
- Damage and heal numbers on the frame (combat feedback).
- Combat and resting icons on the player frame, with Blizzard's own art: crossed swords while you are in combat, the animated "Zzz" while you rest in an inn or a city. Centred on the health bar by default, side by side when both show. Each can be turned off; size, anchor point on the health bar and X/Y offset are configurable.
- 2D or 3D portraits, for players and creatures.

## Raid frames
- Raid frames for 10, 20 and 40 players in the look of the unit frames: a panel of blocks (raid groups, classes, roles, or one block for everyone), side by side or stacked, wrapping after a number of your choice, with a gold border around the panel (borders around each block and each cell can be switched on).
- Three profiles per character, one per raid size. The size follows the raid instance (outside one, the size of the group), or is fixed. Copy a size from another size or from another of your characters, reset it, or export and import one size as a text.
- Cells with a look of their own per raid size, independent of the party frame: bar texture, background, font, name and second-line sizes, outline and shadow, the colours of the name and the second line, a border in its own style, thickness and colour, rounded corners.
- Health in the class colour, a fixed colour or a gradient; name and missing health (or percent, or current health) in the middle; Dead, Ghost, Offline and AFK in place of the number; a thin power strip for everyone, mana users or healers; incoming heals, an overheal lane, shields and damage and heal numbers, each switched on or off.
- The most important debuff you can dispel (or any dispellable debuff) as an icon in the centre, bordered in its type's colour, or as a small square in a corner (from a single pixel) in that colour, beside a corner indicator in the same corner; the whole cell can take that colour, and a row of further debuffs can be switched on.
- Up to five corner indicators for spells of your choice (heals over time, shields): spell IDs, or spell names from your spell book (a name stands for every rank you know; a name it does not know is named in the chat). Each with its colour, size, your own casts only, and the time left as a darkening or a number. The game's aura containers fill them, so they keep updating in combat.
- Icons for the role, the raid target marker, the leader and assistants, the master looter and the ready check, each at a point of your choice. Members out of range fade; a red line inside the cell shows aggro, a light one your target.
- Within a block: raid order, name or role; class blocks in an order of your choice.
- A 5-player group can be shown as a raid as well; Blizzard's raid frames hide while ours are on.
- `/fuf raid` opens the raid options window; so do a button in `/fuf`, the raid frames' own minimap button (drag it, or hide it) and their entry in Blizzard's addon compartment. Its test mode shows a pretend raid of the size you edit, at that size's place: mixed classes and roles, one member dead, one offline, one out of range, debuffs and indicators.

## Status
In a "Status" tab per frame.
```

In `docs/curseforge/description.md`:

Replace

```markdown
- General > Frames: every frame with an on/off switch in one list.
- Works with click-casting addons such as Clique: every unit frame registers itself through the common ClickCastFrames table.
- Long option descriptions show in full in a tooltip when you hover the row.
- A minimap button: left-click opens the options, right-click unlocks or locks the frames, drag it around the minimap (round or square). It can be hidden; with a LibDataBroker display it also appears there, and it is listed in Blizzard's addon compartment.
- Every position can be set by dragging (`/fuf unlock`) or as exact X/Y values.
- Test mode shows every enabled indicator on every frame: sample auras, casts, totems, the combat, resting and PvP icons, raid markers, the group and ready check icons, a threat glow on the player, and a full party with one member dead, one offline, one out of range, a threat glow and a dispel highlight, so you can set everything up without a group.
- Settings are stored compactly. They can be exported and imported as a string. Importing a profile keeps your own language.

## Commands
`/fuf` (options), `/fuf unlock`, `/fuf lock`, `/fuf status`, `/fuf reset <frame|all>`, `/fuf set <scope> <setting> <value>`

## Notes
- Made for WoW: Forever only. It relies on Forever's API and will not load on other clients.
```

with

```markdown
- General > Frames: every frame with an on/off switch in one list.
- Works with click-casting addons such as Clique: every unit frame registers itself through the common ClickCastFrames table.
- Long option descriptions show in full in a tooltip when you hover the row.
- A minimap button: left-click opens the options, right-click unlocks or locks the frames, drag it around the minimap (round or square). It can be hidden; with a LibDataBroker display it also appears there, and it is listed in Blizzard's addon compartment.
- Every position can be set by dragging (`/fuf unlock`) or as exact X/Y values.
- Test mode shows every enabled indicator on every frame: sample auras, casts, totems, the combat, resting and PvP icons, raid markers, the group and ready check icons, a threat glow on the player, and a full party with one member dead, one offline, one out of range, a threat glow and a dispel highlight, so you can set everything up without a group.
- Settings are stored compactly. They can be exported and imported as a string. Importing a profile keeps your own language.

## Commands
`/fuf` (options), `/fuf raid` (raid frames' options), `/fuf unlock`, `/fuf lock`, `/fuf status`, `/fuf reset <frame|all>`, `/fuf set <scope> <setting> <value>`

## Notes
- Made for WoW: Forever only. It relies on Forever's API and will not load on other clients.
```

- [ ] **Step 3: Run the tests**

Run: `tests/run` → Expected: `23929 passed, 0 failed`

- [ ] **Step 4: Commit**

```bash
git add ForeverUnitFrames.toc docs/curseforge/description.md
git commit -m "Version 0.22.0: raid frames in the CurseForge description

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## After the last task

- `./install "<AddOns folder of _classic_beta_>"`, then `/reload`. No Lua error at login. UI only: no moving, casting or fighting.
- Ways in: `/fuf raid`; `/fuf` → *Raid frames…* (the unit window closes); the raid frames' minimap button and their addon compartment entry (R4c); *Unit frames…* leads back. Shift-click on the unit frames' minimap button still opens the unit window.
- Test mode in the raid window, solo: a pretend raid of the edited size where that size's panel sits; switch between 10, 20 and 40 — the pretend raid follows; drag it with `/fuf unlock` and check that only the edited size's position changed (Layout tab, Position); close the window: the pretend raid goes, the unit frames' test mode (if on) stays. Ending by combat is covered by the offline tests (no fighting in game).
- Copy from: another size (first click arms, red "Click again to confirm", second copies); a second character with a raid profile appears as "Name-Realm: 20 players" (log in with it once first).
- Export / Import: export 20, import the text on 40, the message says "Profile imported."; paste a unit-frame profile text: "This text holds no raid size."
- Performance at 40 (spec §9) with test mode from the raid window and every indicator on; the aggro line (R3b) in a real raid when available — if it never shows, a follow-up drops `aggroBorder` and the wiki says why.
- Wiki: the pages under `docs/wiki/Raid-*.md` read well on GitHub (tables, anchors) — `tools/publish_wiki` publishes them with the release.
- Then the maintainer releases 0.22.0 (`tools/release`, not part of this plan).
