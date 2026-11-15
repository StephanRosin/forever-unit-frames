local _, ns = ...

-- Fonts and bar textures. Settings store the *name*, never the path, so a
-- profile survives when files move. LibSharedMedia is used if another addon
-- loaded it; we do not ship it.
local Media = {}
ns.Media = Media

local ADDON = "Interface\\AddOns\\ForeverUnitFrames\\Media\\"
local builtin = {
    font = {
        -- The client's own standard font: FRIZQT__ on western clients, a font
        -- with Hangul/Hanzi/Cyrillic elsewhere (Blizzard_Fonts_Shared GameFonts.xml).
        ["Friz Quadrata"] = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
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
-- The themes' fonts (Latin letters only) and bar textures come with the
-- embedded LibForeverThemes, which also loads its fonts early. Paths are
-- asked at use: a newer copy of the library loading after us has its own.
local Lib = LibForeverThemes
-- Console and Pitwall use Swiss's bar: their dashed and LED bars looked broken here.
local THEME_BARS = {}
for _, name in ipairs({ "Wood", "Tech", "Parchment", "Stone", "Glass", "Comic", "Frost", "Pixel", "Swiss" }) do
    THEME_BARS["FUF " .. name] = name .. "Bar"
end
local function themed(kind, name)
    if kind == "font" then return Lib.FontPath(name) end
    return THEME_BARS[name] and Lib.Texture(THEME_BARS[name])
end
local function themedNames(kind)
    local names = {}
    if kind == "font" then
        for _, f in ipairs(Lib.FONTS) do names[#names + 1] = f.name end
    elseif kind == "statusbar" then
        for name in pairs(THEME_BARS) do names[#names + 1] = name end
    end
    return names
end
local fallback = { font = "Friz Quadrata", statusbar = "Flat" }

local function lsm()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

local function fetch(kind, name)
    local path = builtin[kind][name] or themed(kind, name)
    if path then return path end
    local lib = lsm()
    if lib and name and lib:IsValid(kind, name) then return lib:Fetch(kind, name) end
    return builtin[kind][fallback[kind]]
end

function Media.Font(name) return fetch("font", name) end
function Media.StatusBar(name) return fetch("statusbar", name) end
-- Our own 64 px icons (tools/art/icons): Blizzard's atlases for these are
-- 11-21 px and blur when scaled; their -2x versions are not in the client.
function Media.Icon(name) return ADDON .. "Icon" .. name .. ".tga" end

function Media.List(kind)
    local names, seen = {}, {}
    for name in pairs(builtin[kind]) do names[#names + 1] = name; seen[name] = true end
    for _, name in ipairs(themedNames(kind)) do names[#names + 1] = name; seen[name] = true end
    local lib = lsm()
    if lib then
        for _, name in ipairs(lib:List(kind)) do
            if not seen[name] then names[#names + 1] = name end
        end
    end
    table.sort(names)
    return names
end
