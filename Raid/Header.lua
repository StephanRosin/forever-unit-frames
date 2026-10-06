local _, ns = ...

-- The main raid panel: the first panel (Raid/Panel.lua), with the blocks
-- of the grouping (Raid/Layout.lua) and its position in the raid
-- profile's x / y. ns.RaidHeader is that panel, with what only the main
-- panel answers: whether the raid frames are on, whether they take a
-- 5-player group, the shape of its blocks.
local Panel, Layout, Cell, Pixel, Border = ns.RaidPanel, ns.RaidLayout, ns.RaidCell, ns.Pixel, ns.Border

local function get(key) return ns.RaidConfig.Get(ns.Raid.Scope(Cell.Size()), key) end
local function general(key) return ns.RaidConfig.Get("general", key) end

local Header

-- The numbers Raid/Layout.lua works with, on the pixel grid. A cell's
-- border reaches out between the cells and from the block's edge, a
-- block's border between the blocks.
local function shape()
    local w, h = ns.Single.Size(Cell.KEY)
    local cellExtent = Border.Extent(Cell.KEY)
    return {
        cellWidth = w, cellHeight = h,
        cellGap = Pixel.Snap(get("cellSpacing")) + 2 * cellExtent,
        cellsPerLine = get("cellsPerLine"), cellGrowth = get("cellGrowth"),
        inset = cellExtent,
        titleHeight = get("blockTitles") and Pixel.Snap(Panel.TITLE_HEIGHT) or 0,
        blockGap = Pixel.Snap(get("blockSpacing")) + 2 * Border.Extent(Panel.BLOCK_SCOPE),
        blocksPerLine = get("blocksPerLine"), blockDirection = get("blockDirection"),
    }
end

Header = Panel.New({
    id = "main", name = "ForeverUnitFramesRaid", xKey = "x", yKey = "y",
    blocks = function(size) return Layout.Blocks(get("groupBy"), size, get("sortBy"), get("classOrder")) end,
    shape = shape,
    -- By role: the blocks group by role (Raid/Layout.lua), raid order within.
    attributes = function(a) a.sortMethod = get("sortBy") == "NAME" and "NAME" or "INDEX" end,
    enabled = Panel.Enabled,
    hideEmpty = function() return get("hideEmpty") end,
    -- Blizzard's word for a raid and the size.
    label = function() return ("%s %d"):format(Layout.Title({ kind = "NONE" }), Cell.Size()) end,
    showTest = function() ns.RaidTestMode.Show() end,
    hideTest = function() if ns.RaidTestMode then ns.RaidTestMode.Hide() end end,
})
ns.RaidHeader = Header

Header.NAME = "ForeverUnitFramesRaid"
Header.PANEL_SCOPE = Panel.PANEL_SCOPE
Header.BLOCK_SCOPE = Panel.BLOCK_SCOPE
Header.TITLE_SIZE = Panel.TITLE_SIZE
Header.TITLE_HEIGHT = Panel.TITLE_HEIGHT
Header.TITLE_COLOR = Panel.TITLE_COLOR
Header.Enabled = Panel.Enabled
Header.Active = Panel.Active

-- The raid view in party: a 5-player group shows here, the party frames
-- hide (Units/Party.lua asks).
function Header.ReplacesParty()
    return Header.Enabled() and general("showInParty") == true
end

-- Built once, out of combat, after the raid profile is attached: every
-- panel, the main one first.
function Header.Create()
    if Header.anchor then return Header.anchor end
    Panel.CreateAll()
    -- The party block may have been styled before the raid profile was
    -- there to ask; only the raid view in party changes its answer.
    if Header.ReplacesParty() then ns.AfterCombat("partyStyle", ns.Party.StyleAll) end
    return Header.anchor
end

-- Raid view in party switched, or the raid frames: the party block.
ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if not Header.anchor then return end
    if scope == nil or (scope == "general" and (key == nil or key == "enabled" or key == "showInParty")) then
        ns.AfterCombat("partyStyle", ns.Party.StyleAll)
    end
end)
