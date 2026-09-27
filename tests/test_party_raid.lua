-- "Hide in raid": the party frames (and the pet list) hide while you are
-- in a raid group, by a visibility driver on the headers.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C = ns.Settings, ns.Config

local def = S.Get("partyHideInRaid")
H.check("code", def.code, "HR")
H.checkTrue("party only", S.AppliesTo(def, "party") and not S.AppliesTo(def, "target"))
C.Use({})
H.check("on by default", C.Get("party", "partyHideInRaid"), true)

local header = ns.Party.Create()
M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
M.SetGroup({ "party1" })
ns.Party.StyleAll()
H.checkTrue("party: shown", header:IsShown())
H.check("driver set", M.drivers[header], "[group:raid] hide; show")
M.SetRaid(true)
H.check("raid: hidden", header:IsShown(), false)
H.check("raid: pets hidden", ns.PartyPets.header:IsShown(), false)
M.SetRaid(false)
H.checkTrue("back to party: shown", header:IsShown())

C.Set("party", "partyHideInRaid", false)
H.check("off: no driver", M.drivers[header], nil)
M.SetRaid(true)
H.checkTrue("off: shown in raid", header:IsShown())
M.SetRaid(false)

C.Set("party", "enabled", false)
H.check("disabled: hidden", header:IsShown(), false)
H.check("disabled: no driver", M.drivers[header], nil)
