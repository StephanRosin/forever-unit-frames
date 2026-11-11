-- The focus's target: a single frame like the target of target, off by
-- default, there only where the client has a focus, refreshed by the
-- focus's events and the timer.
local M = H.M

local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "PRIEST", isPlayer = true, health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C = ns.Settings, ns.Config
local frame = ns.Frames.focustarget
H.checkTrue("frame made", frame)
H.check("unit", frame.unit, "focustarget")
H.check("off by default", S.Default(S.Get("enabled"), "focustarget"), false)
H.check("off: not watched", frame._unitWatch, nil)
H.checkTrue("named", ns.L.FRAME_focustarget ~= "FRAME_focustarget")
H.check("only with a focus", ns.Units.List[8].key == "focustarget" and ns.Units.List[8].available,
    ns.Units.FocusAvailable)

C.Set("focustarget", "enabled", true)
H.checkTrue("on: watched", frame._unitWatch)
M.units.focustarget = { name = "Tank", health = 3, healthMax = 4 }
frame:Show()
M.FireEvent("UNIT_TARGET", "focus")
H.check("follows the focus's target change", frame.health:GetValue(), 3)
M.units.focustarget.health = 2
M.FireEvent("PLAYER_FOCUS_CHANGED")
H.check("follows a new focus", frame.health:GetValue(), 2)
M.units.focustarget.health = 1
M.Tick(0.25)
H.check("polled", frame.health:GetValue(), 1)
H.check("no errors", #M.errors, 0)
