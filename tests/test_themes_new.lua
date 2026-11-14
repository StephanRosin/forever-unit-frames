-- Swiss, Console and Pitwall (Core/Themes.lua, Elements/ThemeArt.lua):
-- their look, body font and art on a unit frame; their colours keep the
-- backdrop and paint the art (Swiss accent, Console ring, Pitwall wedge);
-- Pixel's Handheld; Classic untouched; raid cells follow.
local M = H.M
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Themes, Config, C = ns.Themes, ns.Config, ns.Config
local PATH = "Interface\\AddOns\\ForeverUnitFrames\\Media\\Themes\\"
local f = ns.Frames.player
local function rgb(c) return string.format("%.3f,%.3f,%.3f,%.3f", c[1], c[2], c[3], c[4] or 1) end
local function restyle()
    M.RunTimers()
    ns.Single.StyleAll(f)
end

H.check("appended after pixel", table.concat(Themes.IDS, ",", 9), "PIXEL,SWISS,CONSOLE,PITWALL")
H.check("cell themes appended", table.concat(ns.RaidSettings.Get("cellTheme").values, ",", 10),
    "PIXEL,SWISS,CONSOLE,PITWALL")

-- Every theme's files are there: backdrop, bar, ornament, font.
for _, id in ipairs(Themes.IDS) do
    local spec = Themes.SPECS[id]
    local art = spec.art or {}
    for _, name in ipairs({ art.back, art.ornament }) do
        H.checkTrue(id .. ": " .. name .. ".tga shipped", H.ReadFile("Media/Themes/" .. name .. ".tga"))
    end
    if spec.bar then
        local file = ns.Media.StatusBar(spec.bar):gsub("^Interface\\AddOns\\ForeverUnitFrames\\", ""):gsub("\\", "/")
        H.checkTrue(id .. ": bar registered and shipped", file:find("^Media/") and H.ReadFile(file))
    end
    if spec.font and not ns.Media.Font(spec.font):find("^Fonts\\") then
        local file = ns.Media.Font(spec.font):gsub("^Interface\\AddOns\\ForeverUnitFrames\\", ""):gsub("\\", "/")
        H.checkTrue(id .. ": font registered and shipped", file:find("^Media/Fonts/") and H.ReadFile(file))
    end
end
H.check("swiss: the body face", ns.Media.Font("Inter Tight"):match("[^\\]+$"), "InterTight-Regular.ttf")
H.check("console: the body face", ns.Media.Font("IBM Plex Mono"):match("[^\\]+$"), "IBMPlexMono-Regular.ttf")
H.check("pitwall: the body face", ns.Media.Font("Titillium Web"):match("[^\\]+$"), "TitilliumWeb-SemiBold.ttf")

-- Swiss and Pitwall share one black with every Forever addon: the flat
-- backdrop untinted and the background (the tracks) #0a0a0a, opaque.
for _, id in ipairs({ "SWISS", "PITWALL" }) do
    local spec = Themes.SPECS[id]
    H.check(id .. ": the shared black", spec.art.back .. " " .. rgb(Themes.Tint(spec) or { 1, 1, 1, 1 }) .. " "
        .. rgb(spec.look.backgroundColor), "SwissBack 1.000,1.000,1.000,1.000 0.039,0.039,0.039,1.000")
end

-- Classic as it is, to compare after the round trip.
local classic = {}
for _, key in ipairs({ "fontFace", "barTexture", "borderStyle", "fontSize", "borderPadding" }) do
    classic[key] = tostring(Config.Get("player", key))
end
local size = Config.Get("general", "fontSize")

-- Swiss: flat black, hairline ring, a white rule on top, a red accent on it.
H.checkTrue("swiss: switch", Themes.Switch("SWISS"))
restyle()
H.check("swiss: font", Config.Get("player", "fontFace"), "Inter Tight")
H.check("swiss: no larger font", Config.Get("general", "fontSize"), size)
H.check("swiss: bar", Config.Get("player", "barTexture"), "FUF Swiss")
H.check("swiss: hairline ring", rgb(f.frameRing.border[1]._color), "0.165,0.165,0.165,1.000")
H.check("swiss: black track", rgb(Config.Get("player", "backgroundColor")), "0.039,0.039,0.039,1.000")
H.check("swiss: backdrop", f.themeBack._texture, PATH .. "SwissBack")
H.check("swiss: no solid shadow", f.themeShadow:IsShown(), false)
H.check("swiss: rule shown", f.themeRule:IsShown(), true)
H.check("swiss: rule white", rgb(f.themeRule._color), "0.949,0.949,0.949,1.000")
H.check("swiss: rule 3 px", f.themeRule:GetHeight(), ns.Pixel.Snap(3, nil, 1))
H.check("swiss: accent top left only", tostring(f.themeOrnaments[1]:IsShown()) .. " "
    .. tostring(f.themeOrnaments[2]:IsShown()), "true false")
