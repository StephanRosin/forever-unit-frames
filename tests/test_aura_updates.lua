local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()

local function aura(id, fields)
    local a = { auraInstanceID = id, icon = 100 + id, applications = 0, duration = 0, expirationTime = 0 }
    for k, v in pairs(fields or {}) do a[k] = v end
    return a
end
local list = {
    aura(1, { isHelpful = true }),
    aura(2, { isHelpful = true }),
    aura(3, { dispelName = "Magic" }),
}
M.units.target = { name = "Foe", health = 5, healthMax = 10, auras = list }
local t = ns.Frames.target
local buffs, debuffs = t.auras.buffs, t.auras.debuffs
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("start: buffs", buffs.count, 2)
H.check("start: debuffs", debuffs.count, 1)

local function counted(fn)
    local q, l = M.auraQueries, M.auraLookups
    fn()
    return (M.auraQueries - q) .. " lists, " .. (M.auraLookups - l) .. " lookups"
end

-- A shown aura changed (stacks): only that icon is asked for again.
list[3].applications = 4
H.check("updated: one lookup", counted(function()
    M.FireEvent("UNIT_AURA", "target", { updatedAuraInstanceIDs = { 3 } })
end), "0 lists, 1 lookups")
H.check("updated: new stacks", debuffs.buttons[1].count:GetText(), "4")

-- An aura that is not shown changed: nothing to do.
H.check("updated elsewhere: nothing", counted(function()
    M.FireEvent("UNIT_AURA", "target", { updatedAuraInstanceIDs = { 99 } })
end), "0 lists, 0 lookups")

-- A new debuff: only the debuffs are read again. The target shows your
-- debuffs first, so reading them takes two lists: yours, then the rest.
list[4] = aura(4, { dispelName = "Poison" })
H.check("added debuff: the debuffs' two lists", counted(function()
    M.FireEvent("UNIT_AURA", "target", { addedAuras = { list[4] } })
end), "2 lists, 0 lookups")
H.check("added debuff shown", debuffs.count, 2)
H.check("filter of that list", M.lastAuraQuery.filter, "HARMFUL|!PLAYER")

-- A new buff someone else cast while buffs show only mine: nothing.
ns.Config.Set("target", "buffsOnlyMine", true)
list[5] = aura(5, { isHelpful = true })
H.check("added, filtered out: nothing", counted(function()
    M.FireEvent("UNIT_AURA", "target", { addedAuras = { list[5] } })
end), "0 lists, 0 lookups")
ns.Config.ResetScope("target")
H.check("buffs back", buffs.count, 3)

-- A shown buff went: the buffs are read again, the debuffs are not.
table.remove(list, 1)
H.check("removed buff: one list", counted(function()
    M.FireEvent("UNIT_AURA", "target", { removedAuraInstanceIDs = { 1 } })
end), "1 lists, 0 lookups")
H.check("removed buff gone", buffs.count, 2)
H.check("filter of that list", M.lastAuraQuery.filter, "HELPFUL")
H.check("removed, not shown: nothing", counted(function()
    M.FireEvent("UNIT_AURA", "target", { removedAuraInstanceIDs = { 77 } })
end), "0 lists, 0 lookups")

-- An updated aura that is gone by now: its group is read again.
H.check("updated, still there: one lookup", counted(function()
    M.FireEvent("UNIT_AURA", "target", { updatedAuraInstanceIDs = { 2 }, removedAuraInstanceIDs = {} })
end), "0 lists, 1 lookups")
table.remove(list, 1)
H.check("lookup finds nothing: group read", counted(function()
    M.FireEvent("UNIT_AURA", "target", { updatedAuraInstanceIDs = { 2 } })
end), "1 lists, 1 lookups")
H.check("gone buff removed", buffs.count, 1)

-- Full updates, missing or secret details: everything is read (one list
-- for the buffs, two for the debuffs).
H.check("full update", counted(function()
    M.FireEvent("UNIT_AURA", "target", { isFullUpdate = true })
end), "3 lists, 0 lookups")
H.check("no info", counted(function()
    M.FireEvent("UNIT_AURA", "target")
end), "3 lists, 0 lookups")
H.check("secret full flag", counted(function()
    M.FireEvent("UNIT_AURA", "target", { isFullUpdate = M.Secret(false) })
end), "3 lists, 0 lookups")
H.check("secret removed id", counted(function()
    M.FireEvent("UNIT_AURA", "target", { removedAuraInstanceIDs = { M.Secret(3) } })
end), "3 lists, 0 lookups")
H.check("secret added id", counted(function()
    M.FireEvent("UNIT_AURA", "target", { addedAuras = { aura(9, { auraInstanceID = M.Secret(9) }) } })
end), "3 lists, 0 lookups")

-- Refused in combat: the full read that follows keeps the icons.
M.SetCombat(true)
M.auraError = true
local shown = debuffs.count
M.FireEvent("UNIT_AURA", "target", { addedAuras = { aura(10, { dispelName = "Curse" }) } })
H.check("refused: icons kept", debuffs.count, shown)
M.auraError = false
M.SetCombat(false)

-- No tables are made per event beyond what the client hands in: the
-- button pool does not grow for updates of shown auras.
local before = #M.frames
for _ = 1, 50 do M.FireEvent("UNIT_AURA", "target", { updatedAuraInstanceIDs = { 3 } }) end
H.check("no frames made by updates", #M.frames, before)
