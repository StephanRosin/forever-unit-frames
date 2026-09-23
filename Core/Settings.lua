local _, ns = ...

-- The one list of every setting. Config, Codec, the options window and the
-- tests all read from here. A setting's `code` is written into saved and
-- exported strings: once released it must never change or be reused.
local Settings = {}
ns.Settings = Settings

Settings.SCOPES = { "general", "player", "target" }
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

function Settings.AppliesTo(def, scope)
    if scope == "general" then return def.scope ~= "frame" end
    return def.scope ~= "general"
end

local function inList(values, v)
    for i = 1, #values do if values[i] == v then return true end end
    return false
end

function Settings.Validate(def, v)
    local t = def.type
    if t == "int" then
        if type(v) ~= "number" then return nil end
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
Settings.Define({ key = "fontFace", code = "FF", scope = "inherit", type = "media", mediaKind = "font", default = "Friz Quadrata" })
Settings.Define({ key = "fontSize", code = "FS", scope = "inherit", type = "int", min = 6, max = 32, default = 12 })
Settings.Define({ key = "fontOutline", code = "FO", scope = "inherit", type = "enum",
    values = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME" }, default = "OUTLINE" })
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
    default = { player = 220, target = 220, _ = 120 } })
Settings.Define({ key = "height", code = "H", scope = "frame", type = "int", min = 8, max = 200,
    default = { player = 46, target = 46, _ = 28 } })
Settings.Define({ key = "healthPercent", code = "HP", scope = "frame", type = "int", min = 10, max = 100, default = 75 })
Settings.Define({ key = "powerPercent", code = "PP", scope = "frame", type = "int", min = 0, max = 90, default = 25 })
Settings.Define({ key = "powerEnabled", code = "PE", scope = "frame", type = "bool", default = true })
Settings.Define({ key = "x", code = "X", scope = "frame", type = "int", min = -4000, max = 4000,
    default = { player = -300, target = 300, _ = 0 } })
Settings.Define({ key = "y", code = "Y", scope = "frame", type = "int", min = -4000, max = 4000,
    default = { player = -220, target = -220, _ = 0 } })

-- Texts
Settings.Define({ key = "textHealthLeft", code = "TL", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "NAME_LEVEL", target = "NAME_LEVEL", _ = "NAME" } })
Settings.Define({ key = "textHealthRight", code = "TR", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "CURRENT_MAX", target = "PERCENT", _ = "NONE" } })
Settings.Define({ key = "textPowerLeft", code = "UL", scope = "frame", type = "enum", values = TEXT_TAGS, default = "NONE" })
Settings.Define({ key = "textPowerRight", code = "UR", scope = "frame", type = "enum", values = TEXT_TAGS,
    default = { player = "CURRENT", _ = "NONE" } })
