-- A raid cell answers every unit-frame setting itself (Raid/Cell.lua):
-- what the raid profile maps, what a cell fixes, and the unit frames'
-- shipped defaults for everything else, never what the party frame or
-- General is set to. The rings around the panel and the blocks
-- (Raid/Header.lua) take the cell's answers for what they do not fix.
-- The addon as shipped: its look (Core/Preset.lua) is the default.
local ns = H.LoadShipped()
local C, Settings, Header = ns.Config, ns.Settings, ns.RaidHeader
C.Use({})
ns.RaidProfiles.Attach({})
ns.RaidSize.Update()

local SCOPES = { ns.RaidCell.KEY, Header.PANEL_SCOPE, Header.BLOCK_SCOPE }

local function text(v)
    if type(v) ~= "table" then return tostring(v) end
    return ("%s,%s,%s,%s"):format(tostring(v[1]), tostring(v[2]), tostring(v[3]), tostring(v[4]))
end

-- Every unit-frame setting as each raid scope answers it.
local function snapshot()
    local values = {}
    for _, def in ipairs(Settings.All()) do
        for _, scope in ipairs(SCOPES) do values[scope .. " " .. def.key] = text(C.Get(scope, def.key)) end
    end
    return values
end

-- A valid value other than the current one.
local function another(def, current)
    local t = def.type
    if t == "bool" then return not current end
    if t == "int" then return current == def.max and def.min or def.max end
    if t == "enum" then
        for _, v in ipairs(def.values) do
            if v ~= current then return v end
        end
    end
    if t == "color" then return current[1] == 0.5 and { 0.25, 0.5, 0.75, 1 } or { 0.5, 0.25, 0.125, 0.5 } end
    if t == "media" then return current == "Other" and "Another" or "Other" end
    if t == "text" then return current == "x" and "y" or "x" end
end

-- The shipped look before anything changes.
H.check("bar texture: the shipped one", C.Get("raid", "barTexture"), "Raid")
H.check("border style: the shipped one", C.Get("raid", "borderStyle"), "GOLD")
H.check("outline: the shipped one", C.Get("raid", "fontOutline"), "OUTLINE")

-- Every party and General setting changed.
local before = snapshot()
local changed = 0
for _, def in ipairs(Settings.All()) do
    for _, scope in ipairs({ "general", ns.Party.KEY }) do
        if Settings.AppliesTo(def, scope) and C.Set(scope, def.key, another(def, C.Get(scope, def.key))) then
            changed = changed + 1
        end
    end
end
H.check("party and General settings changed", changed, 248)
H.check("the party frame's texture did change", C.Get(ns.Party.KEY, "barTexture"), "Another")

-- Not one raid answer follows.
local after, follow = snapshot(), {}
for name, v in pairs(before) do
    if after[name] ~= v then follow[#follow + 1] = name end
end
table.sort(follow)
H.check("raid answers that follow the party frame or General", #follow, 0)
H.check("the first of them", follow[1], nil)
H.check("bar texture still the shipped one", C.Get("raid", "barTexture"), "Raid")
H.check("panel ring still gold", C.Get(Header.PANEL_SCOPE, "borderStyle"), "GOLD")
