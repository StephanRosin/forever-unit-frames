-- A font still refused when combat starts: the retries must not touch an
-- aura button's text while auras are secret ("calling 'SetFont' on bad
-- self", reported on CurseForge), and take the font once combat ends.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.units.target = { name = "Foe", health = 5, healthMax = 10 }
local t = ns.Frames.target
H.checkTrue("containers", ns.AuraContainers.Ensure(t))
local count = t.auraContainers.debuffs.buttons[1].button.count

local WANTED = "Interface\\AddOns\\ForeverUnitFrames\\Libs\\LibForeverThemes\\Media\\Fonts\\Bangers-Regular.ttf"
local refuse = true
local setFont = count.SetFont
count.SetFont = function(self, path, size, flags)
    if refuse and path == WANTED then self._font = nil; return false end
    return setFont(self, path, size, flags)
end

ns.Texts.SetFont(count, WANTED, 12, "OUTLINE")
M.SetCombat(true)
refuse = false
H.checkTrue("no error in combat", pcall(M.RunTimers, 1))
M.SetCombat(false)
M.RunTimers()
H.check("the wanted font after combat", (count:GetFont()), WANTED)
