-- Range fading in yards (Elements/Range.lua): a mode per reaction
-- (automatic, spell, yards), a range in yards for each, the distance of
-- group members, item probes for everyone else and the follow distance
-- thresholds as the last measure.
local M = H.M

local function boot(class, known)
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = class, className = class, isPlayer = true, health = 1, healthMax = 1 }
    for _, id in ipairs(known or {}) do M.known[id] = true end
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local function target(ns, data)
    data.name, data.health, data.healthMax = data.name or "Boar", 5, 10
    M.units.target = data
    M.FireEvent("PLAYER_TARGET_CHANGED")
    return ns.Frames.target:GetAlpha()
end

-- Settings --------------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local S, L = ns.Settings, ns.L
    local CODES = { rangeFriendlyMode = "VG", rangeHostileMode = "VK", rangeFriendlyYards = "VY",
        rangeHostileYards = "VZ" }
    for key, code in pairs(CODES) do
        local def = S.Get(key)
        H.checkTrue("setting " .. key, def)
        H.check(key .. " code", def and def.code, code)
        H.check(key .. " general only", def and def.scope, "general")
        H.checkTrue(key .. " label", L["SETTING_" .. key] ~= "SETTING_" .. key)
    end
    for _, key in ipairs({ "rangeFriendlyMode", "rangeHostileMode" }) do
        local def = S.Get(key)
        H.check(key .. " values", table.concat(def.values, ","), "AUTO,SPELL,YARDS,OFF")
        H.check(key .. " automatic by default", S.Default(def, "general"), "AUTO")
    end
    H.check("friendly yards default", S.Default(S.Get("rangeFriendlyYards"), "general"), 40)
    H.check("hostile yards default", S.Default(S.Get("rangeHostileYards"), "general"), 30)
    H.check("yards from 5", S.Get("rangeHostileYards").min, 5)
    H.check("yards to 40", S.Get("rangeHostileYards").max, 40)
    local keys
    for _, tab in ipairs(ns.Schema.Tabs("general")) do
        for _, sec in ipairs(tab.sections or {}) do
            if sec.id == "range" then keys = table.concat(sec.keys, ",") end
        end
    end
    H.check("General > Status > Range", keys, "rangeFriendlyMode,rangeFriendlySpell,rangeFriendlyYards,"
        .. "rangeHostileMode,rangeHostileSpell,rangeHostileYards")
end

-- The item table: ranges ascending, each item a number.
do
    local ns = H.LoadAddon()
    for _, reaction in ipairs({ "friendly", "hostile" }) do
        local last = 0
        for _, probe in ipairs(ns.Range.ITEMS[reaction]) do
            H.checkTrue(reaction .. " ranges ascend", probe.range > last)
            last = probe.range
            for _, id in ipairs(probe) do
                H.check(reaction .. " item " .. id .. " matches the mock's range", M.items[id] and M.items[id].range,
                    probe.range)
            end
        end
    end
end

-- Item data is requested at login.
do
    local ns = boot("WARRIOR")
    H.checkTrue("items requested", M.itemLoads > 0)
    H.check("item cached", M.itemCached[835], true)
    -- In combat at login: requested once combat ends.
    ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "WARRIOR", className = "WARRIOR", isPlayer = true, health = 1,
        healthMax = 1 }
    M.combat = true
    M.FireEvent("PLAYER_LOGIN")
    H.check("combat: not yet", M.itemLoads, 0)
    M.SetCombat(false)
    H.checkTrue("after combat: requested", M.itemLoads > 0)
end

-- Warriors: automatic means yards, target and focus fade by default.
do
    local ns = boot("WARRIOR")
    H.check("warrior: target fades by default", ns.Config.Get("target", "rangeFade"), true)
    H.check("warrior: focus fades by default", ns.Config.Get("focus", "rangeFade"), true)
    -- 30 yards: the 30 yard item.
    H.check("enemy at 29: in", target(ns, { hostile = true, distance = 29 }), 1)
    M.units.target.distance = 31
    M.Tick(0.25)
    H.check("enemy at 31: out", ns.Frames.target:GetAlpha(), 0.5)
    H.check("hint: item check", ns.Range.MethodHint("hostile"), ns.L.RANGE_USING_ITEM:format(30))
    -- 22 yards: the closest probe at or below is 20.
    ns.Config.Set("general", "rangeHostileYards", 22)
    H.check("hint: closest item below", ns.Range.MethodHint("hostile"), ns.L.RANGE_USING_ITEM:format(20))
    M.units.target.distance = 21
    M.Tick(0.25)
    H.check("22 yd setting, enemy at 21: item says out", ns.Frames.target:GetAlpha(), 0.5)
    M.units.target.distance = 19
    M.Tick(0.25)
    H.check("enemy at 19: in", ns.Frames.target:GetAlpha(), 1)
    -- In combat hostile probes go on.
    M.combat = true
    M.units.target.distance = 25
    M.Tick(0.25)
    H.check("combat: hostile probe", ns.Frames.target:GetAlpha(), 0.5)
    M.SetCombat(false)
