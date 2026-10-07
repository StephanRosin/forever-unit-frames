-- The buff watch's state (Raid/BuffWatch.lua): your class's watched buffs
-- on the members of your group, read out of combat (throttled), never
-- guessed while auras are secret.
local M = H.M
local ns = H.LoadAddon()
local RC, Watch = ns.RaidConfig, ns.RaidBuffWatch
ns.Config.Use({})
ns.RaidProfiles.Attach({})

M.units.player = { name = "Tester", class = "PRIEST", className = "Priest", isPlayer = true }
M.known[1243], M.known[1244] = true, true

local function ids(list)
    local out = {}
    for i, e in ipairs(list) do out[i] = e.id end
    return table.concat(out, ",")
end

-- What is watched: your class's buffs the spell book knows, switched on.
H.check("priest: fortitude only (no spirit known, shadow protection off)", ids(Watch.Watched()), "fortitude")
local fort = Watch.Watched()[1]
H.check("cast rank: the highest known", fort.single.id, 1244)
H.check("its name", fort.single.name, "Power Word: Fortitude")
H.check("the group form's name, unlearned", fort.group.name, "Prayer of Fortitude")
H.check("the group form: no rank to cast", fort.group.id, nil)
M.known[976] = true
RC.Set("general", "buffShadowProtection", true)
H.check("shadow protection switched on", ids(Watch.Watched()), "fortitude,shadowProtection")
RC.Set("general", "buffFortitude", false)
H.check("fortitude switched off", ids(Watch.Watched()), "shadowProtection")
RC.Set("general", "buffFortitude", true)
RC.Set("general", "buffShadowProtection", false)

