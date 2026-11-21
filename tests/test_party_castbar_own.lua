-- castbarHideOwn (party only, CurseForge 21.11.2026): your own entry in
-- the party frames (show yourself / show when solo) gets no castbar, the
-- members keep theirs. Blizzard's own cast bar shows the player's cast.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, S = ns.Config, ns.Settings
H.check("code", S.Get("castbarHideOwn").code, "CC")
H.check("off by default", C.Get("party", "castbarHideOwn"), false)
H.check("party only", S.AppliesTo(S.Get("castbarHideOwn"), "target"), false)

C.Set("party", "partyShowPlayer", true)
M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
M.SetGroup({ "party1" })
M.RunTimers()
local own, ann
for i = 1, 5 do
    local b = ns.Party.header:GetAttribute("child" .. i)
    if b and b.unit == "player" then own = b elseif b and b.unit == "party1" then ann = b end
end
H.checkTrue("own entry", own)
H.checkTrue("member entry", ann)

local CAST = { name = "Fireball", texture = 135812, startMs = 1000000, endMs = 1002500 }
M.units.player.cast = CAST
M.units.party1.cast = CAST
M.FireEvent("UNIT_SPELLCAST_START", "player", "p-1", 133)
M.FireEvent("UNIT_SPELLCAST_START", "party1", "a-1", 133)
H.checkTrue("off: own castbar shows", own.castbar:IsShown())

C.Set("party", "castbarHideOwn", true)
M.FireEvent("UNIT_SPELLCAST_START", "player", "p-2", 133)
M.FireEvent("UNIT_SPELLCAST_START", "party1", "a-2", 133)
H.check("on: own castbar hidden", own.castbar:IsShown(), false)
H.checkTrue("on: the member's shows", ann.castbar:IsShown())
-- Always show keeps an empty bar for the members, none on your own.
C.Set("party", "castbarAlwaysShow", true)
M.units.player.cast, M.units.party1.cast = nil, nil
M.FireEvent("UNIT_SPELLCAST_STOP", "player", "p-2", 133)
M.FireEvent("UNIT_SPELLCAST_STOP", "party1", "a-2", 133)
H.check("always show: own still hidden", own.castbar:IsShown(), false)
H.checkTrue("always show: the member's empty bar", ann.castbar:IsShown())
