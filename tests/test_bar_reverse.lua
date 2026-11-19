-- Bars filling from the right (barReverse): health and power reversed,
-- heals, shield, spell cost and the overheal lane mirrored to the left.
local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config
C.Use({})
M.units.player = { name = "Me", isPlayer = true, health = 1000, healthMax = 1000 }
ns.Single.CreateAll()
local p = ns.Frames.player
H.check("code", S.Get("barReverse").code, "RV")
H.check("off by default", C.Get("player", "barReverse"), false)
H.check("off: health from the left", not not p.health._reverse, false)
local point, _, rel = p.healAll:GetPoint(1)
H.check("off: heals after the fill's right", point .. rel, "TOPLEFTTOPRIGHT")

C.Set("player", "healOverflow", true)
C.Set("player", "barReverse", true)
H.checkTrue("health from the right", p.health._reverse)
H.checkTrue("power from the right", p.power._reverse)
H.checkTrue("heals from the right", p.healAll._reverse)
point, _, rel = p.healAll:GetPoint(1)
H.check("heals before the fill's left", point .. rel, "TOPRIGHTTOPLEFT")
local _, _, _, x = p.healClip:GetPoint(1)
H.check("heal clip reaches into the lane on the left", x, -p.overhealLane)
_, _, _, x = p.healClip:GetPoint(2)
H.check("heal clip ends at the bar's right", x, 0)
point = p.overhealBg:GetPoint(1)
H.check("lane background left of the bar", point, "TOPRIGHT")
H.checkTrue("shield after the heals, leftwards", p.absorb._reverse)
point, _, rel = p.absorb:GetPoint(1)
H.check("shield before the heals' left", point .. rel, "TOPRIGHTTOPLEFT")
H.check("glow mirrored", p.absorb.glow._texCoord[1], 1)
_, _, _, x = p.health:GetPoint(1)
local lane = p.overhealLane
H.checkTrue("lane taken on the left", lane > 0 and x >= lane)
if p.powerCost then
    H.check("spell cost fills left to right", not not p.powerCost.bar._reverse, false)
    H.check("spell cost at the fill's left end", (p.powerCost.bar:GetPoint(1)), "TOPLEFT")
end

C.Set("player", "absorbMode", "END")
H.check("shield at the end: from the left edge", not not p.absorb._reverse, false)
H.check("shield at the end: on the left", (p.absorb:GetPoint(1)), "TOPLEFT")

C.Set("player", "barReverse", false)
H.check("off again: health from the left", not not p.health._reverse, false)
H.check("off again: glow as drawn", p.absorb.glow._texCoord[1], 0)
