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
        -- The themes' fonts (Core/Themes.lua), Latin letters only; licences
        -- in Media/Fonts.
        ["Bangers"] = ADDON .. "Fonts\\Bangers-Regular.ttf",
        ["Cinzel"] = ADDON .. "Fonts\\Cinzel-Bold.ttf",
        ["IM Fell English SC"] = ADDON .. "Fonts\\IMFeENsc28P.ttf",
        ["Marcellus"] = ADDON .. "Fonts\\Marcellus-Regular.ttf",
        ["Space Grotesk"] = ADDON .. "Fonts\\SpaceGrotesk-Bold.ttf",
        ["VT323"] = ADDON .. "Fonts\\VT323-Regular.ttf",
        -- Body faces of Swiss, Console, Pitwall: one face per frame, so
        -- the readable text face, not the titles' display face.
        ["Inter Tight"] = ADDON .. "Fonts\\InterTight-Regular.ttf",
        ["IBM Plex Mono"] = ADDON .. "Fonts\\IBMPlexMono-Regular.ttf",
        ["Titillium Web"] = ADDON .. "Fonts\\TitilliumWeb-SemiBold.ttf",
    },
    statusbar = {
        ["Flat"] = "Interface\\Buttons\\WHITE8X8",
        ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
        ["Raid"] = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    },
}
-- The themes' bar textures (tools/make_themes.py). Console and Pitwall
-- use Swiss's: their dashed and LED bars looked broken here.
for _, name in ipairs({ "Wood", "Tech", "Parchment", "Stone", "Glass", "Comic", "Frost", "Pixel", "Swiss" }) do
    builtin.statusbar["FUF " .. name] = ADDON .. "Themes\\" .. name .. "Bar.tga"
end
local fallback = { font = "Friz Quadrata", statusbar = "Flat" }

-- Our own font files loaded while the addon loads: a file used for the
-- first time can be refused (Elements/Texts.lua tries again), so the
-- first restyle should not be its first use.
do
    local holder = CreateFrame("Frame")
    holder:Hide()
    for _, path in pairs(builtin.font) do
        if path:find(ADDON, 1, true) then
            holder:CreateFontString():SetFont(path, 12, "")
        end
    end
end

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
