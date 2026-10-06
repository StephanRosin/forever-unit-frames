-- Movers come in two groups, each unlocked on its own: the unit frames'
-- (frames, party block, detached castbars; the unit window, /fuf unlock,
-- the minimap button) and the raid panel's (the raid window). /fuf lock
-- and the start of combat lock both.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Movers = ns.Movers
local unit, raid = ns.Frames.player.mover, ns.RaidHeader.anchor.mover
H.check("unit mover in the units group", unit.spec.group, "units")
H.check("raid mover in the raid group", raid.spec.group, "raid")
H.check("party block in the units group", ns.Party.header.mover.spec.group, "units")

-- The raid group: only the raid panel's handle.
H.checkTrue("raid unlock", Movers.Unlock("raid"))
H.checkTrue("raid handle shown", raid:IsShown())
H.check("unit handle hidden", unit:IsShown(), false)
H.check("units still locked", Movers.IsUnlocked("units"), false)
H.checkTrue("raid unlocked", Movers.IsUnlocked("raid"))
H.check("the default group is the units'", Movers.IsUnlocked(), false)

-- The units group: only the unit frames' handles.
Movers.Lock("raid")
H.check("raid locked", raid:IsShown(), false)
H.checkTrue("unit unlock", Movers.Unlock())
H.checkTrue("unit handle shown", unit:IsShown())
H.check("raid handle stays hidden", raid:IsShown(), false)
H.check("raid still locked", Movers.IsUnlocked("raid"), false)

-- Independent: both on, one locked, the other stays.
Movers.Unlock("raid")
Movers.Lock("units")
H.check("units locked", unit:IsShown(), false)
H.checkTrue("raid stays unlocked", Movers.IsUnlocked("raid"))
H.checkTrue("raid handle stays", raid:IsShown())
Movers.Unlock("units")
Movers.Lock("raid")
H.checkTrue("units stay unlocked", Movers.IsUnlocked("units"))
H.checkTrue("unit handle stays", unit:IsShown())

-- A raid setting change while only the units are unlocked: no raid handle.
ns.RaidConfig.Set("general", "enabled", true)
H.check("raid handle not brought back", raid:IsShown(), false)

-- /fuf unlock: the unit frames; /fuf lock: both.
Movers.Lock("units")
SlashCmdList.FOREVERUNITFRAMES("unlock")
H.checkTrue("/fuf unlock: units", Movers.IsUnlocked("units"))
H.check("/fuf unlock: not the raid", Movers.IsUnlocked("raid"), false)
Movers.Unlock("raid")
SlashCmdList.FOREVERUNITFRAMES("lock")
H.check("/fuf lock: units", Movers.IsUnlocked("units"), false)
H.check("/fuf lock: raid", Movers.IsUnlocked("raid"), false)
H.check("/fuf lock: raid handle hidden", raid:IsShown(), false)

-- Combat start locks both.
Movers.Unlock("units")
Movers.Unlock("raid")
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: units locked", Movers.IsUnlocked("units"), false)
H.check("combat: raid locked", Movers.IsUnlocked("raid"), false)
H.check("combat: raid handle hidden", raid:IsShown(), false)
M.combat = true
H.check("combat: no raid unlock", Movers.Unlock("raid"), false)
M.SetCombat(false)

-- An unknown group is a mistake.
H.checkError("unknown group", function() Movers.Unlock("pets") end)
H.check("nothing blocked", #M.blocked, 0)
