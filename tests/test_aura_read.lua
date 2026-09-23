local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config

local function aura(id, fields)
    local a = { auraInstanceID = id, icon = 100 + id, applications = 0, duration = 0, expirationTime = 0 }
    for k, v in pairs(fields or {}) do a[k] = v end
    return a
end
M.units.player = { name = "Me", health = 5, healthMax = 10 }
M.units.target = { name = "Foe", health = 5, healthMax = 10, auras = {
    aura(1, { isHelpful = true, mine = true, duration = 60, expirationTime = 1050 }),
    aura(2, { isHelpful = true }),
    aura(3, { dispelName = "Magic", dispellable = true, mine = true }),
    aura(4, { dispelName = "Curse", applications = 2 }),
} }

local t = ns.Frames.target
local buffs, debuffs = t.auras.buffs, t.auras.debuffs

-- A new target: both groups read in full.
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("two buffs", buffs.count, 2)
H.check("two debuffs", debuffs.count, 2)
H.check("buff icon", buffs.buttons[1].icon._texture, 101)
H.check("debuff stacks", debuffs.buttons[2].count:GetText(), "2")
H.check("debuff border: curse", debuffs.buttons[2].border._color[3], 1)
H.check("query unit", M.lastAuraQuery.unit, "target")
-- Target debuffs show yours first: the last list is everyone else's.
H.check("query filter", M.lastAuraQuery.filter, "HARMFUL|!PLAYER")
H.check("query capped at the maximum", M.lastAuraQuery.maxCount, 16)
H.check("client sorts: mine first", M.lastAuraQuery.sortRule, Enum.UnitAuraSortRule.Default)
H.check("holder fits two icons: yours (26) above the other (20)", debuffs.holder:GetWidth() .. "x"
    .. debuffs.holder:GetHeight(), "26x48")

-- Filters: only mine, only dispellable.
C.Set("target", "buffsOnlyMine", true)
H.check("only my buffs", buffs.count, 1)
H.check("only mine: filter", buffs.filter, "HELPFUL|PLAYER")
C.Set("target", "debuffsDispellable", true)
H.check("only dispellable", debuffs.count, 1)
H.check("dispellable: filter", debuffs.filter, "HARMFUL|RAID")
C.ResetScope("target")

-- The maximum holds even if the client sends more.
for i = 5, 30 do table.insert(M.units.target.auras, aura(i)) end
M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
H.check("capped debuffs", debuffs.count, 16)
C.Set("target", "debuffsMax", 5)
H.check("new maximum", debuffs.count, 5)
C.ResetScope("target")
for i = 30, 5, -1 do table.remove(M.units.target.auras, i) end

-- A switched-off group asks nothing.
C.Set("target", "buffsEnabled", false)
local queries = M.auraQueries
M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
H.check("debuffs only: yours and the others", M.auraQueries - queries, 2)
H.check("buffs off: empty", buffs.count, 0)
C.ResetScope("target")

-- Secret aura data still shows.
M.units.target.auras[3] = aura(3, { icon = M.Secret(555), dispelName = M.Secret("Magic"), dispelType = M.Secret(1),
    applications = M.Secret(1), duration = M.Secret(10), expirationTime = M.Secret(1010) })
M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
H.check("secret debuff shown", debuffs.count, 2)
H.checkTrue("secret icon", M.IsSecret(debuffs.buttons[1].icon._texture))

-- Refused in combat. A change on the same unit keeps what is shown (the
-- swipes keep running); a new unit shows nothing rather than the old
-- unit's auras.
M.SetCombat(true)
M.auraError = true
M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
H.check("refused: last known kept", debuffs.count, 2)
H.checkTrue("refused: still shown", debuffs.buttons[1]:IsShown())
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("refused on a new target: nothing", debuffs.count, 0)
H.check("refused on a new target: buffs too", buffs.count, 0)
-- Combat ends: every frame reads again.
M.auraError = false
M.SetCombat(false)
H.check("after combat: read again", debuffs.count, 2)
H.check("after combat: buffs", buffs.count, 2)

-- Target of target: no aura events, the frame's timer refreshes it at
-- most every half second.
C.Set("targettarget", "debuffsEnabled", true)
M.units.targettarget = { name = "Other", health = 1, healthMax = 1, auras = { aura(40, { dispelName = "Poison" }) } }
local tot = ns.Frames.targettarget
tot:Show()
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("tot debuff", tot.auras.debuffs.count, 1)
queries = M.auraQueries
M.Tick(0.2)
M.Tick(0.2)
H.check("no aura query inside half a second", M.auraQueries - queries, 0)
M.Tick(0.2)
H.check("then one", M.auraQueries - queries, 1)
M.units.targettarget.auras = {}
M.Tick(0.2); M.Tick(0.2); M.Tick(0.2)
H.check("tot debuff gone", tot.auras.debuffs.count, 0)

-- Party members read their own auras (buffs: only yours by default).
M.units.party1 = { name = "Friend", health = 1, healthMax = 1, auras = {
    aura(50, { dispelName = "Magic" }),
    aura(51, { isHelpful = true, mine = true }),
    aura(52, { isHelpful = true }),
} }
M.SetGroup({ "party1" })
local member = ns.Party.header[1]
H.check("member unit", member.unit, "party1")
H.check("member debuffs", member.auras.debuffs.count, 1)
H.check("member: only my buffs", member.auras.buffs.count, 1)
table.remove(M.units.party1.auras, 1)
M.FireEvent("UNIT_AURA", "party1", { isFullUpdate = true })
H.check("member debuff gone", member.auras.debuffs.count, 0)
