-- The framed themes Azeroth and Goblin (LibForeverThemes 10): a material
-- frame outside the ring with the ornaments on its corners; Azeroth's
-- title and footer rows in dark ink on its light parchment, the bars'
-- texts light and outlined; no banner on a unit frame, but on the Smart
-- Buffs window (Azeroth's red one, Goblin's stripes) and the raid panels'
-- titles. Classic afterwards: no frame, no banner.
local M = H.M
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.units.player = { name = "Me", class = "PRIEST", className = "Priest", isPlayer = true, auras = {} }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Themes, Config, Lib = ns.Themes, ns.Config, LibForeverThemes
local f = ns.Frames.player
local function file(tex) return tex._texture and tex._texture:match("[^\\]+$") end
local function rgb(c) return string.format("%.3f,%.3f,%.3f", c[1], c[2], c[3]) end
local function restyle()
    M.RunTimers()
    ns.Single.StyleAll(f)
    ns.Texts.Update(f)
end

-- Their files ship with the library.
for _, id in ipairs({ "AZEROTH", "GOBLIN" }) do
    local art = Themes.SPECS[id].art
    for _, name in ipairs({ art.frame, art.banner, art.bannerEnd }) do
        H.checkTrue(id .. ": " .. name .. ".tga shipped",
            H.ReadFile("Libs/LibForeverThemes/Media/Themes/" .. name .. ".tga"))
    end
    for _, code in ipairs({ "enUS", "deDE", "esES", "frFR", "koKR" }) do
        local L = ns.Locales[code]
        H.checkTrue(code .. " " .. id .. ": named", L["ENUM_theme_" .. id] and L["RAID_ENUM_cellTheme_" .. id])
        local colour = L["THEME_COLOR_" .. id .. "_" .. Themes.Colors(id)[1]]
        H.checkTrue(code .. " " .. id .. ": colour named", colour and not colour:find("ß"))
    end
end

-- Azeroth on a unit frame.
H.checkTrue("azeroth: switch", Themes.Switch("AZEROTH"))
restyle()
local framed = 0
for _, strip in ipairs(f.themeFrame) do
    if strip:IsShown() and file(strip) == "WoodHDWalnut" then framed = framed + 1 end
end
H.check("azeroth: walnut frame on four sides", framed, 4)
local extent = ns.Border.Extent("player")
local _, _, _, x, y = f.themeFrame[1]:GetPoint(1)
H.check("azeroth: frame outside the ring", x .. "/" .. y, -(extent + 5) .. "/" .. (extent + 5))
H.check("azeroth: block frame waits for a docked castbar", f.themeBlockFrame[1]:IsShown(), false)
local _, _, _, ox = f.themeOrnaments[1]:GetPoint(1)
H.check("azeroth: gold corners on the frame's corners", file(f.themeOrnaments[1]) .. " " .. ox,
    "Bracket " .. -(extent + 5))
H.check("azeroth: no banner on a unit frame", f.themeBanner, nil)
local ink = Themes.SPECS.AZEROTH.ink
local mode = Config.Get("player", "titleColorMode")
local cr, cg, cb = ns.Health.UnitColor("player", mode, "player")
local inked = mode == "WHITE" and ink or { Themes.InkColor(cr, cg, cb, ink) }
H.check("azeroth: the name's colour in ink", rgb({ f.texts.title:GetTextColor() }), rgb(inked))
H.check("azeroth: the name without an outline", select(3, f.texts.title:GetFont()), "")
H.check("azeroth: health text light", rgb({ f.texts.healthRight:GetTextColor() }), "1.000,1.000,1.000")
H.check("azeroth: health text outlined", select(3, f.texts.healthRight:GetFont()), "OUTLINE")
-- A title row with a background of its own: its texts stay light.
Config.Set("general", "titleBackground", true)
Config.Set("general", "backgroundColor", { 0, 0, 0, 0.8 })
restyle()
H.check("azeroth, dark title row: light name", select(3, f.texts.title:GetFont()), "OUTLINE")
Config.Set("general", "backgroundColor", { 0, 0, 0, 0 })
Config.Set("general", "titleBackground", false)

-- Colours in ink: white and grey are the ink, yellow amber, the rest
-- darkened to a readable luminance, a secret one the ink.
H.check("ink: white", rgb({ Themes.InkColor(1, 1, 1, ink) }), rgb(ink))
local r, g, b = Themes.InkColor(1, 1, 0, ink)
H.checkTrue("ink: yellow amber, not olive", r > g and r < 0.5 and b == 0)
r, g = Themes.InkColor(0.25, 0.75, 0.25, ink)
H.checkTrue("ink: green darkened, still green", g > r and g < 0.4)
H.check("ink: dark already, as it is", rgb({ Themes.InkColor(0.1, 0.2, 0.05, ink) }), "0.100,0.200,0.050")
H.check("ink: secret", rgb({ Themes.InkColor(M.Secret(1), M.Secret(0), M.Secret(0), ink) }), rgb(ink))

-- Goblin: copper frame, light outlined texts (its soot is dark).
H.checkTrue("goblin: switch", Themes.Switch("GOBLIN"))
restyle()
H.check("goblin: copper frame", f.themeFrame[1]:IsShown() and file(f.themeFrame[1]), "GoblinCopper")
H.check("goblin: rivets", file(f.themeOrnaments[1]), "Rivet")
H.check("goblin: light name, outlined", select(3, f.texts.title:GetFont()), "OUTLINE")

H.checkTrue("classic: switch", Themes.Switch("CLASSIC"))
restyle()
H.check("classic: no frame", f.themeFrame[1]:IsShown(), false)
H.check("classic: name light", rgb({ f.texts.title:GetTextColor() }) ~= rgb(ink), true)

-- The Smart Buffs window (raid test mode shows it): Azeroth's banner
-- behind its header, the title in gold and the gear past the banner's
-- ends, the blocks below it; Goblin's stripes in the padding.
local RC, Win = ns.RaidConfig, ns.RaidBuffWindow
M.known[1243] = true
ns.RaidTestMode.Set(true)
M.Tick(1)
local w = Win.frame
local plainTop = Win.Top()
RC.Set("general", "cellTheme", "AZEROTH")
M.Tick(1)
local banner = w.themeBanner
H.check("window azeroth: banner", banner.band:IsShown() and file(banner.band), "AzerothBanner")
H.check("window azeroth: banner as high as title and padding", banner.band:GetHeight(),
    Win.HEADER_H + 2 * Win.PADDING)
H.check("window azeroth: its ends, the right one mirrored", banner.ends[1]:IsShown() and banner.ends[2]._texCoord[1], 1)
local endW = banner.ends[1]:GetWidth()
H.check("window azeroth: title past the end", select(4, Win.title:GetPoint(1)), Win.PADDING + endW)
H.check("window azeroth: title gold", rgb({ Win.title:GetTextColor() }), "1.000,0.820,0.000")
H.check("window azeroth: no rule", Win.rule:IsShown(), false)
H.check("window azeroth: blocks below the banner", Win.Top(), plainTop + Win.PADDING)
local Names = ns.RaidBuffNames
local line = Names.Pack({ { name = "Ann", class = "PRIEST", missing = true, reach = true } }, 200,
    function() return 1 end, ink)[1]
H.check("window azeroth: a white name in ink", line, ("|cff%02x%02x%02xAnn|r"):format(ink[1] * 255, ink[2] * 255,
    ink[3] * 255))
RC.Set("general", "cellTheme", "GOBLIN")
M.Tick(1)
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