H.check("swiss: accent red", rgb(f.themeOrnaments[1]._color), "1.000,0.176,0.125,1.000")
H.check("swiss: accent a short bar", f.themeOrnaments[1]:GetWidth() .. "x" .. f.themeOrnaments[1]:GetHeight(), "12x3")
H.check("swiss: colours", table.concat(Themes.Colors(), ","), "RED,BLUE,YELLOW,WHITE")
H.checkTrue("swiss blue: set", Themes.SetColor("BLUE"))
restyle()
H.check("swiss blue: accent", rgb(f.themeOrnaments[1]._color), "0.176,0.420,1.000,1.000")
H.check("swiss blue: backdrop kept", f.themeBack._texture .. " " .. rgb(f.themeBack._color),
    PATH .. "SwissBack 1.000,1.000,1.000,1.000")
H.check("swiss blue: rule stays white", rgb(f.themeRule._color), "0.949,0.949,0.949,1.000")

-- Console: scan lines, a mint ring that follows the colour, no ornaments.
H.checkTrue("console: switch", Themes.Switch("CONSOLE"))
restyle()
H.check("console: font", Config.Get("player", "fontFace"), "IBM Plex Mono")
H.check("console: no larger font", Config.Get("general", "fontSize"), size)
H.check("console: bar", Config.Get("player", "barTexture"), "FUF Swiss")
H.check("console: backdrop", f.themeBack._texture, PATH .. "ConsoleBack")
H.check("console: mint ring", rgb(f.frameRing.border[1]._color), "0.306,0.929,0.690,1.000")
H.check("console: no rule", f.themeRule:IsShown(), false)
H.check("console: no ornaments", f.themeOrnaments[1]:IsShown(), false)
H.check("console: swiss rule gone", f.themeBlockRule:IsShown(), false)
H.checkTrue("console amber: set", Themes.SetColor("AMBER"))
restyle()
H.check("console amber: ring", rgb(f.frameRing.border[1]._color), "1.000,0.690,0.000,1.000")
H.check("console amber: block ring", rgb(f.blockRing.border[1]._color), "1.000,0.690,0.000,1.000")
H.check("console amber: backdrop kept", f.themeBack._texture, PATH .. "ConsoleBack")
H.check("console amber: setting untouched", rgb(Config.Get("player", "borderColor")), "0.306,0.929,0.690,1.000")

-- Pitwall: calm black backdrop, the name row a black strip with the red
-- wedge at its start, solid bars on a black track, health in the player's colour.
H.checkTrue("pitwall: switch", Themes.Switch("PITWALL"))
restyle()
H.check("pitwall: font", Config.Get("player", "fontFace"), "Titillium Web")
H.check("pitwall: bar", Config.Get("player", "barTexture"), "FUF Swiss")
H.check("pitwall: flat backdrop, no weave", f.themeBack._texture, PATH .. "SwissBack")
H.check("pitwall: black track", rgb(Config.Get("player", "backgroundColor")), "0.039,0.039,0.039,1.000")
H.check("pitwall: track on the health bar", rgb(f.healthBg._color), "0.039,0.039,0.039,1.000")
H.check("pitwall: health not forced", ns.Themes.SPECS.PITWALL.look.healthColorMode, nil)
H.check("pitwall: no corner wedge", f.themeOrnaments[1]:IsShown(), false)
H.check("pitwall: title strip", f.title._texture .. " " .. rgb(f.title._color),
    "Interface\\Buttons\\WHITE8X8 0.000,0.000,0.000,1.000")
local wedge = f.themeWedge
H.check("pitwall: wedge shown", wedge:IsShown(), true)
H.check("pitwall: wedge texture", wedge._texture, PATH .. "PitwallWedge")
H.check("pitwall: wedge red", rgb(wedge._color), "0.882,0.024,0.000,1.000")
local function anchor(region, n)
    local point, rel, relPoint = region:GetPoint(n)
    return point .. ">" .. (rel == f.title and "title" or tostring(rel)) .. "." .. relPoint
