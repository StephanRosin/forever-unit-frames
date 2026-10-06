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

-- Debuffs (Raid/CellAuras.lua). The centre icon shows the most important
-- debuff you can dispel (MINE, the client's RAID filter) or any
-- dispellable one (ALL), bordered in its type's colour. Stored by index:
-- append only.
RaidSettings.Define({ key = "dispelIcon", code = "DI", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "dispelFilter", code = "DF", scope = "frame", type = "enum",
    values = { "MINE", "ALL" }, default = "MINE" })
RaidSettings.Define({ key = "dispelIconSize", code = "DZ", scope = "frame", type = "int", min = 8, max = 40,
    default = { r10 = 20, r20 = 18, _ = 16 } })
-- The whole cell tinted in the debuff type's colour.
RaidSettings.Define({ key = "dispelTint", code = "DT", scope = "frame", type = "bool", default = false })
-- A row of further debuffs along the bottom of the cell.
RaidSettings.Define({ key = "debuffRow", code = "DR", scope = "frame", type = "bool", default = false })
RaidSettings.Define({ key = "debuffCount", code = "DC", scope = "frame", type = "int", min = 1, max = 6, default = 3 })
RaidSettings.Define({ key = "debuffSize", code = "DS", scope = "frame", type = "int", min = 8, max = 32,
    default = { r10 = 14, r20 = 13, _ = 12 } })

-- A spell list: spell IDs separated by commas or spaces. Returns the IDs,
-- or nil when anything else is in it (a name, a sign, a fraction).
function Raid.SpellList(text)
    local ids = {}
    for token in text:gmatch("[^,%s]+") do
        if not token:match("^%d+$") then return nil end
        local id = tonumber(token)
        if id < 1 then return nil end
        ids[#ids + 1] = id
    end
    return ids
end

local function isSpellList(text) return Raid.SpellList(text) ~= nil end

-- Corner indicators (Raid/Indicators.lua): five positions, each showing
-- one of its spells while it is on the unit. Empty spells: off. The
-- letter starts every code of the position.
Raid.INDICATORS = {
    { point = "TOPLEFT", name = "TopLeft", letter = "J", color = { 0.2, 0.9, 0.2, 1 } },
    { point = "TOPRIGHT", name = "TopRight", letter = "K", color = { 1, 0.85, 0.1, 1 } },
    { point = "BOTTOMLEFT", name = "BottomLeft", letter = "U", color = { 0.3, 0.6, 1, 1 } },
    { point = "BOTTOMRIGHT", name = "BottomRight", letter = "V", color = { 1, 0.3, 0.3, 1 } },
    { point = "TOP", name = "Top", letter = "T", color = { 1, 1, 1, 1 } },
}
-- Room for every rank of a few spells.
Raid.SPELL_LIST_LETTERS = 200
for _, ind in ipairs(Raid.INDICATORS) do
    local key, l = "indicator" .. ind.name, ind.letter
    RaidSettings.Define({ key = key .. "Spells", code = l .. "S", scope = "frame", type = "text",
        maxLetters = Raid.SPELL_LIST_LETTERS, check = isSpellList, default = "" })
    RaidSettings.Define({ key = key .. "Color", code = l .. "C", scope = "frame", type = "color",
        default = ind.color })
    RaidSettings.Define({ key = key .. "Size", code = l .. "Z", scope = "frame", type = "int", min = 4, max = 24,
        default = 8 })
    -- Only your own casts of the spells.
    RaidSettings.Define({ key = key .. "Own", code = l .. "O", scope = "frame", type = "bool", default = true })
    -- The time left: darkening (a swipe), a number, or not shown. Stored
    -- by index: append only.
    RaidSettings.Define({ key = key .. "Time", code = l .. "M", scope = "frame", type = "enum",
        values = { "SWIPE", "NUMBER", "NONE" }, default = "SWIPE" })
end
