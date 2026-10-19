-- Party buttons prebuilt only after the login loading screen (UIParent
-- hidden until then, Units/Units.lua) get their member's target and the
-- pet beside them styled and watched like any other.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.units.party1 = { name = "A", class = "MAGE", isPlayer = true, health = 100, healthMax = 100 }
M.group = { "party1" }
_G.ForeverUnitFramesDB = { profile = { party = { partyTargets = true, partyPetLayout = "BESIDE",
    partyShowPets = true } }, presetVersion = "0.31.4" }
M.LoadingScreenStarts()
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.LoadingScreenEnds()
M.RunTimers()
local b = ns.Party.header:GetAttribute("child1")
H.checkTrue("a member button", b)
H.checkTrue("target watched", b.targetButton._unitWatch)
H.checkTrue("target placed", b.targetButton:GetNumPoints() > 0)
H.checkTrue("pet beside watched", b.petButton._unitWatch)
H.check("no errors", #M.errors, 0)
