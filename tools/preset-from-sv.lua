-- Prints the PRESET body for Core/Preset.lua from a saved profile: the
-- look as it stands in game (shipped preset plus the saved overrides),
-- written as differences from the plain defaults.
--   cd tests && SV=<ForeverUnitFrames.lua> lua5.1 -e "ADDONDIR='<repo>'" ../tools/preset-from-sv.lua
-- Also lists shipped preset values the profile no longer overrides, so a
-- value set back to the plain default is not silently replaced.
local H = dofile("harness.lua")
local shipped = H.LoadShipped()
dofile(assert(os.getenv("SV"), "SV=<saved variables file> required"))
local profile = ForeverUnitFramesDB.profile
profile.window = nil
shipped.Config.Use(profile)
local S = shipped.Settings

local effective = {}
for _, scope in ipairs(S.SCOPES) do
    effective[scope] = {}
    for _, def in ipairs(S.All()) do
        if S.AppliesTo(def, scope) then effective[scope][def.key] = shipped.Config.Get(scope, def.key) end
    end
end

local plain = H.LoadAddon().Settings
local function same(a, b)
    if type(a) == "table" and type(b) == "table" then
        for i = 1, 4 do if a[i] ~= b[i] then return false end end
        return true
    end
    return a == b
end
local function literal(v)
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) == "table" then return string.format("{ %s, %s, %s, %s }", v[1], v[2], v[3], v[4]) end
    return tostring(v)
end

local out = {}
for _, scope in ipairs(S.SCOPES) do
    local keys = {}
    for key, v in pairs(effective[scope]) do
        local def = plain.Get(key)
        local base
        if scope == "general" or def.scope ~= "inherit" then
            base = plain.Default(def, scope)
        else
            base = effective.general[key]
        end
        if not same(v, base) then keys[#keys + 1] = key end
    end
    table.sort(keys)
    if #keys > 0 then
        out[#out + 1] = "    " .. scope .. " = {"
        for _, k in ipairs(keys) do out[#out + 1] = "        " .. k .. " = " .. literal(effective[scope][k]) .. "," end
        out[#out + 1] = "    },"
    end
end
print(table.concat(out, "\n"))
