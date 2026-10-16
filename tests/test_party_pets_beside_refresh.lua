-- Pets beside their owner (layout BESIDE) are unit frames too: the
-- group-wide refreshes (raid markers, range) reach them.
local M = H.M
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, P = ns.Config, ns.Party
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10 }
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.units.partypet1 = { name = "Wolf", health = 3, healthMax = 4 }
M.SetGroup({ "party1" })
C.Set("party", "partyShowPets", true)
C.Set("party", "partyPetLayout", "BESIDE")
local pet = P.header:GetAttribute("child1").petButton
local seen = false
ns.Units.ForEachFrame(function(f) if f == pet then seen = true end end)
H.checkTrue("beside pet among all frames", seen)
M.units.partypet1.raidTarget = 8
M.FireEvent("RAID_TARGET_UPDATE")
H.checkTrue("its raid marker follows", pet.raidMarker.icon:IsShown())
