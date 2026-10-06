local _, ns = ...

-- Every raid-frame setting, in a registry of its own (Core/Registry.lua).
-- "general" holds what applies to the character as a whole; r10, r20 and
-- r40 are one profile per raid size. Codes are permanent, as in
-- Core/Settings.lua, but only unique within this registry.
local Raid = {}
ns.Raid = Raid

Raid.SIZES = { 10, 20, 40 }
local IS_SIZE = { [10] = true, [20] = true, [40] = true }

-- The scope that holds the profile of a raid size; anything but 10, 20
-- or 40 is a mistake in the caller.
function Raid.Scope(size)
    assert(IS_SIZE[size], "unknown raid size " .. tostring(size))
    return "r" .. size
end

local RaidSettings = ns.NewRegistry(
    { "general", "r10", "r20", "r40" },
    { general = "g", r10 = "a", r20 = "b", r40 = "c" })
ns.RaidSettings = RaidSettings

-- Character-wide ----------------------------------------------------------------
RaidSettings.Define({ key = "enabled", code = "E", scope = "general", type = "bool", default = true })
-- Which size profile shows (Raid/Size.lua): AUTO follows the raid
-- instance, elsewhere the member count; a number fixes it. Stored by
-- index: append only.
RaidSettings.Define({ key = "sizeMode", code = "SM", scope = "general", type = "enum",
    values = { "AUTO", "10", "20", "40" }, default = "AUTO" })
-- A 5-player group in the raid view (10-player profile), party frames hidden.
RaidSettings.Define({ key = "showInParty", code = "SP", scope = "general", type = "bool", default = false })
-- Blizzard's raid frames hidden while ours are on.
RaidSettings.Define({ key = "hideBlizzard", code = "HB", scope = "general", type = "bool", default = true })

-- Per size ------------------------------------------------------------------------
-- Position of the panel's top left corner, relative to the screen centre.
RaidSettings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000, default = -600 })
RaidSettings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000, default = 150 })

-- Layout (Raid/Layout.lua). The panel is made of blocks, one group header
-- each: raid groups (only those of the size), classes, roles, or a single
-- block for everyone. Stored by index: append only.
RaidSettings.Define({ key = "groupBy", code = "GB", scope = "frame", type = "enum",
    values = { "GROUP", "CLASS", "ROLE", "NONE" }, default = "GROUP" })
-- Order within a block: raid order or name.
RaidSettings.Define({ key = "sortBy", code = "SO", scope = "frame", type = "enum",
    values = { "INDEX", "NAME" }, default = "INDEX" })
-- Blocks side by side (a row of blocks) or stacked (a column), wrapping
-- after blocksPerLine.
RaidSettings.Define({ key = "blockDirection", code = "BD", scope = "frame", type = "enum",
    values = { "HORIZONTAL", "VERTICAL" }, default = "HORIZONTAL" })
RaidSettings.Define({ key = "blocksPerLine", code = "BL", scope = "frame", type = "int", min = 1, max = 9,
    default = 8 })
-- Cells within a block: a column growing down, or a row growing right,
-- with a new column (row) after cellsPerLine cells.
RaidSettings.Define({ key = "cellGrowth", code = "CG", scope = "frame", type = "enum",
    values = { "DOWN", "RIGHT" }, default = "DOWN" })
RaidSettings.Define({ key = "cellsPerLine", code = "CL", scope = "frame", type = "int", min = 1, max = 40,
    default = 5 })
RaidSettings.Define({ key = "cellWidth", code = "CW", scope = "frame", type = "int", min = 30, max = 200,
    default = { r10 = 96, r20 = 88, _ = 80 } })
RaidSettings.Define({ key = "cellHeight", code = "CH", scope = "frame", type = "int", min = 16, max = 100,
    default = { r10 = 44, r20 = 40, _ = 38 } })
-- Room between two cells, and between two blocks (border to border).
RaidSettings.Define({ key = "cellSpacing", code = "CS", scope = "frame", type = "int", min = 0, max = 20, default = 2 })
RaidSettings.Define({ key = "blockSpacing", code = "BS", scope = "frame", type = "int", min = 0, max = 40,
    default = 6 })
-- A title row above each block (group number, class, role).
RaidSettings.Define({ key = "blockTitles", code = "BT", scope = "frame", type = "bool", default = false })
-- Blocks without members take no room.
RaidSettings.Define({ key = "hideEmpty", code = "HE", scope = "frame", type = "bool", default = true })
-- Borders: around the panel (gold), around each block, around each cell.
RaidSettings.Define({ key = "panelBorder", code = "PB", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "blockBorder", code = "BB", scope = "frame", type = "bool", default = false })
RaidSettings.Define({ key = "cellBorder", code = "CB", scope = "frame", type = "bool", default = false })

-- The cell (Raid/Cell.lua). Health in the class colour, the unit-frame
-- health colour, or a gradient by health. Stored by index: append only.
RaidSettings.Define({ key = "healthColorMode", code = "HM", scope = "frame", type = "enum",
    values = { "CLASS", "STATIC", "GRADIENT" }, default = "CLASS" })
-- The power strip at the bottom: everyone, mana users, healers, nobody.
RaidSettings.Define({ key = "powerStrip", code = "PS", scope = "frame", type = "enum",
    values = { "ALL", "MANA", "HEALERS", "OFF" }, default = "MANA" })
-- The line under the name: missing health, percent, current health, none.
-- Dead, ghost, offline and AFK replace it.
RaidSettings.Define({ key = "secondLine", code = "SL", scope = "frame", type = "enum",
    values = { "DEFICIT", "PERCENT", "CURRENT", "NONE" }, default = "DEFICIT" })
RaidSettings.Define({ key = "nameClassColor", code = "NC", scope = "frame", type = "bool", default = false })
