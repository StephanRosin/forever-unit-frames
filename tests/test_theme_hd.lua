-- The HD themes (LibForeverThemes' WOOD_HD …, Lib.Specs(own, true)): each
-- is its base theme's unit-frame part over a finer backdrop of its own in
-- every colour, drawn white at the base's alpha; a first switch seeds from
-- Classic with the base's shipped look; every language names them.
local M = H.M
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Lib = LibForeverThemes
local Themes, Config = ns.Themes, ns.Config
local PATH = "Interface\\AddOns\\ForeverUnitFrames\\Libs\\LibForeverThemes\\Media\\Themes\\"
local HD = { WOOD_HD = "WOOD", TECH_HD = "TECH", PARCHMENT_HD = "PARCHMENT", RUNESTONE_HD = "RUNESTONE",
    GLASS_HD = "GLASS", COMIC_HD = "COMIC", FROST_HD = "FROST" }

local texture = CreateFrame("Frame"):CreateTexture()
local function paint(id)
    ns.ThemeArt.Paint(texture, Themes.SPECS[id])
    return texture._texture .. " " .. table.concat(texture._color, ",")
end

for id, base in pairs(HD) do
    local spec, own = Themes.SPECS[id], Themes.SPECS[base]
    H.checkTrue(id .. ": offered", spec)
    H.check(id .. ": base", Lib.BaseTheme(id), base)
    H.checkTrue(id .. ": the base's look", ns.SameValue(spec.look, own.look))
    H.check(id .. ": the base's bar and font", tostring(spec.bar) .. " " .. tostring(spec.font),
        tostring(own.bar) .. " " .. tostring(own.font))
    H.check(id .. ": the base's ornament", tostring(spec.art.ornament), tostring(own.art.ornament))
    H.check(id .. ": finer tile", spec.art.tile, Lib.TILE_HD)
    local alpha = own.art.tint and own.art.tint[4] or 1
    for _, c in ipairs(Themes.Colors(id)) do
        Themes.SetColor(c, id)
        H.check(id .. " " .. c .. ": its own backdrop, white at the base's alpha", paint(id),
            PATH .. Lib.Colour(id, c).texture .. " 1,1,1," .. alpha)
        H.checkTrue(id .. " " .. c .. ": backdrop shipped",
            H.ReadFile("Libs/LibForeverThemes/Media/Themes/" .. Lib.Colour(id, c).texture .. ".tga"))
    end
    Themes.SetColor(Themes.Colors(id)[1], id)
    for _, code in ipairs({ "enUS", "deDE", "esES", "frFR", "koKR" }) do
        local L = ns.Locales[code]
        H.check(code .. " " .. id .. ": named as its base, HD", L["ENUM_theme_" .. id], L["ENUM_theme_" .. base] .. " HD")
        H.check(code .. " " .. id .. ": cell theme named", L["RAID_ENUM_cellTheme_" .. id], L["ENUM_theme_" .. id])
        for _, c in ipairs(Themes.Colors(id)) do
            local name = L["THEME_COLOR_" .. id .. "_" .. c]
            H.checkTrue(code .. " " .. id .. " " .. c .. ": colour named", name and name ~= "" and not name:find("ß"))
            local same = L["THEME_COLOR_" .. base .. "_" .. c]
            if same then H.check(code .. " " .. id .. " " .. c .. ": as the base's", name, same) end
        end
    end
end

-- First switch: Classic's layout, the base's look and shipped preset; the
-- stored sets and REVISION stay.
ns.THEME_PRESETS = { WOOD = { general = { backgroundColor = { 0.1, 0.2, 0.3, 0.4 } } } }
local sets = ns.UnitProfiles.ThemeSets()
local revision = sets.revision
Config.Set("player", "x", -123)
H.checkTrue("wood hd: switch", Themes.Switch("WOOD_HD"))
H.check("wood hd: theme", Themes.Current(), "WOOD_HD")
H.check("wood hd: classic's position", Config.Get("player", "x"), -123)
H.checkTrue("wood hd: wood's shipped background",
    ns.SameValue(Config.Get("general", "backgroundColor"), { 0.1, 0.2, 0.3, 0.4 }))
H.check("wood hd: wood's bar", Config.Get("general", "barTexture"), "FUF Wood")
H.checkTrue("wood hd: classic kept", sets.CLASSIC)
H.check("wood hd: revision untouched", sets.revision, revision)
H.checkTrue("comic hd: switch", Themes.Switch("COMIC_HD"))
H.check("comic hd: comic's outline", Config.Get("general", "fontOutline"), "THICKOUTLINE")
H.checkTrue("comic hd noir: set", Themes.SetColor("NOIR"))
H.check("comic hd noir: its paper as drawn", paint("COMIC_HD"), PATH .. "ComicHDNoir 1,1,1,1")
H.checkTrue("back to classic", Themes.Switch("CLASSIC"))
H.check("classic: own position", Config.Get("player", "x"), -123)
