local _, ns = ...

-- The one list of every setting. Config, Codec, the options window and the
-- tests all read from here. A setting's `code` is written into saved and
-- exported strings: once released it must never change or be reused.
local Settings = {}
ns.Settings = Settings

Settings.SCOPES = { "general", "player", "target", "targettarget", "pet", "focus", "party" }
Settings.PREFIX = {
    general = "g", player = "p", target = "t", targettarget = "o",
    pet = "e", focus = "f", party = "y",
}

local list, byKey, byCode = {}, {}, {}

function Settings.Define(def)
    assert(not byKey[def.key], "duplicate key " .. def.key)
    assert(not byCode[def.code], "duplicate code " .. def.code)
    list[#list + 1] = def
    byKey[def.key] = def
    byCode[def.code] = def
end

function Settings.Get(key) return byKey[key] end
function Settings.ByCode(code) return byCode[code] end
function Settings.All() return list end

function Settings.Default(def, scope)
    local d = def.default
    if type(d) == "table" and d._ ~= nil then
        local v = d[scope]
        if v == nil then v = d._ end
        return v
    end
    return d
end

-- The shipped look (Core/Preset.lua) on top of the plain defaults:
-- preset[scope][key] = value. A general value becomes the setting's base
-- default, a frame value that frame's own default.
function Settings.ApplyPreset(preset)
    for scope, values in pairs(preset) do
        for key, value in pairs(values) do
            local def = assert(byKey[key], "preset: unknown setting " .. key)
            assert(Settings.AppliesTo(def, scope), "preset: " .. key .. " does not apply to " .. scope)
            assert(Settings.Validate(def, value) == value or def.type == "color", "preset: invalid " .. key)
            local d = def.default
            if type(d) ~= "table" or d._ == nil then d = { _ = d } end
            if scope == "general" then d._ = value else d[scope] = value end
            def.default = d
        end
    end
end

-- def.only (optional) limits a frame setting to some frames, e.g.
-- { party = true } for the party layout.
function Settings.AppliesTo(def, scope)
    if scope == "general" then return def.scope ~= "frame" end
    if def.scope == "general" then return false end
    if def.only then return def.only[scope] == true end
    return true
end

local function inList(values, v)
    for i = 1, #values do if values[i] == v then return true end end
    return false
end

-- The longest free text a setting takes (a spell name, or its ID).
Settings.TEXT_MAX = 64

function Settings.Validate(def, v)
    local t = def.type
    if t == "int" then
        if type(v) ~= "number" then return nil end
        if v ~= v or v == math.huge or v == -math.huge then return nil end
        v = math.floor(v + 0.5)
        if def.min and v < def.min then v = def.min end
        if def.max and v > def.max then v = def.max end
        return v
    elseif t == "bool" then
        if type(v) ~= "boolean" then return nil end
        return v
    elseif t == "enum" then
        if not inList(def.values, v) then return nil end
        return v
    elseif t == "color" then
        if type(v) ~= "table" then return nil end
        for i = 1, 4 do
            local c = v[i]
            if type(c) ~= "number" or c < 0 or c > 1 then return nil end
        end
        return { v[1], v[2], v[3], v[4] }
    elseif t == "media" then
        if type(v) ~= "string" or v == "" then return nil end
        return v
    elseif t == "text" then
        -- Free text, trimmed; empty is allowed. def.maxLetters caps it.
        if type(v) ~= "string" then return nil end
        v = v:match("^%s*(.-)%s*$")
        if #v > (def.maxLetters or Settings.TEXT_MAX) then return nil end
        return v
    end
    return nil
end

-- Definitions -----------------------------------------------------------------
-- Order here is the order of the options pages; codes are permanent.

local TEXT_TAGS = { "NONE", "NAME", "NAME_LEVEL", "LEVEL", "CURRENT", "CURRENT_MAX", "PERCENT", "DEFICIT" }
Settings.TEXT_TAGS = TEXT_TAGS

-- General appearance (inherited by every frame, overridable per frame)
-- The font settings, in the order the options page lists them.
Settings.FONT_KEYS = { "fontFace", "fontSize", "fontOutline", "fontShadow" }
-- What "Apply to all frames" hands back to General: the font settings and
-- the name style listed with them.
Settings.TEXT_STYLE_KEYS = { "fontFace", "fontSize", "fontOutline", "fontShadow", "showSurname" }
Settings.Define({ key = "fontFace", code = "FF", scope = "inherit", type = "media", mediaKind = "font", default = "Friz Quadrata" })
Settings.Define({ key = "fontSize", code = "FS", scope = "inherit", type = "int", min = 6, max = 32, default = 12 })
Settings.Define({ key = "fontOutline", code = "FO", scope = "inherit", type = "enum",
    values = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "SOFT" }, default = "SOFT" })
