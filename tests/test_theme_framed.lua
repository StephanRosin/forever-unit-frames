-- The framed theme Goblin (LibForeverThemes 10): a material frame outside
-- the ring with the ornaments on its corners, light outlined texts; no
-- banner on a unit frame, but its stripes on the Smart Buffs window.
-- Classic afterwards: no frame, no banner.
local M = H.M
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.units.player = { name = "Me", class = "PRIEST", className = "Priest", isPlayer = true, auras = {} }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Themes = ns.Themes
local f = ns.Frames.player
local function file(tex) return tex._texture and tex._texture:match("[^\\]+$") end
local function rgb(c) return string.format("%.3f,%.3f,%.3f", c[1], c[2], c[3]) end
local function restyle()
    M.RunTimers()
    ns.Single.StyleAll(f)
    ns.Texts.Update(f)
end

-- Its files ship with the library.
local art = Themes.SPECS.GOBLIN.art
for _, name in ipairs({ art.frame, art.banner }) do
    H.checkTrue("goblin: " .. name .. ".tga shipped", H.ReadFile("Libs/LibForeverThemes/Media/Themes/" .. name .. ".tga"))
end
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR", "koKR" }) do
    local L = ns.Locales[code]
    H.checkTrue(code .. " goblin: named", L.ENUM_theme_GOBLIN and L.RAID_ENUM_cellTheme_GOBLIN)
    local colour = L["THEME_COLOR_GOBLIN_" .. Themes.Colors("GOBLIN")[1]]
    H.checkTrue(code .. " goblin: colour named", colour and not colour:find("ß"))
end

-- Goblin: copper frame on four sides outside the ring, rivets on its
-- corners, light outlined texts (its soot is dark).
H.checkTrue("goblin: switch", Themes.Switch("GOBLIN"))
restyle()
local framed = 0
for _, strip in ipairs(f.themeFrame) do
    if strip:IsShown() and file(strip) == "GoblinCopper" then framed = framed + 1 end
end
H.check("goblin: copper frame on four sides", framed, 4)
local extent = ns.Border.Extent("player")
local _, _, _, x, y = f.themeFrame[1]:GetPoint(1)
H.check("goblin: frame outside the ring", x .. "/" .. y, -(extent + 5) .. "/" .. (extent + 5))
H.check("goblin: block frame waits for a docked castbar", f.themeBlockFrame[1]:IsShown(), false)
H.check("goblin: no banner on a unit frame", f.themeBanner, nil)
H.check("goblin: rivets", file(f.themeOrnaments[1]), "Rivet")
H.check("goblin: light name, outlined", select(3, f.texts.title:GetFont()), "OUTLINE")

H.checkTrue("classic: switch", Themes.Switch("CLASSIC"))
restyle()
H.check("classic: no frame", f.themeFrame[1]:IsShown(), false)

-- The Smart Buffs window (raid test mode shows it): Goblin's stripes in
-- the padding, the title and the blocks where they were.
local RC, Win = ns.RaidConfig, ns.RaidBuffWindow
M.known[1243] = true
ns.RaidTestMode.Set(true)
M.Tick(1)
local w = Win.frame
local plainTop = Win.Top()
RC.Set("general", "cellTheme", "GOBLIN")
M.Tick(1)
local banner = w.themeBanner
H.check("window goblin: stripes 5 high, repeating", file(banner.band) .. " " .. banner.band:GetHeight() .. " "
    .. tostring(banner.band._horizTile), "GoblinHazard 5 true")
H.check("window goblin: no ends", banner.ends[1]:IsShown(), false)
H.check("window goblin: title in place, light", select(4, Win.title:GetPoint(1)) .. " "
    .. rgb({ Win.title:GetTextColor() }), Win.PADDING .. " 0.900,0.900,0.900")
H.check("window goblin: the rule", Win.rule:IsShown(), true)
H.check("window goblin: blocks where they were", Win.Top(), plainTop)
RC.Set("general", "cellTheme", "OWN")
M.Tick(1)
H.check("window classic: no banner", banner.band:IsShown() or banner.ends[1]:IsShown(), false)
H.check("no error", #M.errors, 0)
