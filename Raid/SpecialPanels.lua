local _, ns = ...

-- The special panels: further raid panels (Raid/Panel.lua) beside the
-- main one, one block each, built with the main panel and moved with the
-- raid window's movers. A player in one stays in their group in the main
-- panel as well (shown twice). Their settings (Raid/Settings.lua,
-- Raid.PANELS) are per raid size: shown, a title above the panel, cells
-- per line and their growth, the position. The cells are the main
-- panel's of the same size; the spacing and the panel's ring are the
-- main panel's too.
--
-- Main tanks and main assists come from the raid assignment (MAINTANK,
-- MAINASSIST: /maintank, the raid leader's menu), which the headers
-- follow by themselves, in combat too.
local Special = {}
ns.RaidSpecialPanels = Special

local Panel, Cell, Pixel, Border, Raid = ns.RaidPanel, ns.RaidCell, ns.Pixel, ns.Border, ns.Raid

-- Every special panel by id.
Special.panels = {}
-- A header's columns are counted for a full raid: a list or an
-- assignment may name anyone, whatever the size shown.
Special.MAX_UNITS = 40

local function get(key) return ns.RaidConfig.Get(Raid.Scope(Cell.Size()), key) end

-- The panel's word (its section in the raid window as well).
function Special.Title(id)
    return ns.L["RAID_SECTION_" .. id]
end

-- The numbers Raid/Layout.lua works with: the main panel's cells and
-- spacing, the panel's own cells per line, growth and title row; one
-- block, so no room between blocks.
local function shape(id, cellKey)
    local w, h = ns.Single.Size(cellKey)
    local cellExtent = Border.Extent(cellKey)
    return {
        cellWidth = w, cellHeight = h,
        cellGap = Pixel.Snap(get("cellSpacing")) + 2 * cellExtent,
        cellsPerLine = get(id .. "PerLine"), cellGrowth = get(id .. "Growth"),
        inset = cellExtent,
        titleHeight = get(id .. "Title") and Pixel.Snap(Panel.TITLE_HEIGHT) or 0,
        blockGap = 0, blocksPerLine = 1, blockDirection = "HORIZONTAL",
    }
end

-- "mainTanks" -> "ForeverUnitFramesRaidMainTanks".
local function frameName(id)
    return "ForeverUnitFramesRaid" .. id:sub(1, 1):upper() .. id:sub(2)
end

-- A special panel from its definition in Raid.PANELS. how: filter() (the
-- block's header filter), optional attributes(a, size) and cellKey.
function Special.New(id, how)
    local cellKey = how.cellKey or Cell.KEY
    local P = Panel.New({
        id = id, name = frameName(id), xKey = id .. "X", yKey = id .. "Y", cellKey = cellKey,
        template = how.template, maxUnits = Special.MAX_UNITS,
        blocks = function() return { { kind = "PANEL", id = id, filter = how.filter() } } end,
        shape = function() return shape(id, cellKey) end,
        attributes = how.attributes,
        enabled = function() return Panel.Enabled() and get(id .. "Show") == true end,
        hideEmpty = function() return true end,
        blockRing = false,
        label = function() return ("%s %d"):format(Special.Title(id), Cell.Size()) end,
    })
    Special.panels[id] = P
    return P
end

Special.New("mainTanks", { filter = function() return { roleFilter = "MAINTANK" } end })
Special.New("mainAssists", { filter = function() return { roleFilter = "MAINASSIST" } end })