Settings.Define({ key = "fontShadow", code = "FH", scope = "inherit", type = "bool", default = false })
-- Secondary name (surname) next to the first name, like Blizzard's frames.
Settings.Define({ key = "showSurname", code = "SN", scope = "inherit", type = "bool", default = true })
-- Class icon at the right end of the title row (players only).
Settings.Define({ key = "titleClassIcon", code = "CL", scope = "inherit", type = "bool", default = true })
-- The icon is a round badge on the frame's top right corner: its size and
-- the offset of its centre from that corner. The defaults put it slightly
-- inside horizontally and mostly above the top edge.
Settings.Define({ key = "classIconSize", code = "KS", scope = "inherit", type = "int", min = 10, max = 48, default = 28 })
Settings.Define({ key = "classIconX", code = "KX", scope = "inherit", type = "int", min = -64, max = 64, default = -6 })
Settings.Define({ key = "classIconY", code = "KY", scope = "inherit", type = "int", min = -64, max = 64, default = 2 })
-- The badge's own round ring, independent of the frame border: thickness
-- (0 turns it off, the icon then fills the badge) and colour.
Settings.Define({ key = "classIconRing", code = "KR", scope = "inherit", type = "int", min = 0, max = 4, default = 2 })
Settings.Define({ key = "classIconRingColor", code = "KC", scope = "inherit", type = "color",
    default = { 0.78, 0.78, 0.8, 1 } })
Settings.Define({ key = "barTexture", code = "BT", scope = "inherit", type = "media", mediaKind = "statusbar", default = "Flat" })
Settings.Define({ key = "backgroundColor", code = "BC", scope = "inherit", type = "color", default = { 0, 0, 0, 0.6 } })
-- Outer border (Core/Border.lua): one ring around the unit, a docked
-- castbar included. Hidden keeps size and padding for later. Styles are
-- stored by index: append only.
Settings.Define({ key = "borderShow", code = "BV", scope = "inherit", type = "bool", default = true })
Settings.Define({ key = "borderStyle", code = "BY", scope = "inherit", type = "enum",
    values = { "FLAT", "GOLD" }, default = "FLAT" })
Settings.Define({ key = "borderSize", code = "BS", scope = "inherit", type = "int", min = 0, max = 8, default = 1 })
Settings.Define({ key = "borderColor", code = "BO", scope = "inherit", type = "color", default = { 0, 0, 0, 1 } })
Settings.Define({ key = "borderPadding", code = "BP", scope = "inherit", type = "int", min = 0, max = 8, default = 0 })
-- Soft drop shadow around the ring: strength in percent, size in pixels.
Settings.Define({ key = "shadowEnabled", code = "SE", scope = "inherit", type = "bool", default = false })
Settings.Define({ key = "shadowAlpha", code = "SA", scope = "inherit", type = "int", min = 0, max = 100, default = 50 })
Settings.Define({ key = "shadowSize", code = "SZ", scope = "inherit", type = "int", min = 1, max = 16, default = 4 })
Settings.Define({ key = "cornerRadius", code = "CR", scope = "inherit", type = "int", min = 0, max = 12, default = 0 })

-- Colors
Settings.Define({ key = "healthColorMode", code = "HM", scope = "inherit", type = "enum",
    values = { "CLASS", "REACTION", "STATIC", "GRADIENT" }, default = "STATIC" })
