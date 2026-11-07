-- The target of the target of target: a single frame like the target of
-- target, off by default, refreshed by the timer alone (no unit events).
local M = H.M

local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "PRIEST", isPlayer = true, health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C = ns.Settings, ns.Config
local frame = ns.Frames.targettargettarget
H.checkTrue("frame made", frame)
H.check("unit", frame.unit, "targettargettarget")
H.check("off by default", S.Default(S.Get("enabled"), "targettargettarget"), false)
H.check("off: not watched", frame._unitWatch, nil)
H.checkTrue("named", ns.L.FRAME_targettargettarget ~= "FRAME_targettargettarget")

C.Set("targettargettarget", "enabled", true)
H.checkTrue("on: watched", frame._unitWatch)
-- Tank targeted, boss on the tank: the tank comes back as the third step.
M.units.targettargettarget = { name = "Tank", health = 3, healthMax = 4 }
M.FireEvent("UNIT_TARGET", "target")
H.check("follows the target's target change", frame.health:GetValue(), 3)
frame:Show()
M.units.targettargettarget.health = 2
M.Tick(0.25)
H.check("polled", frame.health:GetValue(), 2)
