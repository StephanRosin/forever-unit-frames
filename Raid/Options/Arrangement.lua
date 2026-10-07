local _, ns = ...

-- The raid window's Arrangement tab (Raid/Options/Window.lua builds the
-- window; Raid/OwnPanels.lua does the arranging): for the edited size the
-- tab's note, the board of panels and their blocks, then a section per
-- own panel shown at that size with its settings (its title, grouping,
-- layout and position; its blocks are on the board). A section comes
-- and goes with its panel: the page lays its rows out again whenever the
-- board refreshes, which every refresh of the window's rows does.
local Arrangement = {}
ns.RaidArrangement = Arrangement

local Widgets, Schema, Raid, Own = ns.Widgets, ns.RaidSchema, ns.Raid, ns.RaidOwnPanels
local RaidOptions, RaidConfig = ns.RaidOptions, ns.RaidConfig

-- The settings the board holds rather than a row.
local ON_THE_BOARD = { Show = true, Blocks = true }

local function editedSize() return RaidOptions.Size() end

local function shownAtEditedSize(slot)
    return RaidConfig.Get(Raid.Scope(editedSize()), slot.id .. "Show") == true
end

-- A row of a slot: its grouping goes through Own.SetGrouping (a new
-- grouping starts without blocks).
local function slotRow(page, slot, part)
    local key = slot.id .. part
    if part ~= "GroupBy" then return RaidOptions.SettingRow(page, key) end
    return RaidOptions.SettingRow(page, key, function(groupBy)
        Own.SetGrouping(editedSize(), slot, groupBy)
        return true
    end)
end

-- Every item of the page in its order: { row, visible() (optional) }.
local function items(page, tab)
    local list = { { row = RaidOptions.NoteBlock(page, Schema.Note(tab.note)) } }
    list[1].row:SetHeight(RaidOptions.PAGE.noteHeight)
    for _, slot in ipairs(Raid.OWN_PANELS) do
        local function visible() return shownAtEditedSize(slot) end
        local header = Widgets.Header(page, Schema.SectionTitle(slot.id))
        header.isSection = true
        list[#list + 1] = { row = header, visible = visible }
        for _, entry in ipairs(Raid.OWN_PANEL_PARTS) do
            if not ON_THE_BOARD[entry.part] then
                list[#list + 1] = { row = slotRow(page, slot, entry.part), visible = visible }
            end
        end
    end
    return list
end

-- The visible items one below the other, a gap before each section after
-- the first item; the page's height follows.
local function restack(page)
    local P = RaidOptions.PAGE
    local y = P.top
    for i, item in ipairs(page.items) do
        local on = item.visible == nil or item.visible()
        item.row:SetShown(on)
        if on then
            if item.row.isSection and i > 1 then y = y + P.sectionGap end
            item.row:ClearAllPoints()
            item.row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
            item.row:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -y)
            y = y + item.row:GetHeight()
        end
    end
    page.height = y + P.bottom
    RaidOptions.PageResized(page)
end
Arrangement.Restack = restack

-- The page's own row, first to refresh: lays the page out again.
local function layoutRow(page)
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(1)
    function row:Refresh() restack(page) end
    function row:SetEnabled() end
    return row
end

function Arrangement.BuildPage(page, tab)
    page.items = items(page, tab)
    page.rows = { layoutRow(page) }
    for _, item in ipairs(page.items) do page.rows[#page.rows + 1] = item.row end
    restack(page)
end

RaidOptions.CUSTOM_PAGES.arrangement = Arrangement.BuildPage
