-- Aura icons restyled while auras are secret out of combat (an instance,
-- an encounter, a PvP match): the client refuses, and the buttons kept
-- the old font. They were tried again only when combat ended, so after
-- leaving the instance old icons kept a theme's font while new ones had
-- Classic's: the same aura in two fonts (reported on CurseForge, 0.55.0).
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.units.target = { name = "Foe", health = 5, healthMax = 10 }
local t = ns.Frames.target
H.checkTrue("containers", ns.AuraContainers.Ensure(t))
local button = t.auraContainers.debuffs.buttons[1].button

-- The button's fonts, read as the client would let us out of restrictions.
local function fonts()
    local secret = M.aurasSecret
    M.aurasSecret = false
    local count, numbers = button.count:GetFont(), button.cooldown:GetCountdownFontString():GetFont()
    M.aurasSecret = secret
    return count, numbers
end
local classic = ns.Media.Font(ns.Config.Get("target", "fontFace"))

ns.Themes.Switch("TECH")
M.RunTimers()
local tech = ns.Media.Font(ns.Config.Get("target", "fontFace"))
H.checkTrue("a theme font", tech ~= classic)
H.check("theme: count font", (fonts()), tech)

-- In an instance (auras secret, out of combat): back to Classic.
M.aurasSecret = true
H.checkTrue("switch allowed out of combat", ns.Themes.Switch("CLASSIC"))
M.RunTimers()
H.check("refused while secret: still the theme's", (fonts()), tech)

-- Leaving: the restriction ends, the icons take Classic's font.
M.aurasSecret = false
M.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Map, Enum.AddOnRestrictionState.Inactive)
M.RunTimers()
local count, numbers = fonts()
H.check("count back to classic", count, classic)
H.check("countdown back to classic", numbers, classic)

-- A restriction starting does not restyle (it would only be refused).
ns.Themes.Switch("TECH")
M.aurasSecret = true
ns.Themes.Switch("CLASSIC")
M.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Encounter, Enum.AddOnRestrictionState.Active)
M.RunTimers()
H.check("still refused while active", (fonts()), tech)
M.aurasSecret = false
