-- Your own auras placed freely where the addon draws the icons itself
-- (Elements/Auras.lua: test mode samples, clients without containers):
-- yours in a block of their own (group.free) at their own place, the rest
-- from the group's first row; the group's maximum counts both. Test mode
-- shows samples of yours there, so the place can be chosen. Shift +
-- right-click over the block opens the hidden-auras menu as over the row.
local M = H.M
local ns = H.LoadAddon()
M.auraContainerMissing = true
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, Auras = ns.Config, ns.Auras

local function aura(id, fields)
    local a = { auraInstanceID = id, spellId = 9000 + id, icon = 100 + id, applications = 0, duration = 60,
        expirationTime = 0 }
    for k, v in pairs(fields or {}) do a[k] = v end
    return a
end
M.units.player = { name = "Me", health = 5, healthMax = 10 }
M.units.target = { name = "Foe", hostile = true, health = 5, healthMax = 10,
    auras = { aura(1), aura(2, { mine = true }), aura(3), aura(4, { mine = true }) } }
local t = ns.Frames.target
local debuffs = t.auras.debuffs
local free = debuffs.free
local function icons(group)
    local out = {}
    for i = 1, group.count do out[i] = tostring(group.buttons[i].icon._texture) end
    return table.concat(out, ",")
end
local function point(region)
    local p, rel, rp, x, y = region:GetPoint(1)
    return p .. ">" .. rp .. " " .. x .. "," .. y, rel
end
M.FireEvent("PLAYER_TARGET_CHANGED")

-- With the rest (default): yours first in the group, the block empty.
H.check("with: all in the group", icons(debuffs), "102,104,101,103")
H.check("with: two of yours", debuffs.own, 2)
H.check("with: block empty", free.count, 0)

-- Free: yours in the block, the rest from the group's first row.
C.Set("target", "debuffsOwnPlacement", "FREE")
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("free: yours in the block", icons(free), "102,104")
H.check("free: the rest in the group", icons(debuffs), "101,103")
H.check("free: none of yours in the group", debuffs.own, 0)
H.check("free: the rest at the corner", (point(debuffs.buttons[1])), "BOTTOMLEFT>BOTTOMLEFT 0,0")
H.check("free: the rest at their size", debuffs.buttons[1]:GetWidth(), 20)
H.check("free: yours at the own size", free.buttons[1]:GetWidth(), 26)
H.check("free: yours grow right", (point(free.buttons[2])), "TOPLEFT>TOPLEFT 28,0")
local at, rel = point(free.holder)
H.check("free: block's place", at, "TOPLEFT>TOPRIGHT 5,0")
H.check("free: on the unit box", rel, t.unitBox)
H.check("free: block sized", free.holder:GetWidth() .. "x" .. free.holder:GetHeight(), "54x26")
H.check("free: block level", free.holder:GetFrameLevel(), t:GetFrameLevel() + Auras.LEVELS)
-- The maximum counts both.
C.Set("target", "debuffsMax", 3)
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("max 3: yours", icons(free), "102,104")
H.check("max 3: one of the rest", icons(debuffs), "101")
C.Set("target", "debuffsMax", 16)
M.FireEvent("PLAYER_TARGET_CHANGED")
-- An aura of yours goes (an aura event): the block follows.
table.remove(M.units.target.auras, 2)
M.FireEvent("UNIT_AURA", "target", { removedAuraInstanceIDs = { 2 } })
H.check("removed: block follows", icons(free), "104")
H.check("removed: the rest kept", icons(debuffs), "101,103")
-- Its place follows the settings.
C.Set("target", "debuffsOwnFramePoint", "BOTTOM")
C.Set("target", "debuffsOwnPoint", "TOP")
C.Set("target", "debuffsOwnY", -3)
H.check("moved", (point(free.holder)), "TOP>BOTTOM 4,-4")
-- Back with the rest.
C.Set("target", "debuffsOwnPlacement", "WITH")
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("with again: block empty", free.count, 0)
H.check("with again: yours first in the group", icons(debuffs), "104,101,103")

-- Test mode: samples of yours in the block, the rest in the group.
C.Set("target", "debuffsOwnPlacement", "FREE")
ns.TestMode.Set(true)
H.check("test: yours in the block", free.count, Auras.OWN_SAMPLES)
H.check("test: the rest", debuffs.count, C.Get("target", "debuffsMax") - Auras.OWN_SAMPLES)
H.check("test: none of yours in the group", debuffs.own, 0)
H.checkTrue("test: block shown", free.holder:IsShown() and free.buttons[1]:IsShown())
H.check("test: block's samples at the own size", free.buttons[1]:GetWidth(), 26)
-- Buffs with mine first and free too.
C.Set("target", "buffsHighlightOwn", true)
C.Set("target", "buffsOwnPlacement", "FREE")
H.check("test: buffs block", t.auras.buffs.free.count, Auras.OWN_SAMPLES)
C.Set("target", "debuffsOwnPlacement", "WITH")
H.check("test, with: block empty", free.count, 0)
H.check("test, with: yours first in the group", debuffs.own, Auras.OWN_SAMPLES)
ns.TestMode.Set(false)
H.check("test off: buffs block empty", t.auras.buffs.free.count, 0)

-- Shift + right-click over the block: the menu of that group's auras.
C.Set("target", "debuffsOwnPlacement", "FREE")
M.FireEvent("PLAYER_TARGET_CHANGED")
M.spells[9004] = { name = "Mine" }
M.units.target.auras[3].name = "Mine"
M.shiftDown = true
free.holder._mouseOver = true
M.menu = nil
t:GetScript("OnMouseUp")(t, "RightButton")
H.checkTrue("menu over the block", M.menu ~= nil)
free.holder._mouseOver = false
M.shiftDown = false
H.check("no error", #M.errors, 0)