Settings.Define({ key = "healthColor", code = "HC", scope = "inherit", type = "color", default = { 0.2, 0.75, 0.3, 1 } })
-- Colour of the shield's stripes; the shield darkens the bar under them.
Settings.Define({ key = "absorbColor", code = "AC", scope = "inherit", type = "color", default = { 1, 1, 1, 0.65 } })
Settings.Define({ key = "healMyColor", code = "MC", scope = "inherit", type = "color", default = { 0.3, 0.95, 0.45, 0.65 } })
Settings.Define({ key = "healOtherColor", code = "OC", scope = "inherit", type = "color", default = { 0.15, 0.65, 0.3, 0.55 } })

-- Frame layout
Settings.Define({ key = "enabled", code = "E", scope = "frame", type = "bool", default = true })
Settings.Define({ key = "width", code = "W", scope = "frame", type = "int", min = 40, max = 600,
    default = { player = 220, target = 220, focus = 160, party = 160, _ = 120 } })
Settings.Define({ key = "height", code = "H", scope = "frame", type = "int", min = 8, max = 200,
    default = { player = 46, target = 46, focus = 36, party = 46, _ = 28 } })
-- Rows, top to bottom: title, health, power; each a share of the frame
-- height, and together they fill it (Layout.Rows). A title of 0 is the
-- two-row layout.
Settings.Define({ key = "titlePercent", code = "TP", scope = "frame", type = "int", min = 0, max = 60,
    default = { player = 30, target = 30, focus = 30, party = 30, _ = 0 } })
Settings.Define({ key = "healthPercent", code = "HP", scope = "frame", type = "int", min = 10, max = 100,
    default = { player = 45, target = 45, focus = 45, party = 45, _ = 75 } })
Settings.Define({ key = "powerPercent", code = "PP", scope = "frame", type = "int", min = 0, max = 90, default = 25 })
Settings.Define({ key = "powerEnabled", code = "PE", scope = "frame", type = "bool", default = true })
Settings.Define({ key = "absorbEnabled", code = "AB", scope = "frame", type = "bool", default = true })
-- Incoming heals; the overheal lane gives the end of the health row to
-- heals past full health.
Settings.Define({ key = "healPrediction", code = "IH", scope = "frame", type = "bool", default = true })
Settings.Define({ key = "healOverflow", code = "OV", scope = "frame", type = "bool", default = false })
-- With the overheal lane: the power bar ends where the health bar ends.
Settings.Define({ key = "powerMatchesHealth", code = "OM", scope = "frame", type = "bool", default = false })
Settings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000,
    default = { player = -300, target = 300, targettarget = 480, pet = -352, focus = -300, party = -760, _ = 0 } })
Settings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000,
    default = { player = -220, target = -220, targettarget = -220, pet = -272, focus = -120, party = 120, _ = 0 } })

-- Portrait
Settings.Define({ key = "portraitMode", code = "PM", scope = "frame", type = "enum",
    values = { "OFF", "LEFT", "RIGHT" }, default = "OFF" })
Settings.Define({ key = "portraitStyle", code = "PS", scope = "frame", type = "enum",
    values = { "2D", "3D" }, default = "2D" })

-- Elite / rare marker: frames that show units other than you and your pet.
Settings.Define({ key = "eliteMarker", code = "EM", scope = "frame",
    only = { target = true, targettarget = true, focus = true, party = true }, type = "bool", default = true })
-- Damage and heal numbers inside the frame (Blizzard shows them on the
-- player and pet frames).
Settings.Define({ key = "combatFeedback", code = "CF", scope = "frame", type = "bool",
    default = { player = true, pet = true, _ = false } })

-- Party block (party only)
local PARTY = { party = true }
Settings.Define({ key = "partyOrientation", code = "OR", scope = "frame", only = PARTY, type = "enum",
    values = { "VERTICAL", "HORIZONTAL" }, default = "VERTICAL" })
Settings.Define({ key = "partySpacing", code = "GS", scope = "frame", only = PARTY, type = "int", min = 0, max = 60, default = 12 })
Settings.Define({ key = "partyShowPlayer", code = "SP", scope = "frame", only = PARTY, type = "bool", default = false })
Settings.Define({ key = "partyShowSolo", code = "SO", scope = "frame", only = PARTY, type = "bool", default = false })
-- Party pets (Units/PartyPets.lua): one small frame under each member
-- whose pet exists. Height in pixels; the width is the member's.
Settings.Define({ key = "partyShowPets", code = "PT", scope = "frame", only = PARTY, type = "bool", default = false })
Settings.Define({ key = "partyPetHeight", code = "PH", scope = "frame", only = PARTY, type = "int", min = 10, max = 60,
    default = 20 })