end

-- Items not cached, or no answer: the follow distance at the nearest
-- threshold, then full opacity.
do
    local ns = boot("ROGUE")
    M.itemCached = {}
    M.itemLoadStalls = true
    H.check("not cached: 28 yd threshold for 30", target(ns, { hostile = true, distance = 27 }), 1)
    M.units.target.distance = 29
    M.Tick(0.25)
    H.check("not cached: beyond 28", ns.Frames.target:GetAlpha(), 0.5)
    H.check("hint: follow distance", ns.Range.MethodHint("hostile"), ns.L.RANGE_USING_INTERACT:format(28))
    ns.Config.Set("general", "rangeHostileYards", 9)
    M.units.target.distance = 10.5
    M.Tick(0.25)
    H.check("9 yd: 10 yd threshold", ns.Frames.target:GetAlpha(), 0.5)
    H.check("hint: 10 yd threshold", ns.Range.MethodHint("hostile"), ns.L.RANGE_USING_INTERACT:format(10))
    M.units.target.distance = 9
    M.Tick(0.25)
    H.check("9 yd: near", ns.Frames.target:GetAlpha(), 1)
    -- Nothing answers at all.
    M.units.target.distance, M.units.target.near = nil, "nil"
    M.Tick(0.25)
    H.check("nothing: full", ns.Frames.target:GetAlpha(), 1)
    -- A cached item with no answer (unit without a known distance): the
    -- follow distance decides.
    M.itemLoadStalls = false
    M.itemCached = { [835] = true, [7734] = true, [4941] = true }
    ns.Config.Set("general", "rangeHostileYards", 30)
    M.units.target.near = false
    M.Tick(0.25)
    H.check("item nil: follow distance", ns.Frames.target:GetAlpha(), 0.5)
end