end
H.check("pitwall: wedge at the strip's start, full height", anchor(wedge, 1) .. " " .. anchor(wedge, 2),
    "TOPLEFT>title.TOPLEFT BOTTOMLEFT>title.BOTTOMLEFT")
local indent = ns.ThemeArt.TitleIndent(f)
H.check("pitwall: wedge as wide as the title row is high", wedge:GetWidth(), f.titleHeight)
-- The family rule: the name starts 8 past the wedge's edge at mid-height.
H.check("pitwall: name 8 past the wedge", 4 + indent, math.floor(0.8 * f.titleHeight + 0.5) + 8)
local _, _, _, nameX = f.texts.title:GetPoint(1)
H.check("pitwall: the name starts after the wedge", nameX, ns.Pixel.Snap(4 + indent, f.texts.title))
H.check("pitwall: no rule", f.themeRule:IsShown(), false)
H.check("pitwall: ring unchanged by colours", Themes.Accent("PITWALL", "ring"), nil)
H.checkTrue("pitwall teal: set", Themes.SetColor("TEAL"))
restyle()
H.check("pitwall teal: wedge", rgb(f.themeWedge._color), "0.000,0.631,0.612,1.000")
H.check("pitwall teal: backdrop kept", f.themeBack._texture, PATH .. "SwissBack")
H.check("colours: each theme its own", Themes.Color("SWISS") .. " " .. Themes.Color("CONSOLE") .. " "
    .. Themes.Color(), "BLUE AMBER TEAL")

-- Pixel's Handheld: the grey texture tinted to its green.
H.checkTrue("pixel: switch", Themes.Switch("PIXEL"))
H.check("pixel: handheld last", Themes.Colors()[9], "HANDHELD")
H.checkTrue("pixel handheld: set", Themes.SetColor("HANDHELD"))
restyle()
H.check("pixel handheld: grey texture tinted", f.themeBack._texture .. " " .. rgb(f.themeBack._color),
    PATH .. "PixelBackGrey " .. rgb({ 0.059 / 0.8, 0.122 / 0.8, 0.059 / 0.8, 1 }))
H.check("pixel handheld: ring its green", rgb(f.frameRing.border[1]._color), "0.784,0.941,0.439,1.000")

-- Back to Classic: nothing of the themes stayed.
H.checkTrue("classic: switch", Themes.Switch("CLASSIC"))
restyle()
for key, value in pairs(classic) do
    H.check("classic: own " .. key, tostring(Config.Get("player", key)), value)
end
H.check("classic: no rule", f.themeRule:IsShown(), false)
H.check("classic: no ornament", f.themeOrnaments[1]:IsShown(), false)
H.check("classic: no wedge, the name back in place", tostring(f.themeWedge:IsShown()) .. " "
    .. select(4, f.texts.title:GetPoint(1)), "false " .. ns.Pixel.Snap(4, f.texts.title))
H.check("classic: title row the bar again", f.title._texture,
    ns.Media.StatusBar(Config.Get("player", "barTexture")))
H.check("classic: no colours", #Themes.Colors(), 0)

-- Raid cells in a theme of their own: its bar, body font, accent ring.
local Cell = ns.RaidCell
ns.RaidConfig.Set("general", "cellTheme", "CONSOLE")
H.check("cells: console bar", C.Get(Cell.KEY, "barTexture"), "FUF Swiss")
H.check("cells: console font", C.Get(Cell.KEY, "fontFace"), "IBM Plex Mono")
H.check("cells: amber ring", rgb(C.Get(Cell.KEY, "borderColor")), "1.000,0.690,0.000,1.000")
ns.RaidConfig.Set("general", "cellTheme", "SWISS")
H.check("cells: swiss hairline", rgb(C.Get(Cell.KEY, "borderColor")), "0.165,0.165,0.165,1.000")
H.check("cells: swiss font", C.Get(Cell.KEY, "fontFace"), "Inter Tight")
ns.RaidConfig.Set("general", "cellTheme", "PITWALL")
H.check("cells: pitwall bar", C.Get(Cell.KEY, "barTexture"), "FUF Swiss")
H.check("cells: pitwall font size as their own", C.Get(Cell.KEY, "fontSize"),
    ns.RaidConfig.Get("r10", "nameFontSize"))
H.check("no error", #M.errors, 0)
