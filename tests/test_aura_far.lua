-- A group member out of sight: the client sends their auras without the
-- caster, "PLAYER" and "!PLAYER" both take every one -- each showed twice
-- (CurseForge). Yours and the rest are not told apart then.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, P = ns.Config, ns.Party
C.Set("party", "buffsEnabled", true)
C.Set("party", "buffsHighlightOwn", true)
C.Set("party", "buffsOnlyMine", false)
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
M.SetGroup({ "party1" })
local b1 = P.header:GetAttribute("child1")
ns.Auras.Style(b1)
local groups = b1.auraContainers.buffs.container._groups
H.check("near: yours apart", groups.own.enabled, true)
H.check("near: the rest without yours", groups.other.filter, "HELPFUL|!PLAYER")

M.units.party1.visible = false
M.Tick(1.1)
H.check("far: no group of yours", groups.own.enabled, false)
H.check("far: all in one", groups.other.filter, "HELPFUL")

-- In combat too: the containers are plain frames.
M.SetCombat(true)
M.units.party1.visible = nil
M.Tick(1.1)
H.check("near again in combat: yours apart", groups.own.enabled, true)
H.check("near again in combat: the rest", groups.other.filter, "HELPFUL|!PLAYER")
M.SetCombat(false)
