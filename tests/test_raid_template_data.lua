-- The shipped raid templates (Raid/TemplateData.lua): four role templates
-- (Healer, Tank, DPS, Dispel only) and three looks (Forever, Flat,
-- Classic). Every key they name is a raid setting and every value one its
-- setting stores as it is, for every class; Forever is today's defaults
-- exactly; a role template and a look never name the same key.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "DRUID", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = {}
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local T, RS, RC, Raid = ns.RaidTemplates, ns.RaidSettings, ns.RaidConfig, ns.Raid

local function ids(list)
    local out = {}
    for i, t in ipairs(list) do out[i] = t.id end
    return table.concat(out, ",")
end
H.check("role templates", ids(T.ROLES), "healer,tank,dps,dispel")
H.check("looks", ids(T.LOOKS), "forever,flat,classic")
H.check("by id", T.Get("flat"), T.LOOKS[2])
H.check("unknown id", T.Get("nope"), nil)

-- Every shipped key and value, for every class, with the spell book
-- knowing every spell the data names.
for id in pairs(M.spells) do M.known[id] = true end
local classes = ns.RaidBuffData.CLASSES
for _, list in ipairs({ T.ROLES, T.LOOKS }) do
    for _, t in ipairs(list) do
        for _, class in ipairs(classes) do
            for key, v in pairs(T.Values(t, class)) do
                H.checkTrue(t.id .. ": known key " .. key, RS.Get(key))
                if RS.Get(key) and type(v) == "table" and v[10] ~= nil then
                    for _, size in ipairs(Raid.SIZES) do
                        H.checkTrue(t.id .. ": valid " .. key .. " at " .. size, T.Valid(key, v[size]))
                    end
                elseif RS.Get(key) then
                    H.checkTrue(t.id .. " (" .. class .. "): valid " .. key, T.Valid(key, v))
                end
            end
            H.checkTrue(t.id .. " (" .. class .. "): changes", T.Changes(t, Raid.SIZES, class))
        end
    end
end

