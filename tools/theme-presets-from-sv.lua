-- Prints the THEME_PRESETS body for Core/Preset.lua from a saved profile's
-- theme sets: per theme, what the stored set shows differently from a
-- fresh seed of that theme on the same profile's CLASSIC set. Never what
-- places a frame (positions, anchors, offsets, frame sizes) and never
-- what is personal (language, block lists, spell names, macros).
--   cd tests && SV=<ForeverUnitFrames.lua> [PROFILE=<name>] lua5.1 -e "ADDONDIR='<repo>'" ../tools/theme-presets-from-sv.lua
-- PROFILE defaults to the profile the characters use (it must be one).
local H = dofile("harness.lua")
local ns = H.LoadShipped()
ns.THEME_PRESETS = {}
dofile(assert(os.getenv("SV"), "SV=<saved variables file> required"))
local db = ForeverUnitFramesDB

local name = os.getenv("PROFILE")
if not name then
    for _, chosen in pairs(db.active or {}) do
        assert(not name or name == chosen, "characters use several profiles: PROFILE=<name> required")
        name = chosen
    end
end
local live = assert(db.profiles[name or "Default"], "no such profile")
local sets = assert(db.themeSets and db.themeSets[name or "Default"], "the profile has no theme sets")
local S, Config, Themes = ns.Settings, ns.Config, ns.Themes
assert(not LibForeverThemes.NeedsReseed(sets, Themes.REVISION), "theme sets of another REVISION: they no longer match a seed")
local classic = S.Sanitise(assert(sets[Themes.CLASSIC], "no CLASSIC set"))

local skip = { theme = true, width = true, height = true }
for _, key in ipairs(Themes.PlacementKeys()) do skip[key] = true end
for _, def in ipairs(S.All()) do
    if def.personal or def.type == "text" then skip[def.key] = true end
end

local function literal(v)
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) == "table" then return string.format("{ %s, %s, %s, %s }", v[1], v[2], v[3], v[4]) end
    return tostring(v)
end

-- A frame value that follows General in the stored set is General's
-- difference, not the frame's.
local function differs(set, seeded, scope, def)
    local key = def.key
    if scope ~= "general" and def.scope == "inherit" and set[scope][key] == nil then return false end
    return not ns.SameValue(Config.ValueIn(set, scope, key), Config.ValueIn(seeded, scope, key))
end

local out = {}
for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
    local stored = id == live.general.theme and live or sets[id]
    if id ~= Themes.CLASSIC and type(stored) == "table" then
        local set = S.Sanitise(stored)
        local seeded = S.Sanitise(Themes.Seed(id, classic))
        local lines = {}
        for _, scope in ipairs(S.SCOPES) do
            local keys = {}
            for _, def in ipairs(S.All()) do
                if not skip[def.key] and S.AppliesTo(def, scope) and differs(set, seeded, scope, def) then
                    keys[#keys + 1] = def.key
                end
            end
            table.sort(keys)
            if #keys > 0 then
                lines[#lines + 1] = "        " .. scope .. " = {"
                for _, k in ipairs(keys) do
                    lines[#lines + 1] = "            " .. k .. " = " .. literal(Config.ValueIn(set, scope, k)) .. ","
                end
                lines[#lines + 1] = "        },"
            end
        end
        if #lines > 0 then
            out[#out + 1] = "    " .. id .. " = {"
            for _, l in ipairs(lines) do out[#out + 1] = l end
            out[#out + 1] = "    },"
        end
    end
end
print(table.concat(out, "\n"))