-- Buffs and debuffs on the pet frames, laid out like the members'.
Settings.Define({ key = "partyPetAuras", code = "PA", scope = "frame", only = PARTY, type = "bool", default = false })

-- Castbar (not on the pet frame; off by default on the player frame)
local CASTBAR = { player = true, target = true, targettarget = true, focus = true, party = true }
Settings.Define({ key = "castbarEnabled", code = "CE", scope = "frame", only = CASTBAR, type = "bool",
    default = { player = false, _ = true } })
-- Player only: conceals Blizzard's PlayerCastingBarFrame. Independent of
-- castbarEnabled -- some players want both cast bars shown at once.
Settings.Define({ key = "hideBlizzardCastbar", code = "CB", scope = "frame", only = { player = true },
    type = "bool", default = false })
-- Single frames may detach their castbar (own mover); party castbars
-- dock above or below each member.
local CASTBAR_SINGLE = { player = true, target = true, targettarget = true, focus = true }
Settings.Define({ key = "castbarPosition", code = "CP", scope = "frame", only = CASTBAR_SINGLE, type = "enum",
    values = { "BELOW", "ABOVE", "DETACHED" }, default = "BELOW" })
Settings.Define({ key = "castbarDock", code = "CD", scope = "frame", only = PARTY, type = "enum",
    values = { "BELOW", "ABOVE" }, default = "BELOW" })
Settings.Define({ key = "castbarX", code = "CX", scope = "frame", only = CASTBAR_SINGLE, type = "int", min = -4000, max = 4000,
    default = { target = 300, targettarget = 480, focus = -300, _ = 0 } })
Settings.Define({ key = "castbarY", code = "CY", scope = "frame", only = CASTBAR_SINGLE, type = "int", min = -4000, max = 4000,
    default = { player = -160, focus = -170, _ = -300 } })
Settings.Define({ key = "castbarHeight", code = "CH", scope = "frame", only = CASTBAR, type = "int", min = 4, max = 60,
    default = { player = 18, target = 16, focus = 16, _ = 12 } })
Settings.Define({ key = "castbarIcon", code = "CI", scope = "frame", only = CASTBAR, type = "bool", default = true })
Settings.Define({ key = "castbarName", code = "CN", scope = "frame", only = CASTBAR, type = "bool", default = true })
Settings.Define({ key = "castbarTime", code = "CT", scope = "frame", only = CASTBAR, type = "bool", default = true })
-- Keeps an empty bar in place while nothing is cast, so what is anchored
-- below it does not jump.
Settings.Define({ key = "castbarAlwaysShow", code = "CA", scope = "frame", only = CASTBAR, type = "bool", default = false })

-- Texts. With a title row the name moves up there and the health bar
-- shows values.
Settings.Define({ key = "titleText", code = "NT", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "NAME_LEVEL", target = "NAME_LEVEL", party = "NAME_LEVEL", _ = "NAME" } })
Settings.Define({ key = "titleColorMode", code = "NC", scope = "frame", type = "enum",
    values = { "CLASS", "REACTION", "WHITE" }, default = "CLASS" })
Settings.Define({ key = "textHealthLeft", code = "TL", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "CURRENT_MAX", target = "CURRENT_MAX", focus = "NONE", party = "NONE", _ = "NAME" } })
Settings.Define({ key = "textHealthRight", code = "TR", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "PERCENT", target = "PERCENT", focus = "PERCENT", party = "PERCENT", _ = "NONE" } })
Settings.Define({ key = "textPowerLeft", code = "UL", scope = "frame", type = "enum", values = TEXT_TAGS, default = "NONE" })
Settings.Define({ key = "textPowerRight", code = "UR", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "CURRENT", _ = "NONE" } })

