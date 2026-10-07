-- Click-casting on the unit frames' party members (Raid/ClickCast.lua):
-- on by default, switchable; switched off they get the XML's left/right
-- back. Their pretend members in test mode never take bindings.
local M = H.M
local ns = H.LoadAddon()
local RC, CC = ns.RaidConfig, ns.ClickCast
ns.Config.Use({})
ns.Single.CreateAll()
local header = ns.Party.Create()
-- Made before the raid profile is attached (as at login): nothing yet.
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.SetGroup({ "party1" })
local b1 = header:GetAttribute("child1")
H.check("made before the profile: the XML's", b1:GetAttribute("*type1"), "target")
ns.RaidProfiles.Attach({})
RC.Set("general", "click1Ctrl", "assist")
H.check("a binding reaches the party", b1:GetAttribute("ctrl-type1"), "assist")
H.check("left still targets", b1:GetAttribute("*type1"), "target")

-- A member who joins later gets them at once; in combat after combat.
M.units.party2 = { name = "Bob", health = 5, healthMax = 10 }
M.SetGroup({ "party1", "party2" })
H.check("a new member's button", header:GetAttribute("child2"):GetAttribute("ctrl-type1"), "assist")
M.units.party3 = { name = "Cid", health = 5, healthMax = 10 }
M.SetCombat(true)
M.SetGroup({ "party1", "party2", "party3" })
local b3 = header:GetAttribute("child3")
H.check("made in combat: the XML's", b3:GetAttribute("ctrl-type1"), nil)
M.SetCombat(false)
H.check("after combat: the binding", b3:GetAttribute("ctrl-type1"), "assist")
H.check("nothing blocked", #M.blocked, 0)

-- Switched off for the party: the XML's attributes again.
RC.Set("general", "clickCastParty", false)
H.check("switched off", b1:GetAttribute("ctrl-type1"), nil)
H.check("left targets", b1:GetAttribute("*type1"), "target")
H.check("right menu", b1:GetAttribute("*type2"), "togglemenu")
RC.Set("general", "clickCastParty", true)
H.check("on again", b1:GetAttribute("ctrl-type1"), "assist")

-- Test mode's pretend members: never.
ns.Party.SetTest(true)
for _, b in ipairs(ns.Party.fakes) do H.check("pretend member", b:GetAttribute("ctrl-type1"), nil) end
H.checkTrue("pretend members exist", #ns.Party.fakes > 0)
ns.Party.SetTest(false)
