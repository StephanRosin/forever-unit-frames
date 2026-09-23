-- Title, health and power fill the frame: row shares that leave room over
-- never open a see-through band between health and power, and a docked
-- castbar sits right under (or over) the frame, inside the unit's ring.
local M = H.M
local ns = H.LoadAddon()
local Lay = ns.Layout

-- Layout maths: title, health, power.
local function rows(...) return table.concat({ Lay.Rows(...) }, ",") end
H.check("shares of 100: as set", rows(46, 30, 45, 25, true), "14,21,11")
H.check("room left over: health and power share it", rows(50, 20, 40, 20, true), "10,27,13")
H.check("room left over, 65 high", rows(65, 28, 41, 25, true), "18,30,17")
H.check("too much: power keeps its share", rows(46, 30, 60, 25, true), "14,21,11")
H.check("too much: title gives way", rows(20, 60, 50, 50, true), "9,1,10")
H.check("no title: two rows", rows(40, 0, 75, 25, true), "0,30,10")
H.check("power off: health takes the rest", rows(46, 30, 45, 25, false), "14,32,0")
H.check("power at 0 %: health takes the rest", rows(46, 30, 45, 0, true), "14,32,0")
for _, h in ipairs({ 8, 13, 46, 65, 200 }) do
    for _, shares in ipairs({ { 0, 10, 0 }, { 0, 10, 90 }, { 60, 10, 90 }, { 28, 41, 25 }, { 10, 100, 90 } }) do
        local t, hh, p = Lay.Rows(h, shares[1], shares[2], shares[3], true)
        H.check(("rows fill %d (%d/%d/%d)"):format(h, shares[1], shares[2], shares[3]), t + hh + p, h)
        H.checkTrue(("health at least 1 (%d)"):format(h), hh >= 1)
    end
end
H.check("two-row helper", table.concat({ Lay.Bars(48, 70, 20, true) }, ","), "38,10")

M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config

local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

-- The rows of a frame meet: health ends where power begins.
local function checkFilled(label, f)
    local titleTop = point(f.health, "TOPLEFT")[5]
    H.check(label .. ": health starts under the title", -titleTop, f.titleHeight)
    H.check(label .. ": title, health and power fill the frame",
        f.titleHeight + f.health:GetHeight() + f.power:GetHeight(), f:GetHeight())
    H.check(label .. ": power on the frame's bottom", point(f.power, "BOTTOMLEFT")[5], 0)
end

-- A party member with shares that leave room over and a docked castbar.
C.Set("party", "height", 65)
C.Set("party", "titlePercent", 28)
C.Set("party", "healthPercent", 41)
C.Set("party", "castbarEnabled", true)
C.Set("party", "castbarDock", "BELOW")
C.Set("party", "castbarHeight", 12)
M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
M.units.party2 = { name = "Bob", health = 1, healthMax = 1 }
M.SetGroup({ "party1", "party2" })
local member = ns.Party.header:GetAttribute("child1")
checkFilled("party", member)
local bar = member.castbar
H.check("party castbar right under the power bar", point(bar, "TOPLEFT")[5], 0)
H.check("party castbar on the frame's bottom", point(bar, "TOPLEFT")[3], "BOTTOMLEFT")
H.check("unit box: frame plus the castbar", point(member.unitBox, "BOTTOMRIGHT")[5], -12)
local depth = 12 + ns.Border.Extent("party")
H.check("party step: castbar and ring, then the spacing", ns.Party.Spacing(),
    C.Get("party", "partySpacing") + depth)
C.Set("party", "castbarDock", "ABOVE")
H.check("party castbar right over the title", point(bar, "BOTTOMLEFT")[5], 0)
C.Set("party", "castbarDock", "BELOW")

-- The same for a single frame (target: docked below).
C.Set("target", "height", 65)
C.Set("target", "titlePercent", 28)
C.Set("target", "healthPercent", 41)
C.Set("target", "castbarPosition", "BELOW")
local target = ns.Frames.target
checkFilled("target", target)
H.check("target castbar right under the power bar", point(target.castbar, "TOPLEFT")[5], 0)
H.check("target: docked reach is the castbar", select(2, ns.Shape.DockReach(target)), ns.Castbar.Height("target"))