-- Auras. Buffs and debuffs are two groups with the same settings, each
-- configured on its own. Codes: J + letter for buffs, D + letter for
-- debuffs (the letter is the same for both groups). Anchor OTHER is the
-- other group.
Settings.AURA_GROUPS = { "buffs", "debuffs" }
Settings.POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local AURA_ANCHORS = { "FRAME", "HEALTH", "POWER", "CASTBAR", "OTHER" }
local DIRECTIONS = { "RIGHT", "LEFT", "UP", "DOWN" }
local AURA_SIZE = { party = 18, targettarget = 16, pet = 16, _ = 20 }
-- Own auras (cast by you, your pet or vehicle) are drawn this much bigger
-- by default.
local function ownSizes(sizes)
    local out = {}
    for scope, size in pairs(sizes) do out[scope] = math.floor(size * 1.3 + 0.5) end
    return out
end

-- suffix, code letter, definition without key, code and default.
local AURA_SETTINGS = {
    { "Enabled", "E", { type = "bool" } },
    { "OnlyMine", "M", { type = "bool" } },
    { "Dispellable", "V", { type = "bool" } },
    { "ShowTime", "T", { type = "bool" } },
    { "Anchor", "A", { type = "enum", values = AURA_ANCHORS } },
    { "FramePoint", "F", { type = "enum", values = Settings.POINTS } },
    { "Point", "O", { type = "enum", values = Settings.POINTS } },
    { "X", "X", { type = "int", min = -200, max = 200 } },
    { "Y", "Y", { type = "int", min = -200, max = 200 } },
    { "Growth", "G", { type = "enum", values = DIRECTIONS } },
    { "RowGrowth", "R", { type = "enum", values = DIRECTIONS } },
    { "Size", "S", { type = "int", min = 8, max = 64 } },
    { "Spacing", "D", { type = "int", min = 0, max = 20 } },
    -- 0 = Auto: as many as fit the frame's width (height when growing
    -- up or down).
    { "PerRow", "N", { type = "int", min = 0, max = 40, zeroText = "AUTO" } },
    { "Max", "C", { type = "int", min = 1, max = 40 } },
    -- Own auras first, in their own rows, at their own size.
    { "HighlightOwn", "H", { type = "bool" } },
    { "OwnSize", "B", { type = "int", min = 10, max = 64 } },
}

-- Debuffs sit above the frame, buffs above the debuffs; party auras to
-- the right of each member. Player buffs are off: Blizzard's buff frame
-- shows them.
local AURA_DEFAULTS = {
    buffs = {
        letter = "J",
        Enabled = { target = true, focus = true, party = true, _ = false },
        OnlyMine = { party = true, _ = false },
        ShowTime = true,
        Anchor = "OTHER",
        FramePoint = { party = "TOPRIGHT", _ = "TOPLEFT" },
        Point = { party = "TOPLEFT", _ = "BOTTOMLEFT" },
        X = { party = 2, _ = 0 },
        Y = { party = 0, _ = 2 },
        Growth = "RIGHT",
        RowGrowth = { party = "DOWN", _ = "UP" },
        Size = AURA_SIZE, Spacing = 2, PerRow = 0,
        Max = { party = 4, targettarget = 6, pet = 6, _ = 16 },
        HighlightOwn = false, OwnSize = ownSizes(AURA_SIZE),
    },
    debuffs = {
        letter = "D",
        Enabled = { targettarget = false, _ = true },
        OnlyMine = false,
        Dispellable = false,
        ShowTime = true,
        Anchor = "FRAME",
        FramePoint = { party = "TOPRIGHT", _ = "TOPLEFT" },
        Point = { party = "TOPLEFT", _ = "BOTTOMLEFT" },
        X = { party = 8, _ = 0 },
        Y = { party = 0, _ = 2 },
        Growth = "RIGHT",
        RowGrowth = { party = "DOWN", _ = "UP" },
        Size = AURA_SIZE, Spacing = 2, PerRow = 0,
        Max = { party = 6, targettarget = 6, pet = 6, _ = 16 },
        HighlightOwn = { target = true, focus = true, _ = false }, OwnSize = ownSizes(AURA_SIZE),
    },
}

for _, group in ipairs(Settings.AURA_GROUPS) do
    local defaults = AURA_DEFAULTS[group]
    for _, entry in ipairs(AURA_SETTINGS) do
        local suffix, letter, template = entry[1], entry[2], entry[3]
        -- A setting a group has no default for does not exist for it
        -- (only debuffs can be limited to dispellable ones).
        if defaults[suffix] ~= nil then
            local def = { key = group .. suffix, code = defaults.letter .. letter, scope = "frame",
                default = defaults[suffix] }
            for k, v in pairs(template) do def[k] = v end
            Settings.Define(def)
        end
    end
