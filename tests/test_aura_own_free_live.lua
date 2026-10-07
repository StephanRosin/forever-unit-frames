-- Your own auras placed freely, live (Elements/AuraContainers.lua): a
-- container's groups share one flow and the container one anchor
-- (Blizzard_CustomAuraContainer.lua, Blizzard_AuraContainerFlowLayout.lua),
-- so yours get a second container of their own, made and anchored out of
-- combat; the client still tells yours apart (PLAYER / !PLAYER).
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local AC, C, Auras, Pixel = ns.AuraContainers, ns.Config, ns.Auras, ns.Pixel

local function aura(id, fields)
    local a = { auraInstanceID = id, spellId = 9000 + id, icon = 100 + id, applications = 0, duration = 60,
        expirationTime = 0 }
    for k, v in pairs(fields or {}) do a[k] = v end
    return a
end
M.units.player = { name = "Me", health = 5, healthMax = 10 }
M.units.target = { name = "Foe", hostile = true, health = 5, healthMax = 10,
    auras = { aura(1), aura(2, { mine = true }), aura(3), aura(4, { mine = true }) } }
M.FireEvent("PLAYER_TARGET_CHANGED")
local t = ns.Frames.target
local entry = t.auraContainers.debuffs
local dc = entry.container
local function anchor(c)
    local p, rel, rp, x, y = c:GetPoint(1)
    return p .. ">" .. rp .. " " .. x .. "," .. y, rel
end

-- Default (with the rest): as before, no second container.
local made = #M.auraContainers
H.check("default: no own container", entry.ownContainer, nil)
H.check("default: own part on", dc._groups.own.enabled, true)
H.check("default: the rest on a new line", dc._groups.other.layout.forceNewLine, true)
H.check("default: yours in the container", table.concat(M.AuraContainerShows(dc, "own"), ","),
    "9002,9004")

