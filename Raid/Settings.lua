local _, ns = ...

-- Every raid-frame setting, in a registry of its own (Core/Registry.lua).
-- "general" holds what applies to the character as a whole; r10, r20 and
-- r40 are one profile per raid size. Codes are permanent, as in
-- Core/Settings.lua, but only unique within this registry.
local Raid = {}
ns.Raid = Raid

Raid.SIZES = { 10, 20, 40 }
-- A raid group holds five; the largest size has GROUP_COUNT groups.
-- Defined here once, Raid/Layout.lua uses them.
Raid.GROUP_SIZE = 5
Raid.GROUP_COUNT = Raid.SIZES[#Raid.SIZES] / Raid.GROUP_SIZE
-- The assigned roles in Blizzard's order: the role blocks and their
-- tokens.
Raid.ROLES = { "TANK", "HEALER", "DAMAGER" }
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
-- Every per-size setting has a class (Copy between sizes may leave the
-- layout out, Raid/Profiles.lua): "layout" (cell size, spacing,
-- arrangement and panel structure, positions, icon, aura and text sizes
-- and their places in the cell) or "behaviour" (sorting, grouping, which
-- auras, icons and indicators show, heals, colours, textures, fonts,
-- borders, special panels on or off).
-- Position of the panel's top left corner, relative to the screen centre.
RaidSettings.Define({ key = "x", code = "X", scope = "frame", class = "layout", type = "int", min = -4000, max = 4000, default = -600 })
RaidSettings.Define({ key = "y", code = "Y", scope = "frame", class = "layout", type = "int", min = -4000, max = 4000, default = 150 })

-- Layout (Raid/Layout.lua). The panel is made of blocks, one group header
-- each: raid groups (only those of the size), classes, roles, or a single
-- block for everyone. Stored by index: append only.
RaidSettings.Define({ key = "groupBy", code = "GB", scope = "frame", class = "behaviour", type = "enum",
    values = { "GROUP", "CLASS", "ROLE", "NONE" }, default = "GROUP" })
-- Order within a block: raid order, name, or role (tanks, healers,
-- damage, the rest; each in raid order).
RaidSettings.Define({ key = "sortBy", code = "SO", scope = "frame", class = "behaviour", type = "enum",
    values = { "INDEX", "NAME", "ROLE" }, default = "INDEX" })
-- The class blocks' order: class tokens (commas or spaces), each once;
-- the classes not named follow in Blizzard's order. Empty: Blizzard's
-- order.
RaidSettings.Define({ key = "classOrder", code = "CO", scope = "frame", class = "behaviour", type = "text",
    maxLetters = Raid.CLASS_ORDER_LETTERS, check = isClassOrder, default = "" })
-- Blocks side by side (a row of blocks) or stacked (a column), wrapping
-- after blocksPerLine.
RaidSettings.Define({ key = "blockDirection", code = "BD", scope = "frame", class = "layout", type = "enum",
    values = { "HORIZONTAL", "VERTICAL" }, default = "HORIZONTAL" })
RaidSettings.Define({ key = "blocksPerLine", code = "BL", scope = "frame", class = "layout", type = "int", min = 1, max = 9,
    default = 8 })
-- Cells within a block: a column growing down, or a row growing right,
-- with a new column (row) after cellsPerLine cells.
RaidSettings.Define({ key = "cellGrowth", code = "CG", scope = "frame", class = "layout", type = "enum",
    values = { "DOWN", "RIGHT" }, default = "DOWN" })
RaidSettings.Define({ key = "cellsPerLine", code = "CL", scope = "frame", class = "layout", type = "int", min = 1, max = 40,
    default = 5 })
RaidSettings.Define({ key = "cellWidth", code = "CW", scope = "frame", class = "layout", type = "int", min = 30, max = 200,
    default = { r10 = 96, r20 = 88, _ = 80 } })
RaidSettings.Define({ key = "cellHeight", code = "CH", scope = "frame", class = "layout", type = "int", min = 16, max = 100,
    default = { r10 = 44, r20 = 40, _ = 38 } })
-- Room between two cells, and between two blocks (border to border).
RaidSettings.Define({ key = "cellSpacing", code = "CS", scope = "frame", class = "layout", type = "int", min = 0, max = 20, default = 2 })
RaidSettings.Define({ key = "blockSpacing", code = "BS", scope = "frame", class = "layout", type = "int", min = 0, max = 40,
    default = 6 })
-- A title row above each block (group number, class, role).
RaidSettings.Define({ key = "blockTitles", code = "BT", scope = "frame", class = "layout", type = "bool", default = false })
-- Blocks without members take no room.
RaidSettings.Define({ key = "hideEmpty", code = "HE", scope = "frame", class = "layout", type = "bool", default = true })
-- Borders: around the panel (gold), around each block, around each cell.
RaidSettings.Define({ key = "panelBorder", code = "PB", scope = "frame", class = "behaviour", type = "bool", default = true })
RaidSettings.Define({ key = "blockBorder", code = "BB", scope = "frame", class = "behaviour", type = "bool", default = false })
RaidSettings.Define({ key = "cellBorder", code = "CB", scope = "frame", class = "behaviour", type = "bool", default = false })
-- The cell's ring (Core/Border.lua): the unit frames' styles, stored by
-- index: append only; the colour is the flat style's. The corner radius
-- rounds the cell's bars, with or without a ring: slightly round by
-- default, less so as the cells shrink with the raid.
RaidSettings.Define({ key = "cellBorderStyle", code = "CY", scope = "frame", class = "behaviour", type = "enum",
    -- The unit frames' list itself: append-only there, so here too.
    values = ns.Settings.Get("borderStyle").values, default = "GOLD" })
RaidSettings.Define({ key = "cellBorderSize", code = "CZ", scope = "frame", class = "layout", type = "int", min = 1, max = 8, default = 1 })
RaidSettings.Define({ key = "cellBorderColor", code = "CK", scope = "frame", class = "behaviour", type = "color", default = { 0, 0, 0, 1 } })
RaidSettings.Define({ key = "cellCornerRadius", code = "CR", scope = "frame", class = "layout", type = "int", min = 0, max = 12,
    default = { r10 = 4, r20 = 3, _ = 2 } })

-- The cell (Raid/Cell.lua). Health in the class colour, a fixed colour
-- (healthColor), or a gradient by health. Stored by index: append only.
RaidSettings.Define({ key = "healthColorMode", code = "HM", scope = "frame", class = "behaviour", type = "enum",
    values = { "CLASS", "STATIC", "GRADIENT" }, default = "CLASS" })
RaidSettings.Define({ key = "healthColor", code = "HC", scope = "frame", class = "behaviour", type = "color",
    default = { 0.2, 0.75, 0.3, 1 } })
-- The bars' texture and the colour behind them.
RaidSettings.Define({ key = "barTexture", code = "TX", scope = "frame", class = "behaviour", type = "media", mediaKind = "statusbar",
    default = "Raid" })
RaidSettings.Define({ key = "backgroundColor", code = "BG", scope = "frame", class = "behaviour", type = "color",
    default = { 0, 0, 0, 0.6 } })
-- Incoming heals, the overheal lane at the end of the health bar (heals
-- past full health; never past the cell's edge), absorb shields, and the
-- damage and heal numbers in the cell.
RaidSettings.Define({ key = "healPrediction", code = "IH", scope = "frame", class = "behaviour", type = "bool", default = true })
RaidSettings.Define({ key = "overheal", code = "OV", scope = "frame", class = "behaviour", type = "bool", default = false })
RaidSettings.Define({ key = "absorbs", code = "AS", scope = "frame", class = "behaviour", type = "bool", default = true })
RaidSettings.Define({ key = "combatText", code = "CT", scope = "frame", class = "behaviour", type = "bool", default = false })
-- The power strip at the bottom: everyone, mana users, healers, nobody.
RaidSettings.Define({ key = "powerStrip", code = "PS", scope = "frame", class = "behaviour", type = "enum",
    values = { "ALL", "MANA", "HEALERS", "OFF" }, default = "MANA" })
-- Its height, in percent of the cell's; the health bar takes the rest.
RaidSettings.Define({ key = "powerStripHeight", code = "PH", scope = "frame", class = "layout", type = "int", min = 5,
    max = 40, default = 10 })
-- The line under the name: missing health, percent, current health, none.
-- Dead, ghost, offline and AFK replace it.
RaidSettings.Define({ key = "secondLine", code = "SL", scope = "frame", class = "behaviour", type = "enum",
    values = { "DEFICIT", "PERCENT", "CURRENT", "NONE" }, default = "DEFICIT" })
RaidSettings.Define({ key = "nameClassColor", code = "NC", scope = "frame", class = "behaviour", type = "bool", default = false })
-- The name's colour when it is not in the class colour, and the second
-- line's (the status words too).
RaidSettings.Define({ key = "nameColor", code = "NA", scope = "frame", class = "behaviour", type = "color", default = { 1, 1, 1, 1 } })
RaidSettings.Define({ key = "secondLineColor", code = "SC", scope = "frame", class = "behaviour", type = "color",
    default = { 1, 1, 1, 1 } })
-- The cell's texts: the font, the name's size and the second line's (the
-- status words too), outline and shadow; the block titles take the font
-- and the outline. The outlines are the unit frames' (Core/Settings.lua),
-- stored by index: append only.
RaidSettings.Define({ key = "fontFace", code = "FF", scope = "frame", class = "behaviour", type = "media", mediaKind = "font",
    default = "Friz Quadrata" })
RaidSettings.Define({ key = "nameFontSize", code = "NF", scope = "frame", class = "layout", type = "int", min = 6, max = 24, default = 11 })
RaidSettings.Define({ key = "secondFontSize", code = "SF", scope = "frame", class = "layout", type = "int", min = 6, max = 24,
    default = 10 })
RaidSettings.Define({ key = "fontOutline", code = "FO", scope = "frame", class = "behaviour", type = "enum",
    values = ns.Settings.Get("fontOutline").values, default = "OUTLINE" })
RaidSettings.Define({ key = "fontShadow", code = "FH", scope = "frame", class = "behaviour", type = "bool", default = true })

-- Debuffs (Raid/CellAuras.lua). The centre icon shows the most important
-- debuff you can dispel (MINE, the client's RAID filter) or any
-- dispellable one (ALL), bordered in its type's colour. Stored by index:
-- append only.
RaidSettings.Define({ key = "dispelIcon", code = "DI", scope = "frame", class = "behaviour", type = "bool", default = true })
RaidSettings.Define({ key = "dispelFilter", code = "DF", scope = "frame", class = "behaviour", type = "enum",
    values = { "MINE", "ALL" }, default = "MINE" })
RaidSettings.Define({ key = "dispelIconSize", code = "DZ", scope = "frame", class = "layout", type = "int", min = 8, max = 40,
    default = { r10 = 20, r20 = 18, _ = 16 } })
-- How it shows: the centre icon, or a small square in the type's colour
-- in one of the cell's corners (from a single pixel). Stored by index:
-- append only.
RaidSettings.Define({ key = "dispelStyle", code = "DM", scope = "frame", class = "behaviour", type = "enum",
    values = { "ICON", "SQUARE" }, default = "ICON" })
RaidSettings.Define({ key = "dispelSquarePoint", code = "DP", scope = "frame", class = "layout", type = "enum",
    values = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }, default = "TOPRIGHT" })
RaidSettings.Define({ key = "dispelSquareSize", code = "DQ", scope = "frame", class = "layout", type = "int", min = 1, max = 16,
    default = 6 })
-- The whole cell tinted in the debuff type's colour.
RaidSettings.Define({ key = "dispelTint", code = "DT", scope = "frame", class = "behaviour", type = "bool", default = false })
-- A border inside the cell in the debuff type's colour, and its
-- thickness; with the tint or without.
RaidSettings.Define({ key = "dispelBorder", code = "DB", scope = "frame", class = "behaviour", type = "bool", default = false })
RaidSettings.Define({ key = "dispelBorderSize", code = "DW", scope = "frame", class = "layout", type = "int", min = 1, max = 6,
    default = 2 })
-- A row along the bottom of the cell with every debuff ("HARMFUL"); the
-- one in the centre may show in it as well.
RaidSettings.Define({ key = "debuffRow", code = "DR", scope = "frame", class = "behaviour", type = "bool", default = false })
RaidSettings.Define({ key = "debuffCount", code = "DC", scope = "frame", class = "behaviour", type = "int", min = 1, max = 6, default = 3 })
RaidSettings.Define({ key = "debuffSize", code = "DS", scope = "frame", class = "layout", type = "int", min = 8, max = 32,
    default = { r10 = 14, r20 = 13, _ = 12 } })

-- Hidden auras of this size (Core/AuraBlocklist.lua): with the unit
-- frames' account list, the buff indicators and the debuff row leave
-- these spells out.
RaidSettings.Define({ key = "auraBlock", code = "XL", scope = "frame", class = "behaviour", type = "text",
    maxLetters = ns.AuraBlocklist.LETTERS, check = ns.AuraBlocklist.Check, blocklist = true, default = "" })

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
    RaidSettings.Define({ key = key .. "Spells", code = l .. "S", scope = "frame", class = "behaviour", type = "text",
        maxLetters = Raid.SPELL_LIST_LETTERS, check = isSpellList, default = "" })
    RaidSettings.Define({ key = key .. "Color", code = l .. "C", scope = "frame", class = "behaviour", type = "color",
        default = ind.color })
    RaidSettings.Define({ key = key .. "Size", code = l .. "Z", scope = "frame", class = "layout", type = "int", min = 4, max = 24,
        default = 8 })
    -- Only your own casts of the spells.
    RaidSettings.Define({ key = key .. "Own", code = l .. "O", scope = "frame", class = "behaviour", type = "bool", default = true })
    -- The time left: darkening (a swipe), a number, or not shown. Stored
    -- by index: append only.
    RaidSettings.Define({ key = key .. "Time", code = l .. "M", scope = "frame", class = "behaviour", type = "enum",
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
    RaidSettings.Define({ key = icon.key, code = icon.code, scope = "frame", class = "behaviour", type = "bool", default = true })
    RaidSettings.Define({ key = icon.key .. "Point", code = icon.pointCode, scope = "frame", class = "layout", type = "enum",
        values = POINTS, default = icon.point })
end
RaidSettings.Define({ key = "roleIconDamager", code = "RD", scope = "frame", class = "behaviour", type = "bool", default = false })
RaidSettings.Define({ key = "iconSize", code = "IZ", scope = "frame", class = "layout", type = "int", min = 8, max = 32,
    default = { r10 = 14, r20 = 13, _ = 12 } })

-- States (Raid/CellStates.lua, Elements/Range.lua): out of range faded
-- to rangeAlpha percent; a red inner border while the unit has aggro, a
-- light one on your current target.
RaidSettings.Define({ key = "rangeFade", code = "RF", scope = "frame", class = "behaviour", type = "bool", default = true })
RaidSettings.Define({ key = "rangeAlpha", code = "RA", scope = "frame", class = "behaviour", type = "int", min = 0, max = 100,
    default = 40 })
RaidSettings.Define({ key = "aggroBorder", code = "AB", scope = "frame", class = "behaviour", type = "bool", default = true })
RaidSettings.Define({ key = "targetBorder", code = "TB", scope = "frame", class = "behaviour", type = "bool", default = true })

-- A name list (Raid/Lists.lua): player names separated by commas, each
-- once; never a digit or a sign no name holds. A name may hold an
-- apostrophe, and a second part as the group headers compare it
-- (Raid/Lists.lua: Lists.UnitName): a realm for a player from another
-- realm (Name-Realm), or on this client a surname, which a party
-- member's name carries joined by "-" (Lea-Stone). A space is accepted
-- too: how the raid roster (GetRaidRosterInfo) writes a surname is not
-- known yet, an in-game check.
-- A typed name takes WoW's spelling: its first part (up to a "-" or a
-- space) with the first letter upper case and the rest lower case; the
-- second part stays as typed. string.upper/lower change ASCII letters
-- only, so a name starting with another letter keeps that letter's case.
-- Names are compared without case. Returns the names, or nil, why
-- ("INVALID" or "TWICE") and the name in question.
Raid.NAME_LIST_LETTERS = 250
local NOT_IN_A_NAME = "[%d%c%%;|\\/\"<>%[%]{}()=+*!?@#$^&~_:.]"
function Raid.NormaliseName(name)
    local first, rest = name:match("^([^%- ]*)(.*)$")
    return first:sub(1, 1):upper() .. first:sub(2):lower() .. rest
end
-- The key two names are the same by.
function Raid.NameKey(name)
    return name:lower()
end
function Raid.ParseNameList(text)
    local names, seen = {}, {}
    for piece in text:gmatch("[^,]+") do
        local name = piece:match("^%s*(.-)%s*$")
        if name ~= "" then
            if name:find(NOT_IN_A_NAME) then return nil, "INVALID", name end
            name = Raid.NormaliseName(name)
            local key = Raid.NameKey(name)
            if seen[key] then return nil, "TWICE", name end
            seen[key] = true
            names[#names + 1] = name
        end
    end
    return names
end

local function isNameList(text) return Raid.ParseNameList(text) ~= nil end

-- Special panels (Raid/SpecialPanels.lua): panels of their own beside the
-- main one, each with its own mover; per size: shown, a title above it,
-- cells per line, which way they grow, the panel's top-left corner from
-- the screen centre. The letter starts every code of the panel; keys
-- lists its settings in the raid window's order. The growth is stored by
-- index like cellGrowth, whose list it is. A panel of a name list (names:
-- the setting's key) keeps the list per character (general), first in
-- its section.
Raid.PANELS = {}
function Raid.DefinePanel(p)
    local id, l = p.id, p.letter
    p.keys = { id .. "Show", id .. "Title", id .. "PerLine", id .. "Growth", id .. "X", id .. "Y" }
    if p.names then
        RaidSettings.Define({ key = p.names, code = l .. "N", scope = "general", type = "text",
            maxLetters = Raid.NAME_LIST_LETTERS, check = isNameList, names = true, default = "" })
        table.insert(p.keys, 1, p.names)
    end
    RaidSettings.Define({ key = id .. "Show", code = l .. "S", scope = "frame", class = "behaviour", type = "bool", default = p.show })
    RaidSettings.Define({ key = id .. "Title", code = l .. "T", scope = "frame", class = "layout", type = "bool", default = true })
    RaidSettings.Define({ key = id .. "PerLine", code = l .. "L", scope = "frame", class = "layout", type = "int", min = 1, max = 40,
        default = p.perLine })
    RaidSettings.Define({ key = id .. "Growth", code = l .. "G", scope = "frame", class = "layout", type = "enum",
        values = RaidSettings.Get("cellGrowth").values, default = p.growth })
    RaidSettings.Define({ key = id .. "X", code = l .. "X", scope = "frame", class = "layout", type = "int", min = -4000, max = 4000,
        default = p.x })
    RaidSettings.Define({ key = id .. "Y", code = l .. "Y", scope = "frame", class = "layout", type = "int", min = -4000, max = 4000,
        default = p.y })
    Raid.PANELS[#Raid.PANELS + 1] = p
    return p
end

-- Main tanks (the raid assignment): on, a row above the main panel.
Raid.DefinePanel({ id = "mainTanks", letter = "Q", show = true, perLine = 5, growth = "RIGHT", x = -600, y = 260 })
-- Main assists (the raid assignment): off, a row above the main tanks.
Raid.DefinePanel({ id = "mainAssists", letter = "W", show = false, perLine = 5, growth = "RIGHT", x = -600, y = 340 })
-- My tanks (your own list): off, a column right of the main panel.
Raid.DefinePanel({ id = "myTanks", letter = "Z", show = false, perLine = 5, growth = "DOWN", x = 120, y = 150,
    names = "myTankNames" })
-- Favourites (your own list): off, a column beside my tanks.
Raid.DefinePanel({ id = "favourites", letter = "G", show = false, perLine = 5, growth = "DOWN", x = 240, y = 150,
    names = "favouriteNames" })
-- Pets (every pet of the raid): off, rows below the main panel; their
-- cells are as wide as the main panel's, with a height of their own.
local pets = Raid.DefinePanel({ id = "pets", letter = "O", show = false, perLine = 8, growth = "RIGHT", x = -600,
    y = -100 })
RaidSettings.Define({ key = "petsCellHeight", code = "OH", scope = "frame", class = "layout", type = "int", min = 12, max = 100,
    default = 24 })
table.insert(pets.keys, 5, "petsCellHeight")

-- Own panels (Raid/OwnPanels.lua): up to nine panels beside the main one,
-- "Panel 2" to "Panel 10", made and arranged in the raid window's
-- Arrangement tab. Per size: shown, the grouping and which of its blocks
-- the panel takes (Raid.ParseBlockList), a title above it, its own layout
-- (the main panel's settings of the same name: their ranges, lists and
-- defaults), the panel's top-left corner from the screen centre.
--
-- A code is "slot letter + part letter" (OWN_PANEL_LETTERS, the parts'
-- letters below). The scheme is nearly full: of the part letters only J
-- still makes no code that is taken for any of the nine slots. A part
-- added later needs explicit codes, one per slot, checked against the
-- whole raid registry.
Raid.OWN_TITLE_LETTERS = 40
-- A block list as stored: its longest, every class with a separator.
Raid.BLOCK_LIST_LETTERS = 100

-- A block's token: a group number, a class token or a role.
local function isBlockToken(token)
    local group = token:match("^%d$") and tonumber(token)
    if group then return group >= 1 and group <= Raid.GROUP_COUNT end
    for _, role in ipairs(Raid.ROLES) do
        if role == token then return true end
    end
    return isClass(token)
end

-- The blocks an own panel takes as stored: tokens separated by commas,
-- each once. Returns the tokens in their order, or nil when one is
-- unknown or named twice.
function Raid.ParseBlockList(text)
    local tokens, seen = {}, {}
    for piece in text:gmatch("[^,]+") do
        local token = piece:match("^%s*(.-)%s*$")
        if token ~= "" then
            if seen[token] or not isBlockToken(token) then return nil end
            seen[token] = true
            tokens[#tokens + 1] = token
        end
    end
    return tokens
end

local function isBlockList(text) return Raid.ParseBlockList(text) ~= nil end

-- The settings of a slot, in the raid window's order; like: the main
-- panel's setting whose range, list and default it takes.
local OWN_PANEL_PARTS = {
    { part = "Show", letter = "E", def = { type = "bool", default = false } },
    -- Stored by index: append only.
    { part = "GroupBy", letter = "G", def = { type = "enum", values = { "GROUP", "CLASS", "ROLE" }, default = "GROUP" } },
    { part = "Blocks", letter = "K", def = { type = "text", maxLetters = Raid.BLOCK_LIST_LETTERS, check = isBlockList,
        default = "" } },
    { part = "Title", letter = "T", def = { type = "text", maxLetters = Raid.OWN_TITLE_LETTERS, default = "" } },
    { part = "BlockDirection", letter = "D", like = "blockDirection" },
    { part = "BlocksPerLine", letter = "L", like = "blocksPerLine" },
    { part = "CellGrowth", letter = "R", like = "cellGrowth" },
    { part = "CellsPerLine", letter = "N", like = "cellsPerLine" },
    { part = "BlockTitles", letter = "U", like = "blockTitles" },
    { part = "HideEmpty", letter = "Q", like = "hideEmpty" },
    { part = "PanelBorder", letter = "W", like = "panelBorder" },
    { part = "BlockBorder", letter = "V", like = "blockBorder" },
    { part = "X", letter = "X", like = "x" },
    { part = "Y", letter = "Y", like = "y" },
}
-- Each part and the main panel's setting it is like (nil: its own).
Raid.OWN_PANEL_PARTS = {}
for i, entry in ipairs(OWN_PANEL_PARTS) do Raid.OWN_PANEL_PARTS[i] = { part = entry.part, like = entry.like } end

local function ownPanelDef(entry)
    local like = entry.like and RaidSettings.Get(entry.like)
    local def = {}
    for field, value in pairs(like or entry.def) do def[field] = value end
    return def
end

-- Panels 2 to 10: the slots' letters, and where each one first stands
-- (three to a row, right of the screen centre, right of my tanks and
-- favourites, inside a 1365 wide UI).
local OWN_PANEL_LETTERS = { "A", "F", "L", "N", "P", "M", "J", "K", "U" }
local OWN_SPOT_X, OWN_SPOT_Y, OWN_SPOT_STEP_X, OWN_SPOT_STEP_Y, OWN_SPOTS_PER_ROW = 360, 300, 110, 160, 3
Raid.OWN_PANELS = {}
local ownById = {}
for i, letter in ipairs(OWN_PANEL_LETTERS) do
    local p = { id = "panel" .. (i + 1), number = i + 1, letter = letter, keys = {} }
    for _, entry in ipairs(OWN_PANEL_PARTS) do
        local def = ownPanelDef(entry)
        -- Own panels are the arrangement itself: layout, every part.
        def.key, def.code, def.scope, def.class = p.id .. entry.part, letter .. entry.letter, "frame", "layout"
        if entry.part == "X" then def.default = OWN_SPOT_X + ((i - 1) % OWN_SPOTS_PER_ROW) * OWN_SPOT_STEP_X end
        if entry.part == "Y" then
            def.default = OWN_SPOT_Y - math.floor((i - 1) / OWN_SPOTS_PER_ROW) * OWN_SPOT_STEP_Y
        end
        RaidSettings.Define(def)
        p.keys[#p.keys + 1] = def.key
    end
    Raid.OWN_PANELS[i] = p
    ownById[p.id] = p
end

-- An own panel's slot by its id ("panel2" ...), or nil.
function Raid.OwnPanel(id)
    return ownById[id]
end

-- The raid tools bar (Raid/Tools.lua), per character: shown in a group,
-- docked or free, its top-left corner from the screen centre (free), and
-- which tools it holds.
RaidSettings.Define({ key = "toolsShow", code = "IO", scope = "general", type = "bool", default = true })
-- Docked to the main panel's right edge or free at its own position
-- (both with a handle that folds it out and in; open: folded out).
-- Stored by index: append only.
RaidSettings.Define({ key = "toolsMode", code = "IM", scope = "general", type = "enum", values = { "DOCKED", "FREE" },
    default = "DOCKED" })
-- uiState: a state of the screen (folded in or out), not a choice a
-- template or the templates' Undo touches (Raid/Templates.lua).
RaidSettings.Define({ key = "toolsOpen", code = "IE", scope = "general", type = "bool", default = false,
    uiState = true })
-- Free, it first stands above the screen centre, clear of every panel's
-- default spot (tests/test_raid_tools_default_spot.lua).
RaidSettings.Define({ key = "toolsX", code = "IX", scope = "general", type = "int", min = -4000, max = 4000,
    default = -60 })
RaidSettings.Define({ key = "toolsY", code = "IY", scope = "general", type = "int", min = -4000, max = 4000,
    default = 370 })
-- The raid target icons for your target.
RaidSettings.Define({ key = "toolsTargets", code = "IT", scope = "general", type = "bool", default = true })
-- The ready check: the last result, and starting one (leader, assistants).
RaidSettings.Define({ key = "toolsReady", code = "IR", scope = "general", type = "bool", default = true })
-- The world markers (leader, assistants).
RaidSettings.Define({ key = "toolsMarkers", code = "IW", scope = "general", type = "bool", default = true })
-- A role poll (leader, assistants); everyone an assistant, party to raid
-- and back, the loot method (the leader).
RaidSettings.Define({ key = "toolsRolePoll", code = "IP", scope = "general", type = "bool", default = true })
RaidSettings.Define({ key = "toolsAssist", code = "IA", scope = "general", type = "bool", default = true })
RaidSettings.Define({ key = "toolsConvert", code = "IC", scope = "general", type = "bool", default = true })
RaidSettings.Define({ key = "toolsLoot", code = "IL", scope = "general", type = "bool", default = true })

-- Click-casting (Raid/ClickCast.lua, Raid/ClickKeys.lua), per character:
-- spells differ per class, not per raid size.
--
-- A binding is stored as text: "" (nothing of its own: a modified click
-- does what the plain click of its button does, the client's fallback; a
-- plain click or a key does nothing), "target", "focus", "assist",
-- "menu", or "spell:<name>" (the highest rank known) or "spell:<spell
-- ID>" (that rank), "item:<name or item ID>", "macro:<macro text>". The kinds go by name, never by index. An empty value
-- ("spell:") counts as "". Returns the kind and the value (nil for a
-- kind without one), or nil when the text is no binding.
local PLAIN_BINDINGS = { [""] = true, target = true, focus = true, assist = true, menu = true }
local VALUED_BINDINGS = { spell = true, item = true, macro = true }
-- The kinds in the raid window's order: a mouse slot's, a key's.
Raid.CLICK_KINDS = { "", "target", "focus", "assist", "menu", "spell", "item", "macro" }
Raid.CLICK_KEY_KINDS = { "", "spell", "item", "macro" }
-- Whether a kind takes a value.
function Raid.BindingHasValue(kind) return VALUED_BINDINGS[kind] == true end
function Raid.ParseBinding(text)
    if PLAIN_BINDINGS[text] then return text end
    local kind, value = text:match("^(%a+):(.*)$")
    if kind and VALUED_BINDINGS[kind] then return kind, value end
    return nil
end
-- The longest binding: a macro of the client's 255 letters.
Raid.CLICK_BINDING_LETTERS = #"macro:" + 255

local function isBinding(text) return Raid.ParseBinding(text) ~= nil end
-- A key casts on the unit under the mouse: a spell, an item or a macro;
-- target, focus, assist and the menu are clicks.
local function isKeyBinding(text)
    local kind = Raid.ParseBinding(text)
    return kind == "" or (kind ~= nil and VALUED_BINDINGS[kind] == true)
end

-- A key as the client names it: upper case, modifiers in its order
-- (ALT-, CTRL-, SHIFT-) before a key name (F, F5, NUMPAD1, BUTTON4,
-- MOUSEWHEELUP, ...) or a single sign; other names are refused. Typed in any case and modifier
-- order, spaces around it trimmed. "" for none; nil for what is no key, a
-- modifier alone or twice, and the keys never taken: the mouse's left
-- and right buttons and Escape (the game's own clicks and menu).
local KEY_MODIFIERS = { "ALT", "CTRL", "SHIFT" }
local NEVER_TAKEN = { BUTTON1 = true, BUTTON2 = true, ESCAPE = true, ALT = true, CTRL = true, SHIFT = true }
-- The client's key names. Its source holds no list of them (key names come
-- from the keyboard driver, OnKeyDown); these are the families every
-- binding of the source uses, the keys a keyboard and mouse have, and a
-- gamepad's.
local NAMED_KEYS = {}
for _, name in ipairs({ "SPACE", "TAB", "ENTER", "BACKSPACE", "INSERT", "DELETE", "HOME", "END", "PAGEUP",
    "PAGEDOWN", "UP", "DOWN", "LEFT", "RIGHT", "CAPSLOCK", "NUMLOCK", "SCROLLLOCK", "PAUSE", "PRINTSCREEN",
    "ESCAPE", "MOUSEWHEELUP", "MOUSEWHEELDOWN", "NUMPADPLUS", "NUMPADMINUS", "NUMPADMULTIPLY", "NUMPADDIVIDE",
    "NUMPADDECIMAL", "NUMPADEQUALS" }) do
    NAMED_KEYS[name] = true
end
local function inRange(text, pattern, lo, hi)
    local n = tonumber(text:match(pattern))
    return n ~= nil and n >= lo and n <= hi
end
local function isKeyName(name)
    return NAMED_KEYS[name] or name:match("^[%u%d]$") ~= nil or name:match("^%p$") ~= nil
        or inRange(name, "^F(%d%d?)$", 1, 24) or inRange(name, "^NUMPAD(%d)$", 0, 9)
        or inRange(name, "^BUTTON(%d%d?)$", 1, 31)
        -- A gamepad's keys (Blizzard_SharedXML/Shared/GamepadConstants.lua:
        -- PAD1-PAD4, PADDUP, PADLSHOULDER, PADBACK, ...).
        or name:match("^PAD[%u%d]+$") ~= nil
end
function Raid.ParseKey(text)
    local rest = text:match("^%s*(.-)%s*$"):upper()
    if rest == "" then return "" end
    local held = {}
    while true do
        local modifier, after = rest:match("^(%u+)%-(.+)$")
        if not modifier or not (modifier == "ALT" or modifier == "CTRL" or modifier == "SHIFT") then break end
        if held[modifier] then return nil end
        held[modifier] = true
        rest = after
    end
    if not isKeyName(rest) or NEVER_TAKEN[rest] then return nil end
    local key = ""
    for _, modifier in ipairs(KEY_MODIFIERS) do
        if held[modifier] then key = key .. modifier .. "-" end
    end
    return key .. rest
end

local function isKey(text) return Raid.ParseKey(text) == text end

-- On or off: AUTO is on unless Clique (or another click-casting addon) is
-- loaded. Stored by index: append only.
RaidSettings.Define({ key = "clickCast", code = "HA", scope = "general", type = "enum",
    values = { "AUTO", "ON", "OFF" }, default = "AUTO" })
-- Retired (decision 76): the party frames' switch is the unit frames'
-- clickCast now (Raid/Profiles.lua migrates a stored false once). Its
-- code stays taken so old strings still read; the codec and Sanitise drop
-- its value (Core/Registry.lua); shown nowhere.
RaidSettings.Define({ key = "clickCastParty", code = "HP", scope = "general", type = "bool", default = true,
    retired = true })

-- The mouse: five buttons, each plain and with seven sets of modifiers.
-- A slot's key is "click" .. button .. modifiers ("click1",
-- "click2Shift", ...), its code the button's letter and the modifiers'.
-- The prefix is the client's for the attributes (SecureTemplates.lua:
-- alt- before ctrl- before shift-); the plain click is the wildcard "*",
-- so a modified click with nothing bound does what the plain one does.
Raid.CLICK_BUTTONS = {
    { button = 1, name = "Left", letter = "H" },
    { button = 2, name = "Right", letter = "V" },
    { button = 3, name = "Middle", letter = "S" },
    { button = 4, name = "Button4", letter = "Q" },
    { button = 5, name = "Button5", letter = "W" },
}
Raid.CLICK_MODIFIERS = {
    { name = "", prefix = "*", letter = "D" },
    { name = "Shift", prefix = "shift-", letter = "H" },
    { name = "Ctrl", prefix = "ctrl-", letter = "I" },
    { name = "Alt", prefix = "alt-", letter = "J" },
    { name = "ShiftCtrl", prefix = "ctrl-shift-", letter = "K" },
    { name = "ShiftAlt", prefix = "alt-shift-", letter = "N" },
    { name = "CtrlAlt", prefix = "alt-ctrl-", letter = "R" },
    { name = "ShiftCtrlAlt", prefix = "alt-ctrl-shift-", letter = "U" },
}
-- Left click targets, right click opens the menu, as the cells' XML does.
local CLICK_DEFAULTS = { click1 = "target", click2 = "menu" }
-- Blizzard's click bindings come first on a unit button (SecureTemplates
-- .lua: SecureUnitButton_OnClick): target and the menu act only on a
-- click bound to an interaction there, which by default are the plain
-- left and right clicks alone. A slot's interaction is true for those
-- two: the others take Target as a macro (Raid/ClickCast.lua) and never
-- the menu.
local MOUSE_KINDS = {}
for _, kind in ipairs(Raid.CLICK_KINDS) do
    if kind ~= "menu" then MOUSE_KINDS[#MOUSE_KINDS + 1] = kind end
end
-- The kinds a mouse slot offers, in the raid window's order.
function Raid.SlotKinds(slot) return slot.interaction and Raid.CLICK_KINDS or MOUSE_KINDS end
Raid.CLICK_SLOTS, Raid.CLICK_SLOT_BY_KEY = {}, {}
for _, b in ipairs(Raid.CLICK_BUTTONS) do
    for _, m in ipairs(Raid.CLICK_MODIFIERS) do
        local slot = { key = "click" .. b.button .. m.name, button = b.button, modifiers = m.name, prefix = m.prefix,
            interaction = m.prefix == "*" and b.button <= 2 }
        local check = isBinding
        if not slot.interaction then check = function(text) return isBinding(text) and text ~= "menu" end end
        RaidSettings.Define({ key = slot.key, code = b.letter .. m.letter, scope = "general", type = "text",
            maxLetters = Raid.CLICK_BINDING_LETTERS, check = check, kinds = Raid.SlotKinds(slot),
            default = CLICK_DEFAULTS[slot.key] or "" })
        Raid.CLICK_SLOTS[#Raid.CLICK_SLOTS + 1] = slot
        Raid.CLICK_SLOT_BY_KEY[slot.key] = slot
    end
end

-- Sixteen keys that cast on the raid member under the mouse: the key
-- ("clickKey1": code "T" and the slot's letter) and its binding
-- ("clickKey1Bind": code "O" and the slot's letter).
Raid.CLICK_KEY_COUNT = 16
local KEY_LETTERS, KEY_BIND_LETTERS = "ADEFGHIJKLNPQRTU", "ABCDEFIJKMNOPQRU"
-- The longest key: every modifier and a long key name.
Raid.CLICK_KEY_LETTERS = 40
Raid.CLICK_KEYS = {}
for i = 1, Raid.CLICK_KEY_COUNT do
    local slot = { index = i, key = "clickKey" .. i, bind = "clickKey" .. i .. "Bind" }
    RaidSettings.Define({ key = slot.key, code = "T" .. KEY_LETTERS:sub(i, i), scope = "general", type = "text",
        maxLetters = Raid.CLICK_KEY_LETTERS, check = isKey, default = "" })
    RaidSettings.Define({ key = slot.bind, code = "O" .. KEY_BIND_LETTERS:sub(i, i), scope = "general",
        type = "text", maxLetters = Raid.CLICK_BINDING_LETTERS, check = isKeyBinding, kinds = Raid.CLICK_KEY_KINDS,
        default = "" })
    Raid.CLICK_KEYS[i] = slot
end

-- The buff watch (Raid/BuffWatch.lua, Raid/BuffWatchWindow.lua,
-- Raid/SmartBuff.lua), per character: buffs differ per class, not per
-- raid size. Which of your class's group buffs are watched
-- (Raid/BuffData.lua: a switch per buff, one for every blessing), and
-- the blessing each class of the members gets.
local BuffData = ns.RaidBuffData
local BUFF_CODES = { buffFortitude = "BF", buffSpirit = "BR", buffShadowProtection = "BH", buffIntellect = "BA",
    buffWild = "BC", buffThorns = "BQ" }
-- Shadow Protection when a fight asks for it; Thorns on tanks only, when
-- you want it.
local BUFF_OFF = { buffShadowProtection = true, buffThorns = true }
for _, buff in ipairs(BuffData.BUFFS) do
    RaidSettings.Define({ key = buff.key, code = assert(BUFF_CODES[buff.key]), scope = "general", type = "bool",
        default = not BUFF_OFF[buff.key] })
end
RaidSettings.Define({ key = BuffData.BLESSINGS_KEY, code = "BO", scope = "general", type = "bool", default = true })
local BLESSING_CODES = { WARRIOR = "ZW", PALADIN = "ZP", PRIEST = "ZR", SHAMAN = "ZC", DRUID = "ZD", ROGUE = "ZU",
    MAGE = "ZM", WARLOCK = "ZK", HUNTER = "ZH" }
local BLESSING_DEFAULTS = { WARRIOR = "MIGHT", ROGUE = "MIGHT", HUNTER = "MIGHT" }
Raid.BLESSING_KEYS = {}
for _, class in ipairs(BuffData.CLASSES) do
    local key = "blessing" .. class
    RaidSettings.Define({ key = key, code = BLESSING_CODES[class], scope = "general", type = "enum",
        values = BuffData.BLESSINGS, default = BLESSING_DEFAULTS[class] or "WISDOM" })
    Raid.BLESSING_KEYS[#Raid.BLESSING_KEYS + 1] = key
end
-- A buff runs out with less than this many minutes left (at most a third
-- of how long it lasts); the group form is cast when this many members of
-- one group (raid group, or class for a blessing) miss it or have it
-- running out and its reagent is in your bags.
RaidSettings.Define({ key = "buffExpiring", code = "BE", scope = "general", type = "int", min = 1, max = 30,
    default = 3 })
RaidSettings.Define({ key = "buffGroupMin", code = "BN", scope = "general", type = "int", min = 1,
    max = Raid.GROUP_SIZE, default = 3 })
-- The smart buff key: casts the next buff out of combat (a key as
-- Raid.ParseKey stores it; "" none).
RaidSettings.Define({ key = "buffKey", code = "BK", scope = "general", type = "text",
    maxLetters = Raid.CLICK_KEY_LETTERS, check = isKey, default = "" })
-- The watch window: shown in a group (by default only while a buff is
-- missing or running out), its top-left corner from the screen centre.
RaidSettings.Define({ key = "buffWatchShow", code = "BW", scope = "general", type = "bool", default = true })
RaidSettings.Define({ key = "buffWatchOnlyMissing", code = "BM", scope = "general", type = "bool", default = true })
RaidSettings.Define({ key = "buffWatchX", code = "BX", scope = "general", type = "int", min = -4000, max = 4000,
    default = 300 })
RaidSettings.Define({ key = "buffWatchY", code = "BY", scope = "general", type = "int", min = -4000, max = 4000,
    default = 120 })
-- An icon on a cell whose member lacks a watched buff, at one of the
-- cell's nine points.
RaidSettings.Define({ key = "buffCellIcon", code = "BI", scope = "general", type = "bool", default = false })
RaidSettings.Define({ key = "buffCellIconPoint", code = "BP", scope = "general", type = "enum", values = POINTS,
    default = "BOTTOMLEFT" })
