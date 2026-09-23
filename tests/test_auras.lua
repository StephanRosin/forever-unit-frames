local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C, P, Auras = ns.Config, ns.Party, ns.Auras
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10 }
M.units.target = { name = "Foe", level = 60, health = 5, healthMax = 10 }

local t = ns.Frames.target
local debuffs, buffs = t.auras.debuffs, t.auras.buffs

-- Two groups per frame, each with its own holder above the bars.
for _, key in ipairs({ "player", "target", "targettarget", "pet", "focus" }) do
    local f = ns.Frames[key]
    H.checkTrue(key .. ": buffs", f.auras.buffs.holder)
    H.checkTrue(key .. ": debuffs", f.auras.debuffs.holder)
    H.check(key .. ": holder parent", f.auras.debuffs.holder:GetParent(), f)
    H.check(key .. ": holder level", f.auras.debuffs.holder:GetFrameLevel(), f:GetFrameLevel() + Auras.LEVELS)
    H.check(key .. ": holder plain", f.auras.debuffs.holder:IsProtected(), false)
end

-- Default anchors: debuffs above the frame, buffs above the debuffs.
local function anchor(group)
    local point, rel, relPoint, x, y = group.holder:GetPoint(1)
    return point, rel, relPoint, x, y
end
local point, rel, relPoint, x, y = anchor(debuffs)
H.check("debuffs point", point, "BOTTOMLEFT")
H.check("debuffs on the frame", rel, t)
H.check("debuffs frame point", relPoint, "TOPLEFT")
H.check("debuffs x", x, 0)
H.check("debuffs y", y, 2)
point, rel, relPoint = anchor(buffs)
H.check("buffs point", point, "BOTTOMLEFT")
H.check("buffs on the debuffs", rel, debuffs.holder)
H.check("buffs to the debuffs' top", relPoint, "TOPLEFT")

-- Every anchor choice.
C.Set("target", "debuffsAnchor", "HEALTH")
H.check("health bar", select(2, anchor(debuffs)), t.health)
C.Set("target", "debuffsAnchor", "POWER")
H.check("power bar", select(2, anchor(debuffs)), t.power)
C.Set("target", "powerEnabled", false)
H.check("power bar off: health bar", select(2, anchor(debuffs)), t.health)
C.Set("target", "powerEnabled", true)
C.Set("target", "debuffsAnchor", "CASTBAR")
H.check("castbar", select(2, anchor(debuffs)), t.castbar)
C.Set("target", "castbarEnabled", false)
H.check("castbar off: frame", select(2, anchor(debuffs)), t)
C.Set("target", "castbarEnabled", true)
C.Set("pet", "debuffsAnchor", "CASTBAR")
H.check("no castbar (pet): frame", select(2, anchor(ns.Frames.pet.auras.debuffs)), ns.Frames.pet)
-- Groups anchored to each other: the debuffs hang from the frame.
C.Set("target", "debuffsAnchor", "OTHER")
H.check("cycle broken", select(2, anchor(debuffs)), t)
C.Set("target", "buffsAnchor", "FRAME")
H.check("debuffs on the buffs", select(2, anchor(debuffs)), buffs.holder)
C.ResetScope("target")
C.Set("target", "debuffsFramePoint", "BOTTOMRIGHT")
C.Set("target", "debuffsPoint", "TOPRIGHT")
C.Set("target", "debuffsX", -3)
C.Set("target", "debuffsY", -5)
point, rel, relPoint, x, y = anchor(debuffs)
H.check("chosen point", point, "TOPRIGHT")
H.check("chosen frame point", relPoint, "BOTTOMRIGHT")
H.check("chosen offset", x .. "," .. y, "-3,-5")
C.ResetScope("target")

-- Outside test mode there is nothing to show yet: groups stay empty and
-- one pixel small (another group may hang from them).
H.check("empty", debuffs.count, 0)
H.check("empty holder", debuffs.holder:GetWidth(), 1)

