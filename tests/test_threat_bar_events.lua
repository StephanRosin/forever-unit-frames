-- The threat bar does not rescan the group on every mob's threat event
-- (dozens a second in a raid); its combat timer refreshes it.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "WARRIOR", isPlayer = true, health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, T = ns.Config, ns.ThreatBar
C.Set("player", "threatBar", true)
C.Set("player", "threatBarSolo", true)
local scans = 0
local real = T.Evaluate
T.Evaluate = function(...) scans = scans + 1; return real(...) end
M.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate3")
M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "nameplate3")
H.check("no scan per threat event", scans, 0)
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("a new target: one scan", scans, 1)
T.Evaluate = real

-- The frame poll (Units/Single.lua) leaves it to that timer in combat.
local refreshes = 0
local realRefresh = T.Refresh
T.Refresh = function() refreshes = refreshes + 1 end
local frame = ns.Frames.player
T.Update(frame, ns.Single.POLL)
H.check("poll out of combat: refreshed", refreshes, 1)
M.units.player.combat = true
M.SetCombat(true)
T.Update(frame, ns.Single.POLL)
H.check("poll in combat: left to the timer", refreshes, 1)
T.Update(frame, "UNIT_TARGET")
H.check("an event in combat: refreshed", refreshes, 2)
T.Refresh = realRefresh