-- Free: a second container with yours only, at their own place.
C.Set("target", "debuffsOwnPlacement", "FREE")
local oc = entry.ownContainer
H.checkTrue("free: own container", oc)
H.check("free: one made", #M.auraContainers, made + 1)
H.check("free: parent", oc:GetParent(), t)
H.check("free: unit", oc:GetUnit(), "target")
H.check("free: one group", table.concat(oc._groupOrder, ","), "own")
H.check("free: your filter", oc._groups.own.filter, "HARMFUL|PLAYER")
H.check("free: yours there", table.concat(M.AuraContainerShows(oc, "own"), ","), "9002,9004")
H.check("free: own size", oc._groups.own.layout.elementWidth, 26)
H.check("free: max", oc._groups.own.max, 16)
H.check("free: no edit mode preview", oc:IsEditModePreviewEnabled(), false)
H.check("free: level", oc:GetFrameLevel(), t:GetFrameLevel() + Auras.LEVELS)
H.checkTrue("free: shown", oc:IsShown())
-- Its place: right of the frame at its top, 4 out (+1 for the border).
local at, rel = anchor(oc)
H.check("free: anchor", at, "TOPLEFT>TOPRIGHT 5,0")
H.check("free: on the unit box", rel, t.unitBox)
H.check("free: flow from the top left", oc._flow.anchor, "TOPLEFT")
H.check("free: right, rows down", oc._flow.horizontal .. "," .. oc._flow.vertical, "1,-1")
H.check("free: Auto wraps at the width", oc._flow.lineSize, C.Get("target", "width") + Pixel.One() / 2)
-- The main container: yours gone from it, the rest from the first row.
H.check("free: own part off in the group", dc._groups.own.enabled, false)
H.check("free: the rest on", dc._groups.other.enabled, true)
H.check("free: the rest without a new line", dc._groups.other.layout.forceNewLine, false)
H.check("free: the rest's filter", dc._groups.other.filter, "HARMFUL|!PLAYER")
H.check("free: the rest shown", table.concat(M.AuraContainerShows(dc, "other"), ","), "9001,9003")
H.check("free: group place kept", (anchor(dc)), "BOTTOMLEFT>TOPLEFT 0,3")
-- Buttons the own container makes take the own size.
local ownButtons = 0
for _, record in ipairs(entry.buttons) do
    if record.own then ownButtons = ownButtons + 1 end
end
H.checkTrue("free: own buttons made", ownButtons > 0)

-- Its settings apply at once out of combat.
C.Set("target", "debuffsOwnX", 10)
C.Set("target", "debuffsOwnY", -6)
C.Set("target", "debuffsOwnFramePoint", "BOTTOMLEFT")
C.Set("target", "debuffsOwnPoint", "TOPLEFT")
H.check("moved", (anchor(oc)), "TOPLEFT>BOTTOMLEFT 10,-7")
C.Set("target", "debuffsOwnGrowth", "UP")
C.Set("target", "debuffsOwnRowGrowth", "LEFT")
H.check("up, rows left: corner", oc._flow.anchor, "BOTTOMRIGHT")
H.check("up, rows left: wraps at the height", oc._flow.lineSize, C.Get("target", "height") + Pixel.One() / 2)
C.Set("target", "debuffsOwnPerRow", 3)
H.check("3 per row", oc._flow.lineSize, 3 * 26 + 2 * 2 + Pixel.One() / 2)
C.Set("target", "debuffsOwnSize", 30)
H.check("own size follows", oc._groups.own.layout.elementWidth, 30)
C.Set("target", "debuffsMax", 5)
H.check("max follows", oc._groups.own.max, 5)
C.Set("target", "debuffsOnlyMine", true)
H.check("only mine: yours free", oc._groups.own.filter, "HARMFUL|PLAYER")
H.check("only mine: the group off", dc._groups.other.enabled, false)
C.Set("target", "debuffsOnlyMine", false)

-- In combat nothing changes until it ends.
M.SetCombat(true)
C.Set("target", "debuffsOwnX", 30)
C.Set("target", "debuffsOwnPlacement", "WITH")
H.check("combat: place kept", (anchor(oc)), "TOPLEFT>BOTTOMLEFT 10,-7")
H.checkTrue("combat: still shown", oc:IsShown())
H.check("combat: own part still off", dc._groups.own.enabled, false)
M.SetCombat(false)
-- With the rest again: the own container hides and stays for later.
H.check("with the rest: hidden", oc:IsShown(), false)
H.check("with the rest: its group off", oc._groups.own.enabled, false)
H.check("with the rest: own part back", dc._groups.own.enabled, true)
H.check("with the rest: new line back", dc._groups.other.layout.forceNewLine, true)
C.Set("target", "debuffsOwnPlacement", "FREE")
H.check("free again: the same container", entry.ownContainer, oc)
H.checkTrue("free again: shown", oc:IsShown())
-- "Mine first" off: nothing of yours apart.
C.Set("target", "debuffsHighlightOwn", false)
H.check("mine first off: hidden", oc:IsShown(), false)
H.check("mine first off: the group shows all", dc._groups.other.filter, "HARMFUL")
C.Set("target", "debuffsHighlightOwn", true)
-- Group off: both hidden.
C.Set("target", "debuffsEnabled", false)
H.check("group off: hidden", oc:IsShown(), false)
C.Set("target", "debuffsEnabled", true)
H.checkTrue("group on: shown", oc:IsShown())

-- Refreshes reach it: a new target, the unit's change.
local updates = oc._updates
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("new target: refreshed", oc._updates, updates + 1)

-- Test mode: our samples instead, the container hidden; back after.
ns.TestMode.Set(true)
H.check("test: hidden", oc:IsShown(), false)
ns.TestMode.Set(false)
H.checkTrue("test off: back", oc:IsShown())

-- Made in combat: only after it ends (focus).
M.units.focus = { name = "Foe", hostile = true, health = 5, healthMax = 10, auras = { aura(5, { mine = true }) } }
M.FireEvent("PLAYER_FOCUS_CHANGED")
local f = ns.Frames.focus
M.SetCombat(true)
C.Set("focus", "debuffsOwnPlacement", "FREE")
H.check("combat: none made", f.auraContainers.debuffs.ownContainer, nil)
M.SetCombat(false)
H.checkTrue("after combat: made", f.auraContainers.debuffs.ownContainer)
H.check("after combat: unit", f.auraContainers.debuffs.ownContainer:GetUnit(), "focus")

-- Buffs too (target buffs: mine first off by default).
C.Set("target", "buffsHighlightOwn", true)
C.Set("target", "buffsOwnPlacement", "FREE")
local bo = t.auraContainers.buffs.ownContainer
H.checkTrue("buffs: own container", bo)
H.check("buffs: filter", bo._groups.own.filter, "HELPFUL|PLAYER")
H.check("buffs: right of the frame at its bottom", (anchor(bo)), "BOTTOMLEFT>BOTTOMRIGHT 5,0")
H.check("buffs: rows up", bo._flow.vertical, 1)

-- A refusal: the own container is dropped, yours stay with the rest.
local pet = ns.Frames.pet
C.Set("pet", "debuffsHighlightOwn", true)
M.units.pet = { name = "Wolf", health = 5, healthMax = 10 }
AC.Ensure(pet)
local real = M.NewAuraContainer
M.NewAuraContainer = function(w, template)
    real(w, template)
    w.AddAuraGroup = function() error("refused") end
end
H.check("no error before", #M.errors, 0)
local errors = #M.errors
C.Set("pet", "debuffsOwnPlacement", "FREE")
M.NewAuraContainer = real
H.check("refused: none kept", pet.auraContainers.debuffs.ownContainer, nil)
H.check("refused: reported", #M.errors - errors, 1)
H.check("refused: yours with the rest", pet.auraContainers.debuffs.container._groups.own.enabled, true)
C.Set("pet", "debuffsOwnX", 8)
H.check("refused: not tried again", #M.errors - errors, 1)

H.check("nothing blocked", #M.blocked, 0)
