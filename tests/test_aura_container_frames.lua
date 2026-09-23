-- Each frame's aura groups as containers: made once, configured from the
-- settings out of combat, anchored like the holders.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local AC, C, Auras = ns.AuraContainers, ns.Config, ns.Auras
M.units.target = { name = "Foe", health = 5, healthMax = 10 }
local t = ns.Frames.target

H.checkTrue("target: containers", AC.Ensure(t))
local buffs, debuffs = t.auraContainers.buffs, t.auraContainers.debuffs
local bc, dc = buffs.container, debuffs.container
H.check("buffs container parent", bc:GetParent(), t)
H.check("template", dc._template, "CustomAuraContainerTemplate")
H.check("unit", dc:GetUnit(), "target")
H.check("groups in order", table.concat(dc._groupOrder, ","), "own,other")
H.check("level above the bars", dc:GetFrameLevel(), t:GetFrameLevel() + Auras.LEVELS)
H.checkTrue("shown", dc:IsShown())
H.check("made once", AC.Ensure(t), true)
H.check("still the same", t.auraContainers.debuffs.container, dc)
H.check("two containers plus the test one", #M.auraContainers, 3)

-- Target debuffs: yours first (default) at 26, the rest at 20 on a new line.
H.check("own on", dc._groups.own.enabled, true)
H.check("own filter", dc._groups.own.filter, "HARMFUL|PLAYER")
H.check("other filter", dc._groups.other.filter, "HARMFUL|!PLAYER")
H.check("other new line", dc._groups.other.layout.forceNewLine, true)
H.check("own layout size", dc._groups.own.layout.elementWidth, 26)
H.check("max", dc._groups.other.max, 16)
H.check("own buttons at 26", debuffs.buttons[1].button:GetWidth(), 26)
H.check("other buttons at 20", debuffs.buttons[M.AURA_BATCH + 1].button:GetWidth(), 20)
-- Target buffs: not first, so "own" is off and "other" shows all.
H.check("buffs own off", bc._groups.own.enabled, false)
H.check("buffs other: all", bc._groups.other.filter, "HELPFUL")
-- Flow: right, rows up, from the bottom left; Auto wraps at the width.
H.check("flow anchor", dc._flow.anchor, "BOTTOMLEFT")
H.check("flow growth", dc._flow.horizontal .. "," .. dc._flow.vertical, "1,1")
H.check("flow row length", dc._flow.lineSize, C.Get("target", "width"))
-- Anchors: debuffs on the frame, buffs on the debuffs container.
local p, rel, rp, x, y = dc:GetPoint(1)
H.check("debuffs anchor", p .. ">" .. rp .. " " .. x .. "," .. y, "BOTTOMLEFT>TOPLEFT 0,2")
H.check("debuffs on the frame", rel, t)
H.check("buffs on the debuffs container", select(2, bc:GetPoint(1)), dc)

-- Settings apply at once out of combat.
C.Set("target", "debuffsHighlightOwn", false)
H.check("own off", dc._groups.own.enabled, false)
H.check("other: everything", dc._groups.other.filter, "HARMFUL")
H.check("no new line", dc._groups.other.layout.forceNewLine, false)
C.Set("target", "debuffsHighlightOwn", true)
C.Set("target", "debuffsOnlyMine", true)
H.check("only mine: own", dc._groups.own.filter, "HARMFUL|PLAYER")
H.check("only mine: other off", dc._groups.other.enabled, false)
C.Set("target", "debuffsDispellable", true)
H.check("dispellable", dc._groups.own.filter, "HARMFUL|PLAYER|RAID")
C.ResetScope("target")
C.Set("target", "debuffsSize", 30)
C.Set("target", "debuffsOwnSize", 36)
H.check("other buttons resized", debuffs.buttons[M.AURA_BATCH + 1].button:GetWidth(), 30)
H.check("own buttons resized", debuffs.buttons[1].button:GetWidth(), 36)
H.check("layout follows", dc._groups.other.layout.elementWidth, 30)
C.Set("target", "debuffsPerRow", 4)
H.check("4 per row", dc._flow.lineSize, 4 * 30 + 3 * 2)
C.Set("target", "debuffsGrowth", "LEFT")
C.Set("target", "debuffsRowGrowth", "DOWN")
H.check("left, down: corner", dc._flow.anchor, "TOPRIGHT")
H.check("left, down: growth", dc._flow.horizontal .. "," .. dc._flow.vertical, "-1,-1")
C.Set("target", "debuffsMax", 5)
H.check("max per part", dc._groups.own.max .. "," .. dc._groups.other.max, "5,5")
C.Set("target", "debuffsShowTime", false)
H.check("time left hidden", debuffs.buttons[1].button.cooldown._hideNumbers, true)
C.Set("target", "debuffsEnabled", false)
H.check("off: hidden", dc:IsShown(), false)
H.check("off: parts off", tostring(dc._groups.own.enabled) .. tostring(dc._groups.other.enabled), "falsefalse")
C.ResetScope("target")
H.checkTrue("on again", dc:IsShown())

-- Anchor choices; the containers hang from each other, never in a circle.
C.Set("target", "debuffsAnchor", "HEALTH")
H.check("health bar", select(2, dc:GetPoint(1)), t.health)
C.Set("target", "debuffsAnchor", "OTHER")
H.check("cycle broken", select(2, dc:GetPoint(1)), t)
C.Set("target", "buffsAnchor", "FRAME")
H.check("debuffs on the buffs container", select(2, dc:GetPoint(1)), bc)
H.check("buffs on the frame", select(2, bc:GetPoint(1)), t)
C.ResetScope("target")
H.check("back: buffs on the debuffs", select(2, bc:GetPoint(1)), dc)

-- In combat nothing changes until it ends.
M.SetCombat(true)
C.Set("target", "debuffsSize", 24)
Auras.Style(t)
H.check("combat: layout kept", dc._groups.other.layout.elementWidth, 20)
-- (Read raw: the button refuses its own methods in combat.)
H.check("combat: buttons kept", debuffs.buttons[M.AURA_BATCH + 1].button._w, 20)
M.SetCombat(false)
H.check("after combat: layout", dc._groups.other.layout.elementWidth, 24)
H.check("after combat: buttons", debuffs.buttons[M.AURA_BATCH + 1].button:GetWidth(), 24)
C.ResetScope("target")

-- Auras secret out of combat (an instance): the buttons refuse, the
-- layout is set anyway, the buttons follow after the next combat.
M.aurasSecret = true
C.Set("target", "debuffsSize", 22)
H.check("secret: layout", dc._groups.other.layout.elementWidth, 22)
H.check("secret: marked", debuffs.stale, true)
M.aurasSecret = false
H.check("secret: buttons refused", debuffs.buttons[M.AURA_BATCH + 1].button:GetWidth(), 20)
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("retried", debuffs.buttons[M.AURA_BATCH + 1].button:GetWidth(), 22)
H.check("no longer stale", debuffs.stale, false)
C.ResetScope("target")

-- Made in combat: only after it ends.
local f = ns.Frames.focus
M.SetCombat(true)
H.check("combat: counts as containers", AC.Ensure(f), true)
H.check("combat: none made yet", f.auraContainers, nil)
M.SetCombat(false)
H.checkTrue("made after combat", f.auraContainers)
H.check("focus unit", f.auraContainers.debuffs.container:GetUnit(), "focus")

-- A refusal: nothing kept, the error reported, the frame reads itself.
local pet = ns.Frames.pet
local real = M.NewAuraContainer
M.NewAuraContainer = function(w, template)
    real(w, template)
    if #M.auraContainers > 5 then w.AddAuraGroup = function() error("refused") end end
end
local errors = #M.errors
H.check("refused", AC.Ensure(pet), false)
M.NewAuraContainer = real
H.check("nothing kept", pet.auraContainers, nil)
H.check("reported", #M.errors - errors, 1)
H.check("remembered", AC.Ensure(pet), false)
H.check("half-made container hidden", M.auraContainers[#M.auraContainers]:IsShown(), false)

-- No client support: nothing is made.
ns = H.LoadAddon()
M.auraContainerMissing = true
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.check("unsupported", ns.AuraContainers.Ensure(ns.Frames.target), false)
H.check("unsupported: none", ns.Frames.target.auraContainers, nil)