-- Test mode: samples on every enabled group of every frame.
local framesBefore = #M.frames
H.checkTrue("test mode on", ns.TestMode.Set(true))
H.check("target debuffs: max samples", debuffs.count, 16)
H.check("target buffs: max samples", buffs.count, 16)
H.check("player buffs off: none", ns.Frames.player.auras.buffs.count, 0)
H.check("player debuffs", ns.Frames.player.auras.debuffs.count, 16)
H.check("tot debuffs off: none", ns.Frames.targettarget.auras.debuffs.count, 0)
H.check("pet debuffs", ns.Frames.pet.auras.debuffs.count, 6)
for i, b in ipairs(P.fakes) do
    H.check("pretend member " .. i .. " debuffs", b.auras.debuffs.count, 6)
    H.check("pretend member " .. i .. " buffs", b.auras.buffs.count, 4)
end
local sample = debuffs.buttons[3]
H.checkTrue("sample shown", sample:IsShown())
H.check("sample icon", sample.icon._texture, Auras.SAMPLES.debuffs[3].icon)
H.check("sample stacks", sample.count:GetText(), "5")
H.check("sample swipe", sample.cooldown._cooldown[2], Auras.SAMPLES.debuffs[3].duration)
H.check("samples repeat", debuffs.buttons[6].icon._texture, Auras.SAMPLES.debuffs[1].icon)

-- Layout: 8 per row, growing right, rows going up, from the holder's
-- bottom left corner. The plain layout: yours first and Auto per row are
-- covered in test_aura_own.lua.
C.Set("target", "debuffsHighlightOwn", false)
C.Set("target", "debuffsPerRow", 8)
local function offset(b)
    local p, _, rp, bx, by = b:GetPoint(1)
    return p .. ">" .. rp .. " " .. bx .. "," .. by
end
H.check("first icon", offset(debuffs.buttons[1]), "BOTTOMLEFT>BOTTOMLEFT 0,0")
H.check("second icon", offset(debuffs.buttons[2]), "BOTTOMLEFT>BOTTOMLEFT 22,0")
H.check("ninth icon: next row up", offset(debuffs.buttons[9]), "BOTTOMLEFT>BOTTOMLEFT 0,22")
H.check("holder width", debuffs.holder:GetWidth(), 8 * 20 + 7 * 2)
H.check("holder height", debuffs.holder:GetHeight(), 42)
H.check("icon size", debuffs.buttons[1]:GetWidth(), 20)

-- Settings apply to the samples; the pool is reused, never rebuilt.
C.Set("target", "debuffsMax", 3)
H.check("max 3", debuffs.count, 3)
H.check("fourth hidden", debuffs.buttons[4]:IsShown(), false)
H.check("pool kept", #debuffs.buttons, 16)
C.Set("target", "debuffsGrowth", "LEFT")
C.Set("target", "debuffsSize", 30)
H.check("growing left", offset(debuffs.buttons[2]), "BOTTOMRIGHT>BOTTOMRIGHT -32,0")
H.check("resized", debuffs.buttons[2]:GetWidth(), 30)
C.Set("target", "debuffsEnabled", false)
H.check("switched off", debuffs.count, 0)
H.check("switched off: hidden", debuffs.buttons[1]:IsShown(), false)
C.ResetScope("target")
H.check("back to 16", debuffs.count, 16)
local made = #M.frames - framesBefore

-- Test mode off: samples go.
ns.TestMode.Set(false)
H.check("samples gone", debuffs.count, 0)
H.check("sample hidden", debuffs.buttons[1]:IsShown(), false)
H.check("pretend party cleared", P.fakes[1].auras.debuffs.count, 0)

-- On again: no new frames (buttons, holders) are made.
local before = #M.frames
ns.TestMode.Set(true)
H.check("no new frames the second time", #M.frames, before)
H.checkTrue("frames made the first time", made > 0)
ns.TestMode.Set(false)
