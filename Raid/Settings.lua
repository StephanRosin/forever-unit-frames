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

-- Blizzard's class order for this game type (CLASS_SORT_ORDER), read
-- when asked: the class tokens a class order may name.
function Raid.Classes()
    return CLASS_SORT_ORDER or { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK",
        "HUNTER" }
end

local function isClass(token)
    for _, class in ipairs(Raid.Classes()) do
        if class == token then return true end
    end
    return false
end

-- A class order as stored: class tokens separated by commas or spaces,
-- each once.
local function isClassOrder(text)
    local seen = {}
    for token in text:gmatch("[^,%s]+") do
        if seen[token] or not isClass(token) then return false end
        seen[token] = true
    end
    return true
end
-- Every class with a separator.
Raid.CLASS_ORDER_LETTERS = 100

-- What the options window stores for a typed class order: the tokens,
-- comma-separated. It takes tokens in any case and the game's class
-- names (commas between them, a name may hold a space). nil, why
-- ("UNKNOWN" or "TWICE") and the word in question when a class is
-- unknown or named twice.
local function tokenOf(word)
    local upper = word:upper()
    if isClass(upper) then return upper end
    for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
        if type(names) == "table" then
            for token, name in pairs(names) do
                if type(name) == "string" and name:lower() == word:lower() and isClass(token) then return token end
            end
        end
    end
    return nil
end

function Raid.ParseClassOrder(text)
    local tokens, seen = {}, {}
    for piece in text:gmatch("[^,]+") do
        local word = piece:match("^%s*(.-)%s*$")
        if word ~= "" then
            local token = tokenOf(word)
            if not token then return nil, "UNKNOWN", word end
            if seen[token] then return nil, "TWICE", word end
            seen[token] = true
            tokens[#tokens + 1] = token
        end
    end
    return table.concat(tokens, ",")
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
-- The raid frames' minimap button (Raid/MinimapButton.lua): shown, and its
-- angle around the minimap in degrees, counter-clockwise from the right
-- (260: below the unit frames' button at 225, with room between them on
-- a round minimap); set by dragging it.
RaidSettings.Define({ key = "minimapShow", code = "MS", scope = "general", type = "bool", default = true })
RaidSettings.Define({ key = "minimapAngle", code = "MA", scope = "general", type = "int", min = 0, max = 359,
    default = 260 })

-- Per size ------------------------------------------------------------------------
-- Position of the panel's top left corner, relative to the screen centre.
RaidSettings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000, default = -600 })
RaidSettings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000, default = 150 })

-- Layout (Raid/Layout.lua). The panel is made of blocks, one group header
-- each: raid groups (only those of the size), classes, roles, or a single
-- block for everyone. Stored by index: append only.
RaidSettings.Define({ key = "groupBy", code = "GB", scope = "frame", type = "enum",
    values = { "GROUP", "CLASS", "ROLE", "NONE" }, default = "GROUP" })
-- Order within a block: raid order, name, or role (tanks, healers,
-- damage, the rest; each in raid order).
RaidSettings.Define({ key = "sortBy", code = "SO", scope = "frame", type = "enum",
    values = { "INDEX", "NAME", "ROLE" }, default = "INDEX" })
-- The class blocks' order: class tokens (commas or spaces), each once;
-- the classes not named follow in Blizzard's order. Empty: Blizzard's
-- order.
RaidSettings.Define({ key = "classOrder", code = "CO", scope = "frame", type = "text",
    maxLetters = Raid.CLASS_ORDER_LETTERS, check = isClassOrder, default = "" })
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
-- The cell's ring (Core/Border.lua): the unit frames' styles, stored by
-- index: append only; the colour is the flat style's. The corner radius
-- rounds the cell's bars, with or without a ring: slightly round by
-- default, less so as the cells shrink with the raid.
RaidSettings.Define({ key = "cellBorderStyle", code = "CY", scope = "frame", type = "enum",
    -- The unit frames' list itself: append-only there, so here too.
    values = ns.Settings.Get("borderStyle").values, default = "GOLD" })
RaidSettings.Define({ key = "cellBorderSize", code = "CZ", scope = "frame", type = "int", min = 1, max = 8, default = 1 })
RaidSettings.Define({ key = "cellBorderColor", code = "CK", scope = "frame", type = "color", default = { 0, 0, 0, 1 } })
RaidSettings.Define({ key = "cellCornerRadius", code = "CR", scope = "frame", type = "int", min = 0, max = 12,
    default = { r10 = 4, r20 = 3, _ = 2 } })

