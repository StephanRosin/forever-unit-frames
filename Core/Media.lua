local _, ns = ...

-- Fonts and bar textures. Settings store the *name*, never the path, so a
-- profile survives when files move. LibSharedMedia is used if another addon
-- loaded it; we do not ship it.
local Media = {}
ns.Media = Media

local builtin = {
    font = {
        ["Friz Quadrata"] = "Fonts\\FRIZQT__.TTF",
        ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
        ["Skurri"] = "Fonts\\skurri.ttf",
        ["Morpheus"] = "Fonts\\MORPHEUS.ttf",
    },
    statusbar = {
        ["Flat"] = "Interface\\Buttons\\WHITE8X8",
        ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
        ["Raid"] = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    },
}
local fallback = { font = "Friz Quadrata", statusbar = "Flat" }

local function lsm()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

local function fetch(kind, name)
    local path = builtin[kind][name]
    if path then return path end
    local lib = lsm()
    if lib and name and lib:IsValid(kind, name) then return lib:Fetch(kind, name) end
    return builtin[kind][fallback[kind]]
end

function Media.Font(name) return fetch("font", name) end
function Media.StatusBar(name) return fetch("statusbar", name) end

function Media.List(kind)
    local names, seen = {}, {}
    for name in pairs(builtin[kind]) do names[#names + 1] = name; seen[name] = true end
    local lib = lsm()
    if lib then
        for _, name in ipairs(lib:List(kind)) do
            if not seen[name] then names[#names + 1] = name end
        end
    end
    table.sort(names)
    return names
end
