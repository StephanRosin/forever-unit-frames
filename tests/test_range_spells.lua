-- Spell-based range fading (Elements/Range.lua): a friendly and a hostile
-- spell per class, user overrides by name or ID, and the fallbacks to
-- UnitInRange and the follow distance.
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

-- Settings ------------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local S = ns.Settings
    for key, code in pairs({ rangeFriendlySpell = "VF", rangeHostileSpell = "VH" }) do
        local def = S.Get(key)
        H.checkTrue("setting " .. key, def)
        H.check(key .. " code", def and def.code, code)
        H.check(key .. " is text", def and def.type, "text")
        H.check(key .. " empty by default", def and S.Default(def, "general"), "")
        H.check(key .. " on general", S.AppliesTo(def, "general"), true)
        for _, scope in ipairs({ "player", "target", "focus", "party", "pet" }) do
            H.check(key .. " not on " .. scope, S.AppliesTo(def, scope), false)
        end
        H.checkTrue(key .. " label", ns.L["SETTING_" .. key] ~= "SETTING_" .. key)
    end
    local def = S.Get("rangeHostileSpell")
    H.check("text trimmed", S.Validate(def, "  Smite \t"), "Smite")
    H.check("empty allowed", S.Validate(def, "   "), "")
    H.check("not a string", S.Validate(def, 585), nil)
    H.check("too long", S.Validate(def, string.rep("x", 200)), nil)
    -- Round trip through the export string, awkward characters included.
    local profile = { general = { rangeHostileSpell = "a;b%c", rangeFriendlySpell = "2050" } }
    for _, scope in ipairs(S.SCOPES) do profile[scope] = profile[scope] or {} end
    local text = ns.Codec.Encode(profile)
    local back, _, rejected = ns.Codec.Decode(text)
    H.check("codec: hostile", back.general.rangeHostileSpell, "a;b%c")
    H.check("codec: friendly", back.general.rangeFriendlySpell, "2050")
    H.check("codec: nothing rejected", rejected, 0)
    local _, _, bad = ns.Codec.Decode("1;gVH'" .. string.rep("x", 100))
    H.check("codec: too long is rejected", bad, 1)
    -- Options: General > Status > Range holds both fields.
    local found = {}
    for _, tab in ipairs(ns.Schema.Tabs("general")) do
        for _, sec in ipairs(tab.sections or {}) do
            for _, key in ipairs(sec.keys) do
                if key:match("^range") then found[key] = tab.id .. "/" .. sec.id end
            end
        end
    end
    H.check("friendly field under range", found.rangeFriendlySpell, "status/range")
    H.check("hostile field under range", found.rangeHostileSpell, "status/range")
end

