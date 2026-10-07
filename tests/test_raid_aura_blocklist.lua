-- Hidden auras on the raid cells: the size's list and the unit frames'
-- account list leave their spells out of the buff indicators and the
-- debuff row (the containers' excludeSpellIDs). On group members the
-- client hides buffs by spell, debuffs only when it flags the spell
-- never-secret. The list of a size the panel does not show changes
-- nothing; in combat the change waits.
local M = H.M
local ns = H.LoadAddon()
local RC, C, Header = ns.RaidConfig, ns.Config, ns.RaidHeader
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 }, { name = "Bob", class = "MAGE", subgroup = 1 } })
M.RunTimers()

local RENEW, FOOD, SATED, CURSE = 139, 19705, 57724, 1714
M.neverSecretSpells[SATED] = true
local cell = Header.headers[1]:GetAttribute("child1")
local c = cell.raidAuras.container
M.units[cell.unit].auras = {
    { auraInstanceID = 1, spellId = RENEW, isHelpful = true, mine = true, duration = 15 },
    { auraInstanceID = 2, spellId = FOOD, isHelpful = false, duration = 30 },
    { auraInstanceID = 3, spellId = SATED, isHelpful = false, duration = 600 },
    { auraInstanceID = 4, spellId = CURSE, isHelpful = false, duration = 60 },
}

RC.Set("r10", "indicatorTopLeftSpells", tostring(RENEW))
RC.Set("r10", "debuffRow", true)
local function exclude(f)
    local ids = {}
    for id in pairs(f and f.excludeSpellIDs or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    return table.concat(ids, ",")
end
local slot = c._slots.indicatorTOPLEFT
local row = c._groups.debuffs
H.check("empty lists: indicator shows", table.concat(M.AuraContainerShows(c, "indicatorTOPLEFT", true), ","),
    tostring(RENEW))
H.check("empty lists: the row has no filter", row.candidateFilters, nil)
H.check("empty lists: the row shows all", table.concat(M.AuraContainerShows(c, "debuffs"), ","),
    FOOD .. "," .. SATED .. "," .. CURSE)

-- The size's list.
RC.Set("r10", "auraBlock", RENEW .. ", " .. SATED)
H.check("indicator: excluded", exclude(c._slots.indicatorTOPLEFT.candidateFilters), RENEW .. "," .. SATED)
H.check("indicator: its spells kept", slot.candidateFilters.includeSpellIDs[RENEW], true)
H.check("indicator: a hidden buff does not show", #M.AuraContainerShows(c, "indicatorTOPLEFT", true), 0)
H.check("row: excluded", exclude(row.candidateFilters), RENEW .. "," .. SATED)
H.check("row: never-secret debuff hidden, others stay", table.concat(M.AuraContainerShows(c, "debuffs"), ","),
    FOOD .. "," .. CURSE)
-- The account list joins in.
C.Set("general", "auraBlockAccount", tostring(FOOD))
H.check("row: account list too", exclude(row.candidateFilters), RENEW .. "," .. FOOD .. "," .. SATED)
H.check("row: a debuff the client keeps on members", table.concat(M.AuraContainerShows(c, "debuffs"), ","),
    FOOD .. "," .. CURSE)
-- Another size's list changes nothing shown.
RC.Set("r20", "auraBlock", tostring(CURSE))
H.check("another size: nothing", exclude(row.candidateFilters), RENEW .. "," .. FOOD .. "," .. SATED)

-- In combat: after combat.
M.SetCombat(true)
RC.Set("r10", "auraBlock", "")
H.check("combat: unchanged", exclude(row.candidateFilters), RENEW .. "," .. FOOD .. "," .. SATED)
M.SetCombat(false)
M.RunTimers()
H.check("after combat: only the account's", exclude(row.candidateFilters), tostring(FOOD))
C.Set("general", "auraBlockAccount", "")
M.RunTimers()
H.check("both empty: no filter", row.candidateFilters, nil)
H.check("indicator: back to its spells", exclude(slot.candidateFilters), "")
H.check("no errors", #M.errors, 0)