-- The cell (Raid/Cell.lua). Health in the class colour, a fixed colour
-- (healthColor), or a gradient by health. Stored by index: append only.
RaidSettings.Define({ key = "healthColorMode", code = "HM", scope = "frame", type = "enum",
    values = { "CLASS", "STATIC", "GRADIENT" }, default = "CLASS" })
RaidSettings.Define({ key = "healthColor", code = "HC", scope = "frame", type = "color",
    default = { 0.2, 0.75, 0.3, 1 } })
-- The bars' texture and the colour behind them.
RaidSettings.Define({ key = "barTexture", code = "TX", scope = "frame", type = "media", mediaKind = "statusbar",
    default = "Raid" })
RaidSettings.Define({ key = "backgroundColor", code = "BG", scope = "frame", type = "color",
    default = { 0, 0, 0, 0.6 } })
-- Incoming heals, the overheal lane at the end of the health bar (heals
-- past full health; never past the cell's edge), absorb shields, and the
-- damage and heal numbers in the cell.
RaidSettings.Define({ key = "healPrediction", code = "IH", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "overheal", code = "OV", scope = "frame", type = "bool", default = false })
RaidSettings.Define({ key = "absorbs", code = "AS", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "combatText", code = "CT", scope = "frame", type = "bool", default = false })
-- The power strip at the bottom: everyone, mana users, healers, nobody.
RaidSettings.Define({ key = "powerStrip", code = "PS", scope = "frame", type = "enum",
    values = { "ALL", "MANA", "HEALERS", "OFF" }, default = "MANA" })
-- The line under the name: missing health, percent, current health, none.
-- Dead, ghost, offline and AFK replace it.
RaidSettings.Define({ key = "secondLine", code = "SL", scope = "frame", type = "enum",
    values = { "DEFICIT", "PERCENT", "CURRENT", "NONE" }, default = "DEFICIT" })
RaidSettings.Define({ key = "nameClassColor", code = "NC", scope = "frame", type = "bool", default = false })
-- The name's colour when it is not in the class colour, and the second
-- line's (the status words too).
RaidSettings.Define({ key = "nameColor", code = "NA", scope = "frame", type = "color", default = { 1, 1, 1, 1 } })
RaidSettings.Define({ key = "secondLineColor", code = "SC", scope = "frame", type = "color",
    default = { 1, 1, 1, 1 } })
-- The cell's texts: the font, the name's size and the second line's (the
-- status words too), outline and shadow; the block titles take the font
-- and the outline. The outlines are the unit frames' (Core/Settings.lua),
-- stored by index: append only.
RaidSettings.Define({ key = "fontFace", code = "FF", scope = "frame", type = "media", mediaKind = "font",
    default = "Friz Quadrata" })
RaidSettings.Define({ key = "nameFontSize", code = "NF", scope = "frame", type = "int", min = 6, max = 24, default = 11 })
RaidSettings.Define({ key = "secondFontSize", code = "SF", scope = "frame", type = "int", min = 6, max = 24,
    default = 10 })
RaidSettings.Define({ key = "fontOutline", code = "FO", scope = "frame", type = "enum",
    values = ns.Settings.Get("fontOutline").values, default = "OUTLINE" })
RaidSettings.Define({ key = "fontShadow", code = "FH", scope = "frame", type = "bool", default = true })

-- Debuffs (Raid/CellAuras.lua). The centre icon shows the most important
-- debuff you can dispel (MINE, the client's RAID filter) or any
-- dispellable one (ALL), bordered in its type's colour. Stored by index:
-- append only.
RaidSettings.Define({ key = "dispelIcon", code = "DI", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "dispelFilter", code = "DF", scope = "frame", type = "enum",
    values = { "MINE", "ALL" }, default = "MINE" })
RaidSettings.Define({ key = "dispelIconSize", code = "DZ", scope = "frame", type = "int", min = 8, max = 40,
    default = { r10 = 20, r20 = 18, _ = 16 } })
-- How it shows: the centre icon, or a small square in the type's colour
-- in one of the cell's corners (from a single pixel). Stored by index:
-- append only.
RaidSettings.Define({ key = "dispelStyle", code = "DM", scope = "frame", type = "enum",
    values = { "ICON", "SQUARE" }, default = "ICON" })
RaidSettings.Define({ key = "dispelSquarePoint", code = "DP", scope = "frame", type = "enum",
    values = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }, default = "TOPRIGHT" })