-- The class table -----------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local T = ns.Range.CLASS_SPELLS
    for _, class in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK",
        "DRUID" }) do
        H.checkTrue("class listed " .. class, T[class])
        for _, reaction in ipairs({ "friendly", "hostile" }) do
            for _, family in ipairs(T[class] and T[class][reaction] or {}) do
                H.checkTrue(class .. " " .. reaction .. " has ranks", #family > 0)
                for _, id in ipairs(family) do
                    H.check(class .. " spell id is a number", type(id), "number")
                end
            end
        end
    end
    H.check("warrior: no hostile default", #T.WARRIOR.hostile, 0)
    H.check("rogue: no friendly default", #T.ROGUE.friendly, 0)
    H.check("priest hostile starts with Smite", T.PRIEST.hostile[1][1], 585)
    H.check("hunter Mend Pet is for the pet only", T.HUNTER.friendly[1].petOnly, true)
end

-- Defaults: fading on the target and focus when the class has a hostile
-- spell, off otherwise.
do
    for class, want in pairs({ PRIEST = true, MAGE = true, HUNTER = true, WARRIOR = false, ROGUE = false,
        PALADIN = false }) do
        local ns = boot(class)
        H.check(class .. ": target default", ns.Config.Get("target", "rangeFade"), want)
        H.check(class .. ": focus default", ns.Config.Get("focus", "rangeFade"), want)
        H.check(class .. ": party still on", ns.Config.Get("party", "rangeFade"), true)
        -- The default is not written into the profile.
        ns.Config.Set("target", "rangeFade", want)
        H.check(class .. ": nothing stored", ns.Config.Profile().target.rangeFade, nil)
    end
    -- An explicit choice wins.
    local ns = boot("PRIEST")
    ns.Config.Set("target", "rangeFade", false)
    H.check("switched off stays off", ns.Config.Get("target", "rangeFade"), false)
end

-- Priest: Smite for enemies (30 yards), Lesser Heal for friends (40).
do
    local ns = boot("PRIEST", { 585, 2050 })
    -- 29 yards: beyond the follow distance, inside Smite's range.
    H.check("smite range: in", target(ns, { hostile = true, distance = 29 }), 1)
    M.units.target.distance = 31
    M.Tick(0.25)
    H.check("smite range: out", ns.Frames.target:GetAlpha(), 0.5)
    -- A friendly spell never measures an enemy and vice versa.
    H.check("hint: hostile in use", ns.Range.SpellHint("hostile"):find("Smite", 1, true) ~= nil, true)
    H.check("friend at 35: heal range", target(ns, { friend = true, distance = 35, near = false }), 1)
    M.units.target.distance = 45
    M.Tick(0.25)
    H.check("friend at 45: faded", ns.Frames.target:GetAlpha(), 0.5)
    -- Neither friend nor foe: the follow distance.
    H.check("neutral: follow distance", target(ns, { distance = 29 }), 0.5)
    -- No answer from the spell (no distance known): the follow distance.
    H.check("nil: fallback near", target(ns, { hostile = true, near = true }), 1)
    H.check("nil: fallback far", target(ns, { hostile = true, near = false }), 0.5)
    -- Neither answers: full opacity.
    H.check("nothing known: full", target(ns, { hostile = true, near = "nil" }), 1)
end

-- Ranks: the highest known rank is asked; a rank the list does not know is
-- found by its name.
do
    local ns = boot("PRIEST", { 585, 591, 598 })
    H.check("highest rank", ns.Range.Spells("hostile")[1].id, 598)
    ns = boot("PRIEST", { 591 })
    H.check("a middle rank alone", ns.Range.Spells("hostile")[1].id, 591)
    ns = boot("PRIEST")
    M.spells[99585] = { name = "Smite", maxRange = 30, harmful = true }
    M.known[99585] = true
    ns.Range.Invalidate()
    local first = ns.Range.Spells("hostile")[1]
    H.check("unlisted rank found by name", first and first.id, 99585)
end

-- Not known: the previous method. Learning it later switches over.
do
    local ns = boot("PRIEST")
    H.check("unknown spell: none", #ns.Range.Spells("hostile"), 0)
    H.check("unknown: follow distance", target(ns, { hostile = true, distance = 29 }), 0.5)
    M.known[585] = true
    M.FireEvent("SPELLS_CHANGED")
    M.Tick(0.25)
    H.check("learned: smite", ns.Frames.target:GetAlpha(), 1)
end

-- Party: the friendly spell first, UnitInRange when it gives no answer.
do
    local ns = boot("PRIEST", { 2050 })
    M.units.party1 = { name = "Ann", isPlayer = true, health = 5, healthMax = 10, friend = true, distance = 45,
        inRange = true }
    M.SetGroup({ "party1" })
    local b = ns.Party.buttons[1]
    H.check("party: spell over UnitInRange", b:GetAlpha(), 0.5)
    M.units.party1.distance = 30
    M.Tick(0.25)
    H.check("party: in heal range", b:GetAlpha(), 1)
    -- No distance: IsSpellInRange says nil, UnitInRange decides.
    M.units.party1.distance = nil
    M.units.party1.inRange = false
    M.Tick(0.25)
    H.check("party: nil falls back to UnitInRange", b:GetAlpha(), 0.5)
    -- Refused in combat: UnitInRange (secret) goes on working.
    M.units.party1.distance = 30
    M.spellRangeError = true
    M.rangeSecret = "inRange"
    M.combat = true
    local ok = pcall(M.Tick, 0.25)
    H.check("refused: no error", ok, true)
    H.check("refused: UnitInRange", b:GetAlpha(), 0.5)
    H.check("refused: secret path", b._alphaSecret, true)
    H.check("combat: nothing blocked", #M.blocked, 0)
    M.spellRangeError = false
    M.rangeSecret = false
    M.SetCombat(false)
end

-- Classes without a friendly spell keep UnitInRange and never ask a spell.
do
    local ns = boot("WARRIOR", { 78 })
    M.units.party1 = { name = "Ann", isPlayer = true, health = 5, healthMax = 10, friend = true, distance = 45 }
    M.SetGroup({ "party1" })
    local asked = M.spellQueries
    M.Tick(0.25)
    H.check("warrior party: UnitInRange", ns.Party.buttons[1]:GetAlpha(), 0.5)
    H.check("warrior: no spell asked", M.spellQueries, asked)
    H.check("warrior hint", ns.Range.SpellHint("hostile"), ns.L.RANGE_SPELL_NO_AUTO)
end

-- A secret answer counts as none.
do
    local ns = boot("PRIEST", { 585 })
    M.spellRangeSecret = true
    H.check("secret spell answer: fallback", target(ns, { hostile = true, distance = 29 }), 0.5)
    M.spellRangeSecret = false
end

-- Blocked by the client: never asked again this session.
do
    local ns = boot("PRIEST", { 585 })
    target(ns, { hostile = true, distance = 29 })
    M.FireEvent("ADDON_ACTION_BLOCKED", "ForeverUnitFrames", "C_Spell.IsSpellInRange()")
    local asked = M.spellQueries
    M.Tick(0.25)
    H.check("blocked: not asked again", M.spellQueries, asked)
    H.check("blocked: follow distance", ns.Frames.target:GetAlpha(), 0.5)
end

-- Overrides by name and by ID; an unknown one falls back, not to the class.
do
    local ns = boot("MAGE", { 133, 116, 1459 })
    -- 31 yards: Fireball (35) reaches, Frostbolt (30) and the follow
    -- distance do not.
    H.check("mage default: fireball", target(ns, { hostile = true, distance = 31 }), 1)
    ns.Config.Set("general", "rangeHostileSpell", "Frostbolt")
    M.Tick(0.25)
    H.check("override by name", ns.Frames.target:GetAlpha(), 0.5)
    H.check("override hint", ns.Range.SpellHint("hostile"), ns.L.RANGE_SPELL_IN_USE:format("Frostbolt"))
    ns.Config.Set("general", "rangeHostileSpell", "133")
    M.Tick(0.25)
    H.check("override by id", ns.Frames.target:GetAlpha(), 1)
    ns.Config.Set("general", "rangeHostileSpell", "Pyroblast")
    M.Tick(0.25)
    H.check("unknown override: follow distance", ns.Frames.target:GetAlpha(), 0.5)
    H.check("unknown override hint", ns.Range.SpellHint("hostile"), ns.L.RANGE_SPELL_UNKNOWN)
    M.units.target.distance = 20
    M.Tick(0.25)
    H.check("unknown override: near", ns.Frames.target:GetAlpha(), 1)
    ns.Config.Set("general", "rangeHostileSpell", "")
    H.check("empty: automatic again", ns.Range.SpellHint("hostile"),
        ns.L.RANGE_SPELL_AUTO:format("Fireball, Frostbolt"))
    -- A friendly override for a class with its own friendly spell.
    ns.Config.Set("general", "rangeFriendlySpell", "Shoot")
    H.check("harmful spell as friendly: no answer", target(ns, { friend = true, distance = 45, near = true }), 1)
end
do
    local ns = boot("WARRIOR", { 2061 })
    ns.Config.Set("general", "rangeFriendlySpell", "2061")
    M.units.party1 = { name = "Ann", isPlayer = true, health = 5, healthMax = 10, friend = true, distance = 45,
        inRange = true }
    M.SetGroup({ "party1" })
    H.check("friendly override on a warrior", ns.Party.buttons[1]:GetAlpha(), 0.5)
end

-- Hunter: Auto Shot's minimum range is covered by the follow distance;
-- Mend Pet only measures the pet.
do
    local ns = boot("HUNTER", { 75, 136 })
    H.check("dead zone: near", target(ns, { hostile = true, distance = 5 }), 1)
    M.units.target.distance = 33
    M.Tick(0.25)
    H.check("auto shot range", ns.Frames.target:GetAlpha(), 1)
    M.units.target.distance = 37
    M.Tick(0.25)
    H.check("beyond auto shot", ns.Frames.target:GetAlpha(), 0.5)
    M.units.target.distance, M.units.target.near = 5, "nil"
    M.Tick(0.25)
    H.check("dead zone, no follow distance: full", ns.Frames.target:GetAlpha(), 1)
    M.units.pet = { name = "Wolf", health = 5, healthMax = 10, inParty = true, inRange = true, friend = true,
        distance = 25 }
    M.FireEvent("UNIT_PET", "player")
    H.check("mend pet range", ns.Frames.pet:GetAlpha(), 0.5)
    M.units.party1 = { name = "Ann", isPlayer = true, health = 5, healthMax = 10, friend = true, distance = 25,
        inRange = true }
    M.SetGroup({ "party1" })
    H.check("party: not by mend pet", ns.Party.buttons[1]:GetAlpha(), 1)
end

-- Without C_SpellBook: the old IsPlayerSpell global.
do
    local ns = boot("PRIEST", { 585 })
    _G.C_SpellBook = nil
    ns.Range.Invalidate()
    H.check("IsPlayerSpell fallback", ns.Range.Spells("hostile")[1] and ns.Range.Spells("hostile")[1].id, 585)
    _G.IsPlayerSpell = nil
    ns.Range.Invalidate()
    H.check("IsSpellKnown fallback", ns.Range.Spells("hostile")[1] and ns.Range.Spells("hostile")[1].id, 585)
    _G.IsSpellKnown = nil
    ns.Range.Invalidate()
    H.check("no spell book API: none", #ns.Range.Spells("hostile"), 0)
end

-- The poll stays off while nothing fades.
do
    local ns = boot("PRIEST", { 585, 2050 })
    for _, scope in ipairs({ "party", "pet", "target", "focus" }) do ns.Config.Set(scope, "rangeFade", false) end
    H.check("all off: timer stopped", ns.Range.driver:IsShown(), false)
    target(ns, { hostile = true, distance = 29 })
    local asked = M.spellQueries
    M.Tick(0.25)
    H.check("all off: no spell asked", M.spellQueries, asked)
end

-- The options page: text rows with the automatic spell as hint.
do
    local ns = boot("PRIEST", { 585, 2050 })
    local rows = {}
    ns.Options.Open("general", "status")
    for _, row in ipairs(ns.Options.rows or {}) do rows[row.key or ""] = row end
    local row = rows.rangeHostileSpell
    H.checkTrue("hostile row", row)
    if row then
        H.check("hint shows the automatic spell", row.hintText:GetText(), ns.L.RANGE_SPELL_AUTO:format("Smite"))
        row.edit:SetText(" Shoot ")
        row.edit:GetScript("OnEnterPressed")(row.edit)
        H.check("typed name stored", ns.Config.Get("general", "rangeHostileSpell"), "Shoot")
        H.check("hint follows", row.hintText:GetText(), ns.L.RANGE_SPELL_UNKNOWN)
    end
end