end

-- Totems (player only, Elements/Totems.lua): one icon per totem slot in a
-- row that hangs from the player's block (the frame and a docked castbar)
-- like an aura group. Right of the block by default: the shipped buffs
-- sit above the frame and the debuffs below the castbar.
local TOTEMS = { player = true }
Settings.Define({ key = "totemsEnabled", code = "QE", scope = "frame", only = TOTEMS, type = "bool", default = true })
Settings.Define({ key = "totemsSize", code = "QS", scope = "frame", only = TOTEMS, type = "int", min = 12, max = 64,
    default = 24 })
Settings.Define({ key = "totemsSpacing", code = "QD", scope = "frame", only = TOTEMS, type = "int", min = 0, max = 20,
    default = 3 })
Settings.Define({ key = "totemsFramePoint", code = "QF", scope = "frame", only = TOTEMS, type = "enum",
    values = Settings.POINTS, default = "RIGHT" })
Settings.Define({ key = "totemsPoint", code = "QO", scope = "frame", only = TOTEMS, type = "enum",
    values = Settings.POINTS, default = "LEFT" })
Settings.Define({ key = "totemsX", code = "QX", scope = "frame", only = TOTEMS, type = "int", min = -400, max = 400,
    default = 6 })
Settings.Define({ key = "totemsY", code = "QY", scope = "frame", only = TOTEMS, type = "int", min = -400, max = 400,
    default = 0 })

