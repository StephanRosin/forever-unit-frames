-- The best next cast (Raid/BuffWatch.lua): the group form when enough
-- members of one group need the buff and its reagent is in the bags, else
-- the single form on the member with the least time left (missing first),
-- in range; a range that is unknown counts as in range.
local M = H.M
local ns = H.LoadAddon()
local RC, Watch = ns.RaidConfig, ns.RaidBuffWatch
ns.Config.Use({})
ns.RaidProfiles.Attach({})

M.units.player = { name = "Tester", class = "PRIEST", className = "Priest", isPlayer = true, auras = {} }
M.known[1243], M.known[1244] = true, true

local function fortAura(left)
    return { name = "Power Word: Fortitude", spellId = 1244, isHelpful = true, duration = 1800,
        expirationTime = M.now + left }
end
local function raider(name, group, extra)
    local m = { name = name, class = "MAGE", subgroup = group, unit = { auras = {}, distance = 20 } }
    for k, v in pairs(extra or {}) do m.unit[k] = v end
    return m
end
M.SetRaidRoster({
    raider("A1", 1, { auras = { fortAura(1700) } }), raider("A2", 1), raider("A3", 1, { auras = { fortAura(100) } }),
    raider("B1", 2), raider("B2", 2), raider("B3", 2), raider("B4", 2, { auras = { fortAura(1700) } }),
})
Watch.Scan()
local st = Watch.state.entries[1]
H.check("missing: four", st.missing, 4)

-- Without Prayer of Fortitude: the single form on the first who needs it.
local cast = Watch.Best(st)
H.check("single form", cast.spell, 1244)
H.check("on a missing one first", cast.unit, "raid2")
H.check("not the group form", cast.groupForm, false)
H.check("the next cast overall", Watch.Next().unit, "raid2")

-- Prayer of Fortitude learned, no candles: still single.
M.known[21564] = true
Watch.Scan()
H.check("no reagent: single", Watch.Best(Watch.state.entries[1]).spell, 1244)
-- Sacred Candles in the bags: the group with three missing gets it.
M.bagItems[17029] = 5
Watch.Scan()
cast = Watch.Best(Watch.state.entries[1])
H.check("group form", cast.spell, 21564)
H.check("group form flagged", cast.groupForm, true)
H.check("on group 2", cast.group, 2)
H.check("on a member of it", cast.unit, "raid4")
-- The threshold is a setting: four needed, group 2 has three.
RC.Set("general", "buffGroupMin", 4)
Watch.Scan()
H.check("below the threshold: single", Watch.Best(Watch.state.entries[1]).spell, 1244)
RC.Set("general", "buffGroupMin", 3)
-- A rank's own reagent: rank 1 takes Holy Candles.
M.known[21564] = nil
M.known[21562] = true
Watch.Scan()
H.check("rank 1 without holy candles: single", Watch.Best(Watch.state.entries[1]).spell, 1244)
M.bagItems[17028] = 1
Watch.Scan()
H.check("rank 1 with a holy candle", Watch.Best(Watch.state.entries[1]).spell, 21562)
-- The count secret (not documented as such; guarded): no group form.
M.bagItems[17028] = M.Secret(1)
Watch.Scan()
H.check("secret count: single", Watch.Best(Watch.state.entries[1]).spell, 1244)
M.bagItems[17028] = 1

-- Out of range: the next one. Range unknown (nil, secret): in range.
M.known[21562] = nil
M.units.raid2.distance = 50
Watch.Scan()
H.check("out of range: skipped", Watch.Best(Watch.state.entries[1]).unit, "raid4")
M.spellRangeSecret = true
H.check("range secret: counts as in range", Watch.Best(Watch.state.entries[1]).unit, "raid2")
M.spellRangeSecret = false
M.units.raid2.distance = nil
H.check("no answer: in range", Watch.Best(Watch.state.entries[1]).unit, "raid2")
M.spellRangeError = true
H.check("an error: in range", Watch.Best(Watch.state.entries[1]).unit, "raid2")
M.spellRangeError = false
-- Everyone out of range: nothing to cast.
for i = 1, 7 do M.units["raid" .. i].distance = 50 end
Watch.Scan()
H.check("all out of range: nothing", Watch.Best(Watch.state.entries[1]), nil)
H.check("nothing next", Watch.Next(), nil)
for i = 1, 7 do M.units["raid" .. i].distance = 20 end

-- Nobody needs it: nothing.
for i = 1, 7 do M.units["raid" .. i].auras = { fortAura(1700) } end
Watch.Scan()
H.check("all buffed: nothing", Watch.Best(Watch.state.entries[1]), nil)
-- The least time left first among the expiring.
M.units.raid5.auras = { fortAura(200) }
M.units.raid6.auras = { fortAura(100) }
Watch.Scan()
H.check("least time left", Watch.Best(Watch.state.entries[1]).unit, "raid6")
-- Unknown: nothing to cast, never a guess.
M.aurasSecret = true
Watch.Scan()
H.check("unknown: nothing", Watch.Best(Watch.state.entries[1]), nil)
M.aurasSecret = false

-- A paladin: the greater blessing by class.
M.units.player.class = "PALADIN"
M.known[19740], M.known[25782] = true, true
M.bagItems[21177] = 10
RC.Set("general", "blessingMAGE", "MIGHT")
for i = 1, 7 do M.units["raid" .. i].auras = {} end
Watch.Scan()
cast = Watch.Best(Watch.state.entries[1])
H.check("greater blessing", cast.spell, 25782)
H.check("by class", cast.group, "MAGE")
H.check("no error", #M.errors, 0)
