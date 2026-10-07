-- The raid window's Arrangement tab (Raid/Options/Arrangement.lua): its
-- note, then a section per own panel shown at the edited size with that
-- panel's settings (title, grouping, layout, position); sections come and
-- go with their panels, the page's height follows.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, L = ns.RaidOptions, ns.RaidConfig, ns.L

local function click(button) button:GetScript("OnClick")(button) end
local function rowFor(key)
    for _, row in ipairs(RO.rows) do if row.key == key then return row end end
end
local function shownKeys()
    local list = {}
    for _, row in ipairs(RO.rows) do if row.key and row:IsShown() then list[#list + 1] = row.key end end
    return table.concat(list, ",")
end
local function enter(row, text)
    M.Type(row.edit, text)
    M.PressEnter(row.edit)
end
local function top(row) return -select(5, row:GetPoint(1)) end

RO.Open(10, "arrangement")
H.check("the tab", RO.currentTab, "arrangement")
H.check("its note", RO.page.note:GetText(), L.RAID_NOTE_arrangement)
H.check("no own panel: no rows", shownKeys(), "")
local empty = RO.page.height

-- A panel shown at 10: its section, its settings but those on the board.
RC.Set("r10", "panel3Show", true)
H.check("panel 3's rows", shownKeys(), "panel3GroupBy,panel3Title,panel3BlockDirection,panel3BlocksPerLine,"
    .. "panel3CellGrowth,panel3CellsPerLine,panel3BlockTitles,panel3HideEmpty,panel3PanelBorder,panel3BlockBorder,"
    .. "panel3X,panel3Y")
local title = rowFor("panel3Title")
H.check("labels: the own words", title.label:GetText(), "Title")
H.check("the main panel's words", rowFor("panel3CellsPerLine").label:GetText(), "Cells per line")
H.checkTrue("the page grew", RO.page.height > empty)
H.check("the scroll range follows", RO.frame.scrollChild:GetHeight(), RO.page.height)
H.checkTrue("x: - and + buttons", rowFor("panel3X").minus and rowFor("panel3X").plus)
H.check("x: its spot", rowFor("panel3X").edit:GetText(), "360")

-- The rows set the edited size.
enter(rowFor("panel3CellsPerLine"), "3")
H.check("cells per line set", RC.Get("r10", "panel3CellsPerLine"), 3)
H.check("20 untouched", RC.Get("r20", "panel3CellsPerLine"), 5)
enter(title, "Healers")
H.check("title set", RC.Get("r10", "panel3Title"), "Healers")

-- A new grouping starts without blocks.
RC.Set("r10", "panel3Blocks", "1")
click(rowFor("panel3GroupBy").button)
local list = ns.Widgets.list
H.check("three groupings", #list.items, 3)
click(list.rows[3])
H.check("by role", RC.Get("r10", "panel3GroupBy"), "ROLE")
H.check("its blocks cleared", RC.Get("r10", "panel3Blocks"), "")

-- Two panels: in slot order, a section each.
RC.Set("r10", "panel2Show", true)
H.check("panel 2 first", shownKeys():sub(1, 13), "panel2GroupBy")
H.checkTrue("panel 3 below", top(rowFor("panel3Title")) > top(rowFor("panel2Y")))

-- Another size: its own panels (none).
RO.SelectSize(20)
H.check("20: no rows", shownKeys(), "")
H.check("20: the page back", RO.page.height, empty)
RO.SelectSize(10)
H.check("10 again", rowFor("panel3CellsPerLine").edit:GetText(), "3")

-- Combat: the rows lock.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("locked", rowFor("panel3CellsPerLine").edit._enabled, false)
M.SetCombat(false)
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("unlocked", rowFor("panel3CellsPerLine").edit._enabled, true)
H.check("no error", #M.errors, 0)
