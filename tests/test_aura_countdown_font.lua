-- The time left on an aura icon takes its font like every other text: a
-- refused font is tried again (CurseForge: after a theme switch some icons
-- kept the old font, the same debuff in two frames in different fonts).
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.units.target = { name = "Foe", health = 5, healthMax = 10 }
local t = ns.Frames.target
H.checkTrue("containers", ns.AuraContainers.Ensure(t))
local button = t.auraContainers.debuffs.buttons[1].button
local numbers = button.cooldown:GetCountdownFontString()
H.checkTrue("countdown font string", numbers ~= nil)

local WANTED = "Interface\\AddOns\\ForeverUnitFrames\\Libs\\LibForeverThemes\\Media\\Fonts\\Bangers-Regular.ttf"
local refuse = true
local setFont = numbers.SetFont
numbers.SetFont = function(self, path, size, flags)
    if refuse and path == WANTED then self._font = nil; return false end
    return setFont(self, path, size, flags)
end
local get = ns.Config.Get
ns.Config.Get = function(scope, key, ...)
    if key == "fontFace" then return "Bangers" end
    return get(scope, key, ...)
end
local media = ns.Media.Font
ns.Media.Font = function(name) if name == "Bangers" then return WANTED end return media(name) end

ns.AuraButton.Style(button, "target", 24, true)
H.check("Blizzard's font while refused", (numbers:GetFont()), "Fonts\\FRIZQT__.TTF")
refuse = false
M.RunTimers()
H.check("the wanted font once loadable", (numbers:GetFont()), WANTED)
ns.Config.Get, ns.Media.Font = get, media
