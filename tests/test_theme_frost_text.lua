-- Frost (Core/Themes.lua): its texts have no outline, a 1 px drop shadow
-- instead; every other theme keeps its outline, Classic its own look.
local M = H.M
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Themes, Config = ns.Themes, ns.Config
local f = ns.Frames.player
local function restyle()
    M.RunTimers()
    ns.Single.StyleAll(f)
end
local function look(field)
    local fs = f.texts[field]
    local _, _, flags = fs:GetFont()
    return tostring(flags) .. " " .. table.concat(fs._shadow or {}, ",")
end

local classic = Config.Get("general", "fontOutline") .. " " .. tostring(Config.Get("general", "fontShadow"))

H.checkTrue("frost: switch", Themes.Switch("FROST"))
restyle()
for _, field in ipairs({ "title", "healthLeft", "healthRight", "powerLeft" }) do
    H.check("frost " .. field .. ": no outline, shadow", look(field), " 1,-1")
end

for _, id in ipairs(LibForeverThemes.SpecIds(Themes.SPECS)) do
    local outline = Themes.SPECS[id].look and Themes.SPECS[id].look.fontOutline
    local base = LibForeverThemes.BaseTheme(id)
    if base == "FROST" then
        H.check(id .. ": no outline in the look", outline, "NONE")
    elseif base == "COMIC" then
        H.check(id .. ": thick outline kept", outline, "THICKOUTLINE")
    elseif id ~= "CLASSIC" then
        H.check(id .. ": outline kept", outline, "OUTLINE")
    end
end

H.checkTrue("wood: switch", Themes.Switch("WOOD"))
restyle()
H.check("wood: outlined", look("title"):match("^%S+"), "OUTLINE")

H.checkTrue("classic: switch", Themes.Switch("CLASSIC"))
restyle()
H.check("classic: untouched",
    Config.Get("general", "fontOutline") .. " " .. tostring(Config.Get("general", "fontShadow")), classic)