-- Solo: nobody to watch.
Watch.Scan()
H.check("solo: no members", #Watch.Members(), 0)

-- A party: you and the others.
local function member(name, class, extra)
    local d = { name = name, class = class, className = class, isPlayer = true, health = 100, healthMax = 100,
        auras = {} }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end
local function fortAura(left, name)
    return { name = name or "Power Word: Fortitude", spellId = 1244, isHelpful = true, duration = 1800,
        expirationTime = M.now + left }
end
M.units.player.auras = { fortAura(1700) }
M.units.party1 = member("Ann", "WARRIOR", { auras = { fortAura(120) } })
M.units.party2 = member("Bob", "MAGE")
M.units.party3 = member("Cid", "ROGUE", { auras = { fortAura(1000, "Prayer of Fortitude") } })
M.units.party4 = member("Dee", "MAGE", { dead = true })
M.SetGroup({ "party1", "party2", "party3", "party4" })
H.check("party: five members", #Watch.Members(), 5)
Watch.Scan()
local st = Watch.state.entries[1]
H.check("one entry", #Watch.state.entries, 1)
H.check("missing: Bob (the dead are left out)", st.missing, 1)
H.check("expiring: Ann (2 of 5 minutes)", st.expiring, 1)
H.check("the group form counts as the buff", st.unknown, false)
H.checkTrue("Bob misses it", Watch.state.missingUnits.party2)
H.check("Ann does not miss it", Watch.state.missingUnits.party1, nil)
-- Who needs it, least time left first: the missing, then the expiring.
H.check("needs: two", #st.needs, 2)
H.check("first: the missing one", st.needs[1].unit, "party2")
H.check("then the expiring one", st.needs[2].unit, "party1")

-- The threshold is a setting.
RC.Set("general", "buffExpiring", 1)
Watch.Scan()
H.check("1 minute: Ann not expiring", Watch.state.entries[1].expiring, 0)
RC.Set("general", "buffExpiring", 5)

-- A buff without an end (expirationTime 0) never runs out.
M.units.party1.auras = { fortAura(0) }
M.units.party1.auras[1].expirationTime = 0
Watch.Scan()
H.check("no end: not expiring", Watch.state.entries[1].expiring, 0)
-- Its time secret: it is there, its time unknown: not expiring.
M.units.party1.auras = { fortAura(60) }
M.units.party1.auras[1].expirationTime = M.Secret(M.now + 60)
Watch.Scan()
H.check("secret time: there, not expiring", Watch.state.entries[1].expiring, 0)
H.check("secret time: not missing", Watch.state.entries[1].missing, 1)

-- Auras secret: unknown, never guessed; nothing marked missing.
M.aurasSecret = true
Watch.Scan()
H.check("secret auras: unknown", Watch.state.entries[1].unknown, true)
H.check("secret auras: nobody marked", next(Watch.state.missingUnits), nil)
M.aurasSecret = false
-- One spell's auras secret: that buff unknown.
M.secretSpellAuras[1243] = true
Watch.Scan()
H.check("secret spell aura: unknown", Watch.state.entries[1].unknown, true)
M.secretSpellAuras[1243] = nil
-- The client refuses aura queries: unknown, no error.
M.auraError = true
Watch.Scan()
H.check("refused: unknown", Watch.state.entries[1].unknown, true)
M.auraError = false

-- In combat nothing is read: the last state stays.
Watch.Scan()
local before = Watch.state
M.SetCombat(true)
local queries = M.auraNameQueries
M.units.party2.auras = { fortAura(1700) }
Watch.Scan()
H.check("in combat: no aura read", M.auraNameQueries, queries)
H.check("in combat: the state stays", Watch.state, before)
M.SetCombat(false)
M.Tick(1)
H.check("after combat: read again", Watch.state.entries[1].missing, 0)

-- Throttled: an aura change marks the state for a scan; it runs on the
-- next update after the throttle, once for many changes.
M.units.party2.auras = {}
local scans = Watch.scans
M.FireEvent("UNIT_AURA", "party2")
M.FireEvent("UNIT_AURA", "party1")
H.check("not at once", Watch.scans, scans)
M.Tick(Watch.THROTTLE)
H.check("once after the throttle", Watch.scans, scans + 1)
H.check("Bob misses it again", Watch.state.entries[1].missing, 1)
M.Tick(Watch.THROTTLE)
H.check("no change: no scan", Watch.scans, scans + 1)
-- A rescan now and then: a buff runs out without an event.
M.Tick(Watch.RESCAN)
H.check("rescan", Watch.scans, scans + 2)

-- Who a buff is for: Arcane Intellect on those who use mana.
M.units.player.class = "MAGE"
M.known[1459] = true
H.check("mage: intellect", ids(Watch.Watched()), "intellect")
M.units.party2.auras = {}
Watch.Scan()
local ai = Watch.state.entries[1]
H.check("intellect: the warrior and the rogue left out", ai.missing, 2)
M.known[1459] = nil

-- Thorns on tanks only.
M.units.player.class = "DRUID"
M.known[467] = true
RC.Set("general", "buffThorns", true)
RC.Set("general", "buffWild", false)
M.units.party1.role = "TANK"
Watch.Scan()
H.check("thorns: the tank only", Watch.state.entries[1].missing, 1)
H.check("thorns: on the tank", Watch.state.entries[1].needs[1].unit, "party1")

-- A paladin: one entry per blessing chosen for a class of the members.
M.units.player.class = "PALADIN"
M.known[19740], M.known[19742] = true, true
local watched = ids(Watch.Watched())
H.check("paladin: might and wisdom", watched, "blessingMIGHT,blessingWISDOM")
Watch.Scan()
local might = Watch.state.entries[1]
H.check("might: the warrior and the rogue (by class)", might.missing, 2)
RC.Set("general", "blessingROGUE", "NONE")
Watch.Scan()
H.check("rogues: none", Watch.state.entries[1].missing, 1)
-- A class token secret: no blessing can be chosen for that member.
M.units.party1.class = M.Secret("WARRIOR")
Watch.Scan()
H.check("secret class: left out", Watch.state.entries[1].missing, 0)

-- A raid: raid1..n, groups from the roster.
M.units.player.class = "PRIEST"
M.SetGroup({})
M.SetRaidRoster({
    { name = "R1", class = "MAGE", subgroup = 1 },
    { name = "R2", class = "MAGE", subgroup = 2, assignedRole = "TANK" },
    { name = "R3", class = "WARRIOR", subgroup = 2, role = "MAINTANK" },
})
local members = Watch.Members()
H.check("raid: three", #members, 3)
H.check("raid group of R2", members[2].group, 2)
H.check("R2 a tank (assigned)", members[2].tank, true)
H.check("R3 a tank (main tank)", members[3].tank, true)
H.check("R1 not", members[1].tank, false)
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
