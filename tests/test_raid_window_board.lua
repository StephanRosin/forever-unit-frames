-- The Arrangement tab's board (Raid/Options/Arrangement.lua): a column
-- per panel of the edited size (the main panel, then each own panel) with
-- its blocks as chips. A chip is dragged onto another column of its
-- grouping, or clicked for a menu (Move to …, Take out); an own panel's
-- column adds a block of its grouping and removes the panel; the board
-- adds panels, up to nine. Locked in combat.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, L, Arrangement = ns.RaidOptions, ns.RaidConfig, ns.L, ns.RaidArrangement

local function click(button) button:GetScript("OnClick")(button) end
local function shownColumns()
    local list = {}
    for _, column in ipairs(Arrangement.board.columns) do
        if column:IsShown() then list[#list + 1] = column end
    end
    return list
end
local function chipTexts(column)
    local list = {}
    for _, chip in ipairs(column.chips) do
        if chip:IsShown() then list[#list + 1] = chip.button.text:GetText() end
    end
    return table.concat(list, ",")
end
local function board()
    local parts = {}
    for _, column in ipairs(shownColumns()) do
        parts[#parts + 1] = column.name:GetText() .. "[" .. chipTexts(column) .. "]"
    end
    return table.concat(parts, " ")
end
local function listTexts()
    local list = {}
    for _, item in ipairs(ns.Widgets.list.items) do list[#list + 1] = item.text end
    return table.concat(list, ",")
end
local function pick(text)
    for i, item in ipairs(ns.Widgets.list.items) do
        if item.text == text then return click(ns.Widgets.list.rows[i]) end
    end
    error("no item " .. text)
end
-- A drag from a chip to a column (nil: let go over nothing), the cursor
-- over the window's scroll area unless outside is set.
local function startDrag(chip) chip.button:GetScript("OnDragStart")(chip.button) end
local function stopDrag(chip, column, outside)
    if column then column._mouseOver = true end
    RO.frame.scroll._mouseOver = not outside
    chip.button:GetScript("OnDragStop")(chip.button)
    if column then column._mouseOver = false end
    RO.frame.scroll._mouseOver = false
end
local function drag(chip, column, outside)
    startDrag(chip)
    stopDrag(chip, column, outside)
end
local function chip(column, text)
    for _, c in ipairs(column.chips) do
        if c:IsShown() and c.button.text:GetText() == text then return c end
    end
end

RO.Open(10, "arrangement")
local b = Arrangement.board
H.check("the main panel alone", board(), "Main panel[Group 1,Group 2]")
H.check("its grouping", shownColumns()[1].grouping:GetText(), "Group by: Group")
-- The grouping line: one line across the column.
local function points(region)
    local list = {}
    for i = 1, 2 do
        local p, _, relPoint = region:GetPoint(i)
        list[i] = table.concat({ tostring(p), tostring(relPoint) }, " ")
    end
    return table.concat(list, ", ")
end
H.check("grouping line: across", points(shownColumns()[1].grouping), "TOPLEFT BOTTOMLEFT, TOPRIGHT BOTTOMRIGHT")
H.check("grouping line: one line", shownColumns()[1].grouping:GetWordWrap(), false)
H.checkTrue("chips drag", shownColumns()[1].chips[1].button._drag)
H.check("add panel", b.addButton.text:GetText(), L.RAID_ADD_PANEL)

-- Adding a panel: an empty column, its section below.
click(b.addButton)
H.check("panel 2 shown at 10", RC.Get("r10", "panel2Show"), true)
H.check("two columns", board(), "Main panel[Group 1,Group 2] Panel 2[]")
local main, own = shownColumns()[1], shownColumns()[2]
H.checkTrue("side by side", select(4, own:GetPoint(1)) > select(4, main:GetPoint(1)))
H.check("the same height", own:GetHeight(), main:GetHeight())
H.checkTrue("its section", (function()
    for _, row in ipairs(RO.rows) do if row.key == "panel2Title" then return row:IsShown() end end
end)())

-- A chip's menu: move to the other panel of its grouping.
click(chip(main, "Group 2").button)
H.check("the menu", listTexts(), "Move to Panel 2")
pick("Move to Panel 2")
H.check("moved", RC.Get("r10", "panel2Blocks"), "2")
H.check("the board follows", board(), "Main panel[Group 1] Panel 2[Group 2]")

-- Drag and drop: onto another column of its grouping.
-- A drag shows on the dragged chip's border.
local dragged = chip(main, "Group 1")
startDrag(dragged)
H.check("dragging: its border lit", dragged.button.edges[1]._color[1], ns.Style.COLORS.accent[1])
-- Let go over the column but outside the scroll area (the column scrolled
-- out of view): nothing.
stopDrag(dragged, own, true)
H.check("outside the scroll area: nothing", RC.Get("r10", "panel2Blocks"), "2")
drag(chip(main, "Group 1"), own)
H.check("dropped", RC.Get("r10", "panel2Blocks"), "2,1")
H.check("the main panel empty, its blocks in group order", board(), "Main panel[] Panel 2[Group 1,Group 2]")
drag(chip(own, "Group 1"), own)
H.check("onto its own column: nothing", RC.Get("r10", "panel2Blocks"), "2,1")
drag(chip(own, "Group 1"), nil)
H.check("onto nothing: nothing", RC.Get("r10", "panel2Blocks"), "2,1")
dragged = chip(own, "Group 1")
drag(dragged, main)
H.check("back to the main panel", board(), "Main panel[Group 1] Panel 2[Group 2]")
H.check("the dragged chip's border back", dragged.button.edges[1]._color[1], ns.Style.COLORS.border[1])
-- A column that is not visible (its page hidden) takes nothing.
b:Hide()
drag(chip(main, "Group 1"), own)
b:Show()
H.check("not visible: nothing", RC.Get("r10", "panel2Blocks"), "2")

-- A change while a chip's menu is open closes the menu (its chip may now
-- stand for another block).
click(chip(main, "Group 1").button)
H.checkTrue("menu open", ns.Widgets.list:IsShown())
RC.Set("r10", "panel2Title", "X")
H.check("a change closes it", ns.Widgets.list:IsShown(), false)
RC.Set("r10", "panel2Title", "")

-- A render leaves the buttons' looks alone: an armed remove stays armed
-- and red, a hovered add stays lit.
click(own.remove)
b.addButton:GetScript("OnEnter")(b.addButton)
RC.Set("r10", "panel2Title", "Y")
H.check("still armed", own.remove.text:GetText(), L.RAID_REMOVE_CONFIRM)
local function rgb(c) return table.concat({ c[1], c[2], c[3] }, ",") end
H.check("still red", rgb(own.remove.text._color), rgb(ns.Style.COLORS.error))
H.check("still lit", rgb(b.addButton.text._color), rgb(ns.Style.COLORS.accent))
b.addButton:GetScript("OnLeave")(b.addButton)
own.remove.Disarm()
RC.Set("r10", "panel2Title", "")

-- Another grouping: its blocks come from the add menu; taken out, gone.
ns.RaidOwnPanels.SetGrouping(10, ns.Raid.OwnPanel("panel2"), "ROLE")
H.check("a role panel", board(), "Main panel[Group 1,Group 2] Panel 2[]")
H.check("its grouping", own.grouping:GetText(), "Group by: Role")
click(own.addBlock.button)
H.check("the roles to add", listTexts(), "Tank,Healer,Damage")
pick("Healer")
H.check("healers added", RC.Get("r10", "panel2Blocks"), "HEALER")
H.check("shown again, not moved", board(), "Main panel[Group 1,Group 2] Panel 2[Healer]")
click(own.addBlock.button)
H.check("the rest to add", listTexts(), "Tank,Damage")
ns.Widgets.CloseList()
drag(chip(main, "Group 1"), own)
H.check("another grouping: no drop", RC.Get("r10", "panel2Blocks"), "HEALER")
click(chip(own, "Healer").button)
H.check("nowhere to move: take out", listTexts(), L.RAID_TAKE_OUT)
pick(L.RAID_TAKE_OUT)
H.check("taken out", board(), "Main panel[Group 1,Group 2] Panel 2[]")
click(chip(main, "Group 1").button)
H.check("no panel to move to", listTexts(), L.RAID_NOWHERE)
pick(L.RAID_NOWHERE)
H.check("nothing moved", board(), "Main panel[Group 1,Group 2] Panel 2[]")

-- A title names the column.
RC.Set("r10", "panel2Title", "Healers")
H.check("named by its title", own.name:GetText(), "Healers")

-- Removing: two clicks.
click(own.remove)
H.check("armed only", RC.Get("r10", "panel2Show"), true)
click(own.remove)
H.check("removed", RC.Get("r10", "panel2Show"), false)
H.check("its title gone", RC.Get("r10", "panel2Title"), "")
H.check("one column again", board(), "Main panel[Group 1,Group 2]")

-- Up to nine own panels, five columns to a row.
for _ = 1, 9 do click(b.addButton) end
H.check("ten columns", #shownColumns(), 10)
H.check("no more", b.addButton:IsEnabled(), false)
local sixth = shownColumns()[6]
H.check("the sixth under the first", select(4, sixth:GetPoint(1)), select(4, main:GetPoint(1)))
H.checkTrue("in a second row", select(5, sixth:GetPoint(1)) < select(5, main:GetPoint(1)))
H.check("the board's height", b:GetHeight() > 2 * main:GetHeight(), true)

-- Another size: its own board.
RO.SelectSize(40)
H.check("40: the main panel alone", board(), "Main panel[Group 1,Group 2,Group 3,Group 4,Group 5,Group 6,Group 7,Group 8]")
H.checkTrue("40: add panel", b.addButton:IsEnabled())
RO.SelectSize(10)

-- Combat: everything locks; a drag does nothing.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("add locked", b.addButton:IsEnabled(), false)
local first = shownColumns()[2]
H.check("a chip locked", main.chips[1].button:IsEnabled(), false)
H.check("add block locked", first.addBlock.button:IsEnabled(), false)
H.check("remove locked", first.remove:IsEnabled(), false)
drag(main.chips[1], first)
H.check("combat: no drop", RC.Get("r10", "panel2Blocks"), "")
M.SetCombat(false)
M.FireEvent("PLAYER_REGEN_ENABLED")
-- A drag under way when combat starts is dropped nowhere.
startDrag(main.chips[1])
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
stopDrag(main.chips[1], first)
H.check("combat came: no drop", RC.Get("r10", "panel2Blocks"), "")
H.check("combat came: the border back", main.chips[1].button.edges[1]._color[1], ns.Style.COLORS.border[1])
M.SetCombat(false)
M.FireEvent("PLAYER_REGEN_ENABLED")
H.checkTrue("a chip unlocked", main.chips[1].button:IsEnabled())
H.check("still full", b.addButton:IsEnabled(), false)
H.check("no error", #M.errors, 0)

-- Every word of the board in every language, fitting its place (mock:
-- half the font size per character): menu items in a chip's list, the
-- buttons' words on the buttons.
local function width(text, size)
    local fs = M.newWidget("FontString")
    fs:SetFont("x", size, "")
    fs:SetText(text)
    return fs:GetStringWidth()
end
-- A chip's list is the chip's width (its button covers it, SetAllPoints); a
-- list row sits 1 and 4 inside it, its text 8 inside the row on each side.
local chipWidth = main.chips[1]:GetWidth()
local listTextWidth = chipWidth - 1 - 4 - 2 * 8
local removeWidth = shownColumns()[2].remove:GetWidth()
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    local words = ns.Locales[code]
    for _, key in ipairs({ "RAID_MAIN_PANEL", "RAID_ADD_PANEL", "RAID_REMOVE_PANEL", "RAID_ADD_BLOCK", "RAID_MOVE_TO",
        "RAID_TAKE_OUT", "RAID_NOWHERE", "RAID_NONE_LEFT", "RAID_BOARD_HINT", "RAID_OWN_PANEL", "RAID_REMOVE_CONFIRM",
        "RAID_GROUPING_LINE" }) do
        H.checkTrue(code .. " has " .. key, type(words[key]) == "string")
    end
    local panel10 = words.RAID_OWN_PANEL:format(10)
    for _, text in ipairs({ words.RAID_MOVE_TO:format(panel10), words.RAID_MOVE_TO:format(words.RAID_MAIN_PANEL),
        words.RAID_TAKE_OUT, words.RAID_NOWHERE, words.RAID_NONE_LEFT, words.RAID_ADD_BLOCK, words.RAID_REMOVE_PANEL }) do
        H.checkTrue(code .. " fits a chip's list: " .. text, width(text, 12) <= listTextWidth)
    end
    H.checkTrue(code .. " fits its button: add panel", width(words.RAID_ADD_PANEL, 12) <= b.addButton:GetWidth() - 16)
    for _, key in ipairs({ "RAID_REMOVE_PANEL", "RAID_REMOVE_CONFIRM" }) do
        H.checkTrue(code .. " fits its button: " .. key, width(words[key], 12) <= removeWidth - 16)
    end
end

-- A new language: the board in its words.
ns.Config.Set("general", "language", "deDE")
H.check("German board", shownColumns()[1].name:GetText(), "Hauptfeld")
ns.Config.Set("general", "language", "frFR")
H.checkTrue("French grouping line", shownColumns()[1].grouping:GetText():find(" : ", 1, true) ~= nil)
ns.Config.Set("general", "language", "AUTO")
H.check("no error after the language changes", #M.errors, 0)
