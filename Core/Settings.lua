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
Settings.Define({ key = "fontFace", code = "FF", scope = "inherit", type = "media", mediaKind = "font", default = "Friz Quadrata" })
Settings.Define({ key = "fontSize", code = "FS", scope = "inherit", type = "int", min = 6, max = 32, default = 12 })
Settings.Define({ key = "fontOutline", code = "FO", scope = "inherit", type = "enum",
    values = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "SOFT" }, default = "SOFT" })
Settings.Define({ key = "fontShadow", code = "FH", scope = "inherit", type = "bool", default = false })
Settings.Define({ key = "barTexture", code = "BT", scope = "inherit", type = "media", mediaKind = "statusbar", default = "Flat" })
Settings.Define({ key = "backgroundColor", code = "BC", scope = "inherit", type = "color", default = { 0, 0, 0, 0.6 } })
Settings.Define({ key = "borderSize", code = "BS", scope = "inherit", type = "int", min = 0, max = 2, default = 1 })
Settings.Define({ key = "borderColor", code = "BO", scope = "inherit", type = "color", default = { 0, 0, 0, 1 } })

-- Colors
Settings.Define({ key = "healthColorMode", code = "HM", scope = "inherit", type = "enum",
    values = { "CLASS", "REACTION", "STATIC", "GRADIENT" }, default = "CLASS" })
Settings.Define({ key = "healthColor", code = "HC", scope = "inherit", type = "color", default = { 0.2, 0.75, 0.3, 1 } })

-- Frame layout
Settings.Define({ key = "enabled", code = "E", scope = "frame", type = "bool", default = true })
Settings.Define({ key = "width", code = "W", scope = "frame", type = "int", min = 40, max = 600,
    default = { player = 220, target = 220, focus = 160, party = 160, _ = 120 } })
Settings.Define({ key = "height", code = "H", scope = "frame", type = "int", min = 8, max = 200,
    default = { player = 46, target = 46, focus = 36, party = 36, _ = 28 } })
Settings.Define({ key = "healthPercent", code = "HP", scope = "frame", type = "int", min = 10, max = 100, default = 75 })
Settings.Define({ key = "powerPercent", code = "PP", scope = "frame", type = "int", min = 0, max = 90, default = 25 })
Settings.Define({ key = "powerEnabled", code = "PE", scope = "frame", type = "bool", default = true })
Settings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000,
    default = { player = -300, target = 300, targettarget = 480, pet = -352, focus = -300, party = -760, _ = 0 } })
Settings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000,
    default = { player = -220, target = -220, targettarget = -220, pet = -272, focus = -120, party = 120, _ = 0 } })

-- Portrait
Settings.Define({ key = "portraitMode", code = "PM", scope = "frame", type = "enum",
    values = { "OFF", "LEFT", "RIGHT" }, default = "OFF" })
Settings.Define({ key = "portraitStyle", code = "PS", scope = "frame", type = "enum",
    values = { "2D", "3D" }, default = "2D" })

-- Party block (party only)
local PARTY = { party = true }
Settings.Define({ key = "partyOrientation", code = "OR", scope = "frame", only = PARTY, type = "enum",
    values = { "VERTICAL", "HORIZONTAL" }, default = "VERTICAL" })
Settings.Define({ key = "partySpacing", code = "GS", scope = "frame", only = PARTY, type = "int", min = 0, max = 60, default = 12 })
Settings.Define({ key = "partyShowPlayer", code = "SP", scope = "frame", only = PARTY, type = "bool", default = false })
Settings.Define({ key = "partyShowSolo", code = "SO", scope = "frame", only = PARTY, type = "bool", default = false })

-- Castbar (not on the pet frame; off by default on the player frame)
local CASTBAR = { player = true, target = true, targettarget = true, focus = true, party = true }
Settings.Define({ key = "castbarEnabled", code = "CE", scope = "frame", only = CASTBAR, type = "bool",
    default = { player = false, _ = true } })
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

-- Texts
Settings.Define({ key = "textHealthLeft", code = "TL", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "NAME_LEVEL", target = "NAME_LEVEL", _ = "NAME" } })
Settings.Define({ key = "textHealthRight", code = "TR", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "CURRENT_MAX", target = "PERCENT", focus = "PERCENT", party = "PERCENT", _ = "NONE" } })
Settings.Define({ key = "textPowerLeft", code = "UL", scope = "frame", type = "enum", values = TEXT_TAGS, default = "NONE" })
Settings.Define({ key = "textPowerRight", code = "UR", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "CURRENT", _ = "NONE" } })