-- Status icons (player only, Elements/StatusIcons.lua): Blizzard's combat
-- and resting icons in a row on the player's health bar, centred on it by
-- default (above the bar's texts).
local STATUS = { player = true }
Settings.Define({ key = "statusCombat", code = "ZC", scope = "frame", only = STATUS, type = "bool", default = true })
Settings.Define({ key = "statusResting", code = "ZR", scope = "frame", only = STATUS, type = "bool", default = true })
Settings.Define({ key = "statusSize", code = "ZS", scope = "frame", only = STATUS, type = "int", min = 10, max = 48,
    default = 22 })
Settings.Define({ key = "statusFramePoint", code = "ZF", scope = "frame", only = STATUS, type = "enum",
    values = Settings.POINTS, default = "CENTER" })
Settings.Define({ key = "statusPoint", code = "ZO", scope = "frame", only = STATUS, type = "enum",
    values = Settings.POINTS, default = "CENTER" })
Settings.Define({ key = "statusX", code = "ZX", scope = "frame", only = STATUS, type = "int", min = -400, max = 400,
    default = 0 })
Settings.Define({ key = "statusY", code = "ZY", scope = "frame", only = STATUS, type = "int", min = -400, max = 400,
    default = 0 })

-- Raid target markers (Elements/RaidMarker.lua): on every frame, centred
-- on the frame's top edge by default, clear of the class badge on the top
-- right corner.
Settings.Define({ key = "raidMarker", code = "RE", scope = "frame", type = "bool", default = true })
Settings.Define({ key = "raidMarkerSize", code = "RS", scope = "frame", type = "int", min = 8, max = 64,
    default = { targettarget = 16, pet = 16, _ = 20 } })
Settings.Define({ key = "raidMarkerFramePoint", code = "RF", scope = "frame", type = "enum",
    values = Settings.POINTS, default = "TOP" })
Settings.Define({ key = "raidMarkerPoint", code = "RO", scope = "frame", type = "enum",
    values = Settings.POINTS, default = "CENTER" })
Settings.Define({ key = "raidMarkerX", code = "RX", scope = "frame", type = "int", min = -200, max = 200,
    default = 0 })
Settings.Define({ key = "raidMarkerY", code = "RY", scope = "frame", type = "int", min = -200, max = 200,
    default = 0 })

-- Group icons (player and party, Elements/GroupIcons.lua): leader or
-- assistant, ready check and incoming resurrection, each group on its own
-- switch, in one row at the frame's top left corner by default.
local GROUP = { player = true, party = true }
Settings.Define({ key = "groupLeader", code = "LL", scope = "frame", only = GROUP, type = "bool", default = true })
Settings.Define({ key = "groupReadyCheck", code = "LR", scope = "frame", only = GROUP, type = "bool", default = true })
Settings.Define({ key = "groupResurrect", code = "LZ", scope = "frame", only = GROUP, type = "bool", default = true })
Settings.Define({ key = "groupIconSize", code = "LS", scope = "frame", only = GROUP, type = "int", min = 8, max = 48,
    default = 16 })
Settings.Define({ key = "groupIconFramePoint", code = "LF", scope = "frame", only = GROUP, type = "enum",
    values = Settings.POINTS, default = "TOPLEFT" })
Settings.Define({ key = "groupIconPoint", code = "LO", scope = "frame", only = GROUP, type = "enum",
    values = Settings.POINTS, default = "LEFT" })
Settings.Define({ key = "groupIconX", code = "LX", scope = "frame", only = GROUP, type = "int", min = -200, max = 200,
    default = 2 })
Settings.Define({ key = "groupIconY", code = "LY", scope = "frame", only = GROUP, type = "int", min = -200, max = 200,
    default = 0 })

-- Range fading (Elements/Range.lua): party members and their pets, the
-- target, the focus and the pet at a lower opacity while out of range.
local RANGE = { party = true, target = true, focus = true, pet = true }
-- On everywhere: every class measures enemies, by a spell or in yards.
Settings.Define({ key = "rangeFade", code = "VE", scope = "frame", only = RANGE, type = "bool", default = true })
Settings.Define({ key = "rangeAlpha", code = "VA", scope = "frame", only = RANGE, type = "int", min = 0, max = 100,
    default = 50 })
-- How range is measured, for friends and for enemies (General only):
-- AUTO is the spell, or yards when there is none; SPELL the spell only;
-- YARDS the distance in yards. Stored by index: append only.
-- The spell fields take a name or a spell ID; empty is the class's own
-- (Range.CLASS_SPELLS).
local RANGE_MODES = { "AUTO", "SPELL", "YARDS" }
Settings.Define({ key = "rangeFriendlyMode", code = "VG", scope = "general", type = "enum", values = RANGE_MODES,
    default = "AUTO" })
Settings.Define({ key = "rangeFriendlySpell", code = "VF", scope = "general", type = "text", default = "" })
Settings.Define({ key = "rangeFriendlyYards", code = "VY", scope = "general", type = "int", min = 5, max = 40,
    default = 40 })
Settings.Define({ key = "rangeHostileMode", code = "VK", scope = "general", type = "enum", values = RANGE_MODES,
    default = "AUTO" })
Settings.Define({ key = "rangeHostileSpell", code = "VH", scope = "general", type = "text", default = "" })
Settings.Define({ key = "rangeHostileYards", code = "VZ", scope = "general", type = "int", min = 5, max = 40,
    default = 30 })

-- Threat glow (Elements/Threat.lua): the unit's own threat on the player,
-- party and pet frames, your threat on it on the others.
Settings.Define({ key = "threatGlow", code = "TH", scope = "frame", type = "bool",
    default = { player = true, party = true, _ = false } })

-- Dispel highlight (Elements/Dispel.lua): the border of the player and
-- party frames tints while the unit has a debuff you can dispel.
Settings.Define({ key = "dispelHighlight", code = "HD", scope = "frame", only = { player = true, party = true },
    type = "bool", default = true })

-- Minimap button (Options/MinimapButton.lua): General only. The angle
-- around the minimap in degrees, counter-clockwise from the right (225:
-- bottom left, LibDBIcon's default); set by dragging the button.
Settings.Define({ key = "minimapShow", code = "MS", scope = "general", type = "bool", default = true })
Settings.Define({ key = "minimapAngle", code = "MA", scope = "general", type = "int", min = 0, max = 359,
    default = 225 })

-- Language of every text (Core/Locale.lua): AUTO follows the game. Stored
-- by index: append only. Personal: an imported profile keeps the reader's
-- own language (Config.Import). inNav: its control sits at the bottom of
-- the options window's navigation, on no page.
Settings.Define({ key = "language", code = "LN", scope = "general", type = "enum", personal = true, inNav = true,
    values = { "AUTO", "enUS", "deDE", "esES", "frFR" }, default = "AUTO" })
