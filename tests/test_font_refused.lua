-- A font file the client refuses for a while: the text shows Blizzard's
-- font meanwhile (no chat message) and takes the wanted one once loadable.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

local WANTED = "Interface\\AddOns\\ForeverUnitFrames\\Libs\\LibForeverThemes\\Media\\Fonts\\Bangers-Regular.ttf"
local refuse = true
local fs = CreateFrame("Frame"):CreateFontString()
local setFont = fs.SetFont
fs.SetFont = function(self, path, size, flags)
    if refuse and path == WANTED then self._font = nil; return false end
    return setFont(self, path, size, flags)
end

local chat = #M.chat
ns.Texts.SetFont(fs, WANTED, 12, "NONE")
H.check("Blizzard's font from the first refusal", (fs:GetFont()), "Fonts\\FRIZQT__.TTF")
M.RunTimers(1)
H.check("Blizzard's font while refused", (fs:GetFont()), "Fonts\\FRIZQT__.TTF")
ns.Texts.SetFont(fs, WANTED, 12, "NONE")
H.check("a restyle with the same font: still Blizzard's", (fs:GetFont()), "Fonts\\FRIZQT__.TTF")
H.check("no chat message", #M.chat, chat)

refuse = false
M.RunTimers()
H.check("the wanted font once loadable", (fs:GetFont()), WANTED)

-- Soft outline while refused: the copies take the font the text has, so
-- the outline shows; the wanted one once loadable.
local fs3 = CreateFrame("Frame"):CreateFontString()
fs3.SetFont = fs.SetFont
refuse = true
ns.Texts.SetFont(fs3, WANTED, 12, "SOFT")
H.check("soft: outline shown", fs3.soft, true)
H.check("soft: copies in Blizzard's font", (fs3.softCopies[1]:GetFont()), "Fonts\\FRIZQT__.TTF")
refuse = false
M.RunTimers()
H.check("soft: copies in the wanted font", (fs3.softCopies[1]:GetFont()), WANTED)

-- Refused for good: the slow tries end, the fallback stays.
local fs2 = CreateFrame("Frame"):CreateFontString()
fs2.SetFont = function(self, path, size, flags)
    if path == WANTED then self._font = nil; return false end
    return setFont(self, path, size, flags)
end
ns.Texts.SetFont(fs2, WANTED, 12, "NONE")
M.RunTimers()
H.check("tries end on Blizzard's font", (fs2:GetFont()), "Fonts\\FRIZQT__.TTF")
H.check("no timers left", #M.timers, 0)