-- Forever is today's defaults exactly; every look names the same keys,
-- and only appearance keys.
local forever = T.Values(T.Get("forever"))
local lookKeys = {}
for key, v in pairs(forever) do
    lookKeys[#lookKeys + 1] = key
    for _, size in ipairs(Raid.SIZES) do
        local want = RS.Default(RS.Get(key), Raid.Scope(size))
        local got = type(v) == "table" and v[10] ~= nil and v[size] or v
        if type(want) == "table" then
            for i = 1, 4 do H.check("forever " .. key .. " " .. size .. "." .. i, got[i], want[i]) end
        else
            H.check("forever " .. key .. " " .. size, got, want)
        end
    end
end
table.sort(lookKeys)
H.check("appearance keys", table.concat(lookKeys, ","), table.concat(T.LOOK_KEYS_SORTED, ","))
for _, look in ipairs(T.LOOKS) do
    local keys = {}
    for key in pairs(T.Values(look)) do keys[#keys + 1] = key end
    table.sort(keys)
    H.check(look.id .. ": the appearance keys", table.concat(keys, ","), table.concat(lookKeys, ","))
end
local isLook = {}
for _, key in ipairs(lookKeys) do isLook[key] = true end
for _, role in ipairs(T.ROLES) do
    for _, class in ipairs(classes) do
        for key in pairs(T.Values(role, class)) do
            H.check(role.id .. " leaves the look alone: " .. key, isLook[key], nil)
        end
    end
end

-- Forever on an untouched size changes nothing.
T.Apply(T.Get("forever"), Raid.SIZES)
for _, size in ipairs(Raid.SIZES) do H.check("forever: no override at " .. size, next(RC.Profile()[Raid.Scope(size)]), nil) end

-- Healer for a druid: wider cells, heals, debuffs, range, the buff watch,
-- its heals over time as corner indicators (every rank the book knows).
T.Apply(T.Get("healer"), { 10 })
H.checkTrue("healer: wider cells", RC.Get("r10", "cellWidth") > RS.Default(RS.Get("cellWidth"), "r10"))
H.check("healer: deficit", RC.Get("r10", "secondLine"), "DEFICIT")
H.check("healer: heal prediction", RC.Get("r10", "healPrediction"), true)
H.check("healer: overheal", RC.Get("r10", "overheal"), true)
H.check("healer: absorbs", RC.Get("r10", "absorbs"), true)
H.check("healer: debuff row", RC.Get("r10", "debuffRow"), true)
H.check("healer: dispel icon", RC.Get("r10", "dispelIcon"), true)
H.check("healer: range", RC.Get("r10", "rangeFade"), true)
H.check("healer: buff watch", RC.Get("general", "buffWatchShow"), true)
H.check("healer: rejuvenation, every rank", RC.Get("r10", "indicatorTopLeftSpells"), "774,1058")
H.check("healer: regrowth", RC.Get("r10", "indicatorTopRightSpells"), "8936")
H.check("healer: lifebloom", RC.Get("r10", "indicatorBottomLeftSpells"), "33763")
H.check("healer: own casts", RC.Get("r10", "indicatorTopLeftOwn"), true)

-- A spell the book does not know is left out.
M.known[33763] = nil
local values = T.Values(T.Get("healer"), "DRUID")
H.check("unknown hot left out", values.indicatorBottomLeftSpells, nil)
-- A class without buffs or heals over time: none of that.
values = T.Values(T.Get("healer"), "WARRIOR")
H.check("warrior healer: no buff watch key", values.buffWatchShow, nil)
H.check("warrior healer: no indicator", values.indicatorTopLeftSpells, nil)

-- Tank, DPS, dispel only.
T.Apply(T.Get("tank"), { 20 })
H.checkTrue("tank: compact", RC.Get("r20", "cellWidth") < RS.Default(RS.Get("cellWidth"), "r20"))
H.check("tank: aggro", RC.Get("r20", "aggroBorder"), true)
H.check("tank: main tanks", RC.Get("r20", "mainTanksShow"), true)
H.check("tank: no heal prediction", RC.Get("r20", "healPrediction"), false)
T.Apply(T.Get("dps"), { 40 })
H.check("dps: by group", RC.Get("r40", "groupBy"), "GROUP")
H.check("dps: every group in a line", RC.Get("r40", "blocksPerLine"), 8)
H.check("dps: no second line", RC.Get("r40", "secondLine"), "NONE")
H.check("dps: no heal prediction", RC.Get("r40", "healPrediction"), false)
H.check("dps: only your dispels", RC.Get("r40", "dispelFilter"), "MINE")
T.Apply(T.Get("dispel"), { 40 })
H.check("dispel: no second line", RC.Get("r40", "secondLine"), "NONE")
H.checkTrue("dispel: a large icon", RC.Get("r40", "dispelIconSize") > RS.Default(RS.Get("dispelIconSize"), "r40"))
H.check("dispel: tinted", RC.Get("r40", "dispelTint"), true)

-- Looks only touch appearance: Flat has no ring, thin borders.
T.Apply(T.Get("flat"), { 40 })
H.check("flat: square corners", RC.Get("r40", "cellCornerRadius"), 0)
H.check("flat: flat style", RC.Get("r40", "cellBorderStyle"), "FLAT")
H.check("flat: thin", RC.Get("r40", "cellBorderSize"), 1)
H.check("flat: the role stays", RC.Get("r40", "dispelTint"), true)

-- The defaults of each size, whatever the kind of value: a colour that
-- differs per size too (a setting made for the test).
RS.Define({ key = "testSizedColor", code = "ZZ", scope = "frame", type = "color",
    default = { r10 = { 1, 0, 0, 1 }, r20 = { 0, 1, 0, 1 }, _ = { 0, 0, 1, 1 } } })
local sized = T.SizeDefaults({ "testSizedColor", "cellWidth", "cellSpacing" })
for _, size in ipairs(Raid.SIZES) do
    local changes = T.Changes({ id = "d", values = sized }, { size })
    local got = {}
    for _, pair in ipairs(changes[1].values) do got[pair[1]] = pair[2] end
    local want = RS.Default(RS.Get("testSizedColor"), Raid.Scope(size))
    H.check("sized colour " .. size, table.concat(got.testSizedColor, ","), table.concat(want, ","))
    H.check("sized width " .. size, got.cellWidth, RS.Default(RS.Get("cellWidth"), Raid.Scope(size)))
    H.check("same at every size " .. size, got.cellSpacing, 2)
end