-- Friends in yards: the distance of group members, compared plainly.
do
    local ns = boot("WARRIOR")
    M.units.party1 = { name = "Ann", isPlayer = true, health = 5, healthMax = 10, friend = true, distance = 35,
        inRange = true }
    M.SetGroup({ "party1" })
    local b = ns.Party.buttons[1]
    H.check("40 yd: at 35 in", b:GetAlpha(), 1)
    ns.Config.Set("general", "rangeFriendlyYards", 30)
    M.Tick(0.25)
    H.check("30 yd: at 35 out", b:GetAlpha(), 0.5)
    H.check("hint: distance", ns.Range.MethodHint("friendly"), ns.L.RANGE_USING_DISTANCE:format(30))
    -- Unchecked distance: the friendly item for 30 yards, out of combat.
    M.units.party1.distanceChecked = false
    M.Tick(0.25)
    H.check("unchecked: item says out", b:GetAlpha(), 0.5)
    -- In combat friendly items are not asked: UnitInRange.
    M.combat = true
    M.Tick(0.25)
    H.check("unchecked, combat: UnitInRange", b:GetAlpha(), 1)
    -- Secret distance: never compared.
    M.units.party1.distanceChecked = nil
    M.distanceSecret = true
    local ok = pcall(M.Tick, 0.25)
    H.check("secret distance: no error", ok, true)
    H.check("secret distance: UnitInRange", b:GetAlpha(), 1)
    M.distanceSecret = false
    M.SetCombat(false)
    -- A friendly target outside the group: a friendly item, out of combat.
    H.check("friend outside the group, 25 yd", target(ns, { friend = true, distance = 25, near = false }), 1)
    M.units.target.distance = 33
    M.Tick(0.25)
    H.check("friend at 33: the 30 yd item says out", ns.Frames.target:GetAlpha(), 0.5)
    -- In combat friendly items are not asked (restricted on retail).
    M.combat = true
    local asked = M.itemQueries
    M.units.target.near = true
    M.Tick(0.25)
    H.check("combat: no friendly item asked", M.itemQueries, asked)
    local interacts = M.interactQueries
    M.Tick(0.25)
    H.check("combat: no follow distance for a friend", M.interactQueries, interacts)
    H.check("combat: unknown, full", ns.Frames.target:GetAlpha(), 1)
    H.check("combat: nothing blocked", #M.blocked, 0)
    M.SetCombat(false)
end

-- Modes: yards over a class spell, spell without a fallback to yards.
do
    local ns = boot("PRIEST", { 585, 2050 })
    -- Automatic: Smite (30). 32 yards: out.
    H.check("auto: spell", target(ns, { hostile = true, distance = 32 }), 0.5)
    H.check("auto hint: spell", ns.Range.MethodHint("hostile"), ns.L.RANGE_USING_SPELL:format("Smite"))
    ns.Config.Set("general", "rangeHostileMode", "YARDS")
    ns.Config.Set("general", "rangeHostileYards", 35)
    M.Tick(0.25)
    H.check("yards: the 35 yd item", ns.Frames.target:GetAlpha(), 1)
    local asked = M.spellQueries
    M.Tick(0.25)
    H.check("yards: no spell asked", M.spellQueries, asked)
    -- Spell mode with an unknown spell: the standard range, not yards.
    ns.Config.Set("general", "rangeHostileMode", "SPELL")
    ns.Config.Set("general", "rangeHostileSpell", "Pyroblast")
    M.units.target.distance, M.units.target.near = 20, nil
    M.Tick(0.25)
    H.check("spell mode, unknown: follow distance", ns.Frames.target:GetAlpha(), 1)
    H.check("spell mode hint", ns.Range.MethodHint("hostile"), ns.L.RANGE_USING_STANDARD)
    local items = M.itemQueries
    M.Tick(0.25)
    H.check("spell mode: no item asked", M.itemQueries, items)
    -- Automatic with an unknown override: yards.
    ns.Config.Set("general", "rangeHostileMode", "AUTO")
    H.check("auto, unknown spell: yards", ns.Range.MethodHint("hostile"), ns.L.RANGE_USING_ITEM:format(35))
end

-- The options page: mode dropdown with the method as hint.
do
    local ns = boot("WARRIOR")
    ns.Options.Open("general", "status")
    local rows = {}
    for _, row in ipairs(ns.Options.rows or {}) do rows[row.key or ""] = row end
    H.checkTrue("mode row", rows.rangeHostileMode)
    H.checkTrue("yards row", rows.rangeHostileYards)
    if rows.rangeHostileMode then
        H.check("mode hint", rows.rangeHostileMode.hintText:GetText(), ns.L.RANGE_USING_ITEM:format(30))
        ns.Config.Set("general", "rangeHostileYards", 22)
        H.check("mode hint follows", rows.rangeHostileMode.hintText:GetText(), ns.L.RANGE_USING_ITEM:format(20))
    end
end

-- Off per reaction: those units never fade, on any frame.
do
    local ns = boot("PRIEST", { 585, 2050 })
    local C = ns.Config
    H.check("hostile far: faded", target(ns, { hostile = true, distance = 45 }), 0.5)
    C.Set("general", "rangeHostileMode", "OFF")
    M.Tick(0.25)
    H.check("hostile off: full", ns.Frames.target:GetAlpha(), 1)
    H.check("hint: off", ns.Range.MethodHint("hostile"), ns.L.RANGE_USING_OFF)
    local asked = M.spellQueries + M.itemQueries + M.interactQueries
    M.Tick(0.25)
    H.check("hostile off: nothing asked", M.spellQueries + M.itemQueries + M.interactQueries, asked)
    -- Friends still fade.
    H.check("friend far: faded", target(ns, { friend = true, distance = 45 }), 0.5)
    M.units.party1 = { name = "Ann", isPlayer = true, health = 5, healthMax = 10, friend = true, distance = 45,
        inRange = false }
    M.SetGroup({ "party1" })
    H.check("party far: faded", ns.Party.buttons[1]:GetAlpha(), 0.5)
    C.Set("general", "rangeFriendlyMode", "OFF")
    M.Tick(0.25)
    H.check("friendly off: party full", ns.Party.buttons[1]:GetAlpha(), 1)
    H.check("friendly off: target full", ns.Frames.target:GetAlpha(), 1)
    H.check("both off: timer stopped", ns.Range.driver:IsShown(), false)
    C.Set("general", "rangeHostileMode", "AUTO")
    H.check("one back: timer runs", ns.Range.driver:IsShown(), true)
    -- Stored as an index past the others: the encoding only grows.
    H.checkTrue("export keeps off", ns.Codec.Encode(C.Profile()):find("gVG4", 1, true))
end

-- Options: the spell field and yards slider grey out while their mode is Off.
do
    local ns = boot("WARRIOR")
    ns.Options.Open("general", "status")
    local rows = {}
    for _, row in ipairs(ns.Options.rows or {}) do rows[row.key or ""] = row end
    H.check("spell field enabled", rows.rangeHostileSpell.edit:IsEnabled(), true)
    ns.Config.Set("general", "rangeHostileMode", "OFF")
    H.check("spell field disabled", rows.rangeHostileSpell.edit:IsEnabled(), false)
    H.check("yards slider disabled", rows.rangeHostileYards.slider:IsEnabled(), false)
    H.check("friendly slider still enabled", rows.rangeFriendlyYards.slider:IsEnabled(), true)
    H.check("mode itself enabled", rows.rangeHostileMode.button:IsEnabled(), true)
    H.check("mode hint off", rows.rangeHostileMode.hintText:GetText(), ns.L.RANGE_USING_OFF)
    ns.Config.Set("general", "rangeHostileMode", "YARDS")
    H.check("enabled again", rows.rangeHostileYards.slider:IsEnabled(), true)
    -- Combat still locks every row.
    M.combat = true
    M.FireEvent("PLAYER_REGEN_DISABLED")
    H.check("combat: locked", rows.rangeHostileYards.slider:IsEnabled(), false)
    M.SetCombat(false)
    H.check("after combat: enabled", rows.rangeHostileYards.slider:IsEnabled(), true)
end
