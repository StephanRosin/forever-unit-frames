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
-- follow by themselves, in combat too. My tanks and favourites are your
-- own lists (Raid/Lists.lua) in the list's order; a changed list is a
-- header filter, set after combat. Pets: the pet header, smaller cells.
local Special = {}
ns.RaidSpecialPanels = Special

local Panel, Cell, Raid = ns.RaidPanel, ns.RaidCell, ns.Raid

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
-- spacing (Panel.CellShape), the panel's own cells per line, growth and
-- title row; one block, so no room between blocks.
local function shape(id, cellKey)
    local own = { cellsPerLine = id .. "PerLine", cellGrowth = id .. "Growth", blockTitles = id .. "Title" }
    local s = Panel.CellShape(function(key) return get(own[key]) end, cellKey)
    s.blockGap, s.blocksPerLine, s.blockDirection = 0, 1, "HORIZONTAL"
    return s
end

-- "mainTanks" -> "ForeverUnitFramesRaidMainTanks".
local function frameName(id)
    return "ForeverUnitFramesRaid" .. id:sub(1, 1):upper() .. id:sub(2)
end

-- A special panel from its definition in Raid.PANELS. how: filter(size)
-- (the block's header filter), optional attributes(a, size), template
-- and cellKey.
function Special.New(id, how)
    local cellKey = how.cellKey or Cell.KEY
    local P = Panel.New({
        id = id, name = frameName(id), xKey = id .. "X", yKey = id .. "Y", cellKey = cellKey,
        template = how.template, maxUnits = Special.MAX_UNITS,
        blocks = function(size) return { { kind = "PANEL", id = id, filter = how.filter(size) } } end,
        shape = function() return shape(id, cellKey) end,
        attributes = how.attributes,
        enabled = function() return Panel.Enabled() and get(id .. "Show") == true end,
        hideEmpty = function() return true end,
        blockRing = false,
        label = function() return ("%s %d"):format(Special.Title(id), Cell.Size()) end,
        -- Test mode: its pretend members (Raid/TestMode.lua).
        showTest = function(P) ns.RaidTestMode.Show(P) end,
        hideTest = function(P) if ns.RaidTestMode then ns.RaidTestMode.Hide(P) end end,
    })
    Special.panels[id] = P
    return P
end

Special.New("mainTanks", { filter = function() return { roleFilter = "MAINTANK" } end })
Special.New("mainAssists", { filter = function() return { roleFilter = "MAINASSIST" } end })

local function nameList(id)
    return {
        filter = function() return { nameList = ns.RaidLists.Attribute(id) } end,
        attributes = function(a) a.sortMethod = "NAMELIST" end,
    }
end
Special.New("myTanks", nameList("myTanks"))
Special.New("favourites", nameList("favourites"))

-- Every pet of the raid's groups the size shows (the pet header lists
-- the pets that exist, in raid order, in combat too), in cells of their
-- own height.
Special.New("pets", {
    template = "SecureGroupPetHeaderTemplate", cellKey = Cell.PET_KEY,
    filter = function(size) return { groupFilter = table.concat(ns.RaidLayout.Groups(size), ",") } end,
})
