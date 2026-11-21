-- Bars filling vertically (barVertical; with barReverse from the top):
-- health and power, heals, shield, spell cost, the overheal lane, the
-- druid's mana strip and the boxes' rings follow (Layout.Fill). The raid
-- cells take it from their profile (fillVertical, fillReverse).
local M = H.M
local ns = H.LoadAddon()
local S, C, Layout = ns.Settings, ns.Config, ns.Layout
C.Use({})
M.units.player = { name = "Me", isPlayer = true, class = "DRUID", health = 1000, healthMax = 1000 }
ns.Single.CreateAll()
local p = ns.Frames.player

-- The helper.
local f = Layout.Fill(true, false)
H.check("up: from the bottom to the top", f.start .. f.finish, "BOTTOMTOP")
H.check("up: sides", table.concat(f.sides, ","), "LEFT,RIGHT")
H.check("up: corner", Layout.Corner(f, "TOP", "LEFT"), "TOPLEFT")
H.check("up: beyond", table.concat({ Layout.Beyond(f, 5) }, ","), "0,5,0,0")
f = Layout.Fill(true, true)
H.check("down", f.start .. f.finish, "TOPBOTTOM")
H.check("down: beyond", table.concat({ Layout.Beyond(f, 5) }, ","), "0,0,0,-5")
f = Layout.Fill(false, true)
H.check("left", f.start .. f.finish, "RIGHTLEFT")
H.check("left: corner", Layout.Corner(f, "LEFT", "TOP"), "TOPLEFT")
H.check("left: beyond", table.concat({ Layout.Beyond(f, 5) }, ","), "-5,0,0,0")

H.check("code", S.Get("barVertical").code, "FV")
H.check("off by default", C.Get("player", "barVertical"), false)
H.check("off: horizontal", p.health._orientation, "HORIZONTAL")

-- Upward, with the overheal lane.
C.Set("player", "healOverflow", true)
local heightBefore = p.healthHeight
C.Set("player", "barVertical", true)
H.check("health vertical", p.health._orientation, "VERTICAL")
H.check("power vertical", p.power._orientation, "VERTICAL")
H.check("from the bottom", not not p.health._reverse, false)
H.check("heals vertical", p.healAll._orientation, "VERTICAL")
local point, _, rel = p.healAll:GetPoint(1)
H.check("heals above the fill's top", point .. rel, "BOTTOMLEFTTOPLEFT")
local lane = p.overhealLane
H.checkTrue("a lane", lane > 0)
H.check("the lane comes off the height", p.healthHeight, heightBefore - lane)
H.check("the length is the height", p.healthLength, p.healthHeight)
H.check("heals as tall as the bar", p.healAll._h, p.healthHeight)
local _, _, _, x, y = p.healClip:GetPoint(1)
H.check("heal clip reaches into the lane above", x .. "," .. y, "0," .. lane)
point = p.overhealBg:GetPoint(1)
H.check("lane background above the bar", point, "BOTTOMLEFT")
H.check("lane background as deep as the lane", p.overhealBg._h, lane)
_, _, _, _, y = p.health:GetPoint(1)
H.checkTrue("the bar starts below the lane", y <= -lane)
point, _, rel = p.absorb:GetPoint(1)
H.check("shield after the heals, upward", point .. rel, "BOTTOMLEFTTOPLEFT")
H.check("shield vertical", p.absorb._orientation, "VERTICAL")
H.check("glow turned: its left edge at the bottom", table.concat(p.absorb.glow._texCoord, ","), "1,0,0,0,1,1,0,1")
H.check("glow height", p.absorb.glow._h, ns.Absorb.GLOW_WIDTH)
if p.powerCost then
    H.check("spell cost vertical", p.powerCost.bar._orientation, "VERTICAL")
    H.check("spell cost from the fill's top down", (p.powerCost.bar:GetPoint(1)), "TOPLEFT")
end
-- The druid's mana: a strip along the power bar's right edge.
C.Set("player", "druidMana", true)
local dm = p.druidMana
if dm then
    H.check("druid mana vertical", dm._orientation, "VERTICAL")
    H.check("druid mana on the right edge", (dm:GetPoint(1)), "TOPRIGHT")
end
-- Boxes apart: the health box takes the lane above.
-- (Parts lists the health part whether apart or not.)
for _, part in ipairs(ns.Boxes.Parts(p)) do
    if part[1] == "health" then
        H.check("health box: no extra width", part[3], 0)
        H.check("health box: the lane above", part[6], lane)
    end
end


-- Downward.
C.Set("player", "barReverse", true)
H.checkTrue("from the top", p.health._reverse)
point, _, rel = p.healAll:GetPoint(1)
H.check("heals below the fill's bottom", point .. rel, "TOPLEFTBOTTOMLEFT")
_, _, _, x, y = p.healClip:GetPoint(2)
H.check("heal clip reaches into the lane below", x .. "," .. y, "0," .. -lane)
H.check("glow turned the other way", table.concat(p.absorb.glow._texCoord, ","), "0,0,1,0,0,1,1,1")
C.Set("player", "absorbMode", "END")
H.check("shield at the end: from the bottom up", not not p.absorb._reverse, false)
H.check("shield at the end: at the bottom", (p.absorb:GetPoint(1)), "BOTTOMLEFT")
C.Set("player", "absorbMode", "AFTER")

-- Back: horizontal as before.
C.Set("player", "barVertical", false)
C.Set("player", "barReverse", false)
H.check("back: horizontal", p.health._orientation, "HORIZONTAL")
H.check("back: the height whole", p.healthHeight, heightBefore)
point, _, rel = p.healAll:GetPoint(1)
H.check("back: heals after the fill's right", point .. rel, "TOPLEFTTOPRIGHT")
H.check("back: glow as drawn", p.absorb.glow._texCoord[1], 0)

-- Raid cells: from the raid profile.
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC = ns.RaidConfig
M.SetRaidRoster({ { name = "A", class = "PRIEST", subgroup = 1, unit = { health = 1, healthMax = 1 } } })
M.RunTimers()
local cell = ns.RaidCell.buttons[1]
H.check("cell: horizontal by default", cell.health._orientation, "HORIZONTAL")
RC.Set(ns.Raid.Scope(ns.RaidCell.Size()), "fillVertical", true)
M.RunTimers()
H.check("cell: vertical", cell.health._orientation, "VERTICAL")
RC.Set(ns.Raid.Scope(ns.RaidCell.Size()), "fillReverse", true)
M.RunTimers()
H.checkTrue("cell: from the top", cell.health._reverse)
H.check("nothing blocked", #M.blocked, 0)