RaidSettings.Define({ key = "dispelSquareSize", code = "DQ", scope = "frame", type = "int", min = 1, max = 16,
    default = 6 })
-- The whole cell tinted in the debuff type's colour.
RaidSettings.Define({ key = "dispelTint", code = "DT", scope = "frame", type = "bool", default = false })
-- A row along the bottom of the cell with every debuff ("HARMFUL"); the
-- one in the centre may show in it as well.
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

-- Icons (Raid/Cell.lua and the elements it maps them to), each switched
-- on its own and placed on one of the cell's nine points (just inside
-- it), all at one size per raid size: the assigned role (tank and
-- healer; damage too when asked), the raid target marker, the group's
-- leader or an assistant, the master looter, the ready check.
local POINTS = ns.Settings.POINTS
for _, icon in ipairs({
    { key = "roleIcon", code = "RI", pointCode = "RP", point = "LEFT" },
    { key = "raidMarker", code = "RM", pointCode = "RQ", point = "RIGHT" },
    { key = "leaderIcon", code = "LI", pointCode = "LP", point = "TOPLEFT" },
    { key = "looterIcon", code = "MI", pointCode = "MP", point = "TOPRIGHT" },
    { key = "readyCheckIcon", code = "YI", pointCode = "YP", point = "CENTER" },
}) do
    RaidSettings.Define({ key = icon.key, code = icon.code, scope = "frame", type = "bool", default = true })
    RaidSettings.Define({ key = icon.key .. "Point", code = icon.pointCode, scope = "frame", type = "enum",
        values = POINTS, default = icon.point })
end
RaidSettings.Define({ key = "roleIconDamager", code = "RD", scope = "frame", type = "bool", default = false })
RaidSettings.Define({ key = "iconSize", code = "IZ", scope = "frame", type = "int", min = 8, max = 32,
    default = { r10 = 14, r20 = 13, _ = 12 } })

-- States (Raid/CellStates.lua, Elements/Range.lua): out of range faded
-- to rangeAlpha percent; a red inner border while the unit has aggro, a
-- light one on your current target.
RaidSettings.Define({ key = "rangeFade", code = "RF", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "rangeAlpha", code = "RA", scope = "frame", type = "int", min = 0, max = 100,
    default = 40 })
RaidSettings.Define({ key = "aggroBorder", code = "AB", scope = "frame", type = "bool", default = true })
RaidSettings.Define({ key = "targetBorder", code = "TB", scope = "frame", type = "bool", default = true })

-- Special panels (Raid/SpecialPanels.lua): panels of their own beside the
-- main one, each with its own mover; per size: shown, a title above it,
-- cells per line, which way they grow, the panel's top-left corner from
-- the screen centre. The letter starts every code of the panel; keys
-- lists its settings in the raid window's order. The growth is stored by
-- index like cellGrowth, whose list it is.
Raid.PANELS = {}
function Raid.DefinePanel(p)
    local id, l = p.id, p.letter
    p.keys = { id .. "Show", id .. "Title", id .. "PerLine", id .. "Growth", id .. "X", id .. "Y" }
    RaidSettings.Define({ key = id .. "Show", code = l .. "S", scope = "frame", type = "bool", default = p.show })
    RaidSettings.Define({ key = id .. "Title", code = l .. "T", scope = "frame", type = "bool", default = true })
    RaidSettings.Define({ key = id .. "PerLine", code = l .. "L", scope = "frame", type = "int", min = 1, max = 40,
        default = p.perLine })
    RaidSettings.Define({ key = id .. "Growth", code = l .. "G", scope = "frame", type = "enum",
        values = RaidSettings.Get("cellGrowth").values, default = p.growth })
    RaidSettings.Define({ key = id .. "X", code = l .. "X", scope = "frame", type = "int", min = -4000, max = 4000,
        default = p.x })
    RaidSettings.Define({ key = id .. "Y", code = l .. "Y", scope = "frame", type = "int", min = -4000, max = 4000,
        default = p.y })
    Raid.PANELS[#Raid.PANELS + 1] = p
    return p
end

-- Main tanks (the raid assignment): on, a row above the main panel.
Raid.DefinePanel({ id = "mainTanks", letter = "Q", show = true, perLine = 5, growth = "RIGHT", x = -600, y = 260 })
-- Main assists (the raid assignment): off, a row above the main tanks.
Raid.DefinePanel({ id = "mainAssists", letter = "W", show = false, perLine = 5, growth = "RIGHT", x = -600, y = 340 })
