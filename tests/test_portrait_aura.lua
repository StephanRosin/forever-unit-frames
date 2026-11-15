-- Portrait aura (Elements/Portrait.lua): the unit's crowd control big on
-- its portrait, optionally its big defensives under it. The client picks
-- the aura: one container, a slot per kind, filters it evaluates itself.
local M = H.M

local function boot()
    local ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "WARRIOR", className = "WARRIOR", isPlayer = true, health = 1,
        healthMax = 1 }
    _G.ForeverUnitFramesDB = nil
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    return ns
end

local function container(frame) return frame.portraitAura and frame.portraitAura.container end

-- Settings -----------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local S = ns.Settings
    for key, code in pairs({ portraitAura = "QC", portraitAuraDefensive = "QK" }) do
        local def = S.Get(key)
        H.check(key .. ": code", def and def.code, code)
        for _, scope in ipairs({ "player", "target", "focus", "party" }) do
            H.checkTrue(key .. " on " .. scope, S.AppliesTo(def, scope))
            H.check(key .. " off by default on " .. scope, S.Default(def, scope), false)
        end
        for _, scope in ipairs({ "general", "targettarget", "pet", "boss" }) do
            H.check(key .. " not on " .. scope, S.AppliesTo(def, scope), false)
        end
        for code2, t in pairs(ns.Locales) do
            H.checkTrue(code2 .. ": " .. key .. " label", t["SETTING_" .. key] ~= nil)
            H.checkTrue(code2 .. ": " .. key .. " no sharp s", not tostring(t["SETTING_" .. key]):find("ß")
                and not tostring(t["HINT_" .. key]):find("ß"))
        end
    end
    local found
    for _, tab in ipairs(ns.Schema.Tabs("target")) do
        for _, sec in ipairs(tab.sections or {}) do
            for _, key in ipairs(sec.keys) do
                if key == "portraitAura" then found = tab.id .. ":" .. sec.id end
            end
        end
    end
    H.check("in Auras > Portrait aura", found, "auras:portraitAura")
end

-- Off by default: no container is made.
do
    local ns = boot()
    for _, key in ipairs({ "player", "target", "focus" }) do
        H.checkTrue(key .. ": ready", ns.Frames[key].portraitAura)
        H.check(key .. ": no container", container(ns.Frames[key]), nil)
    end
    H.check("none on the pet", ns.Frames.pet.portraitAura, nil)
end

-- On with a portrait: a slot of crowd control over the portrait.
do
    local ns = boot()
    local C, f = ns.Config, ns.Frames.target
    M.units.target = { name = "Foe", health = 5, healthMax = 10 }
    C.Set("target", "portraitAura", true)
    H.check("no portrait: no container", container(f), nil)
    C.Set("target", "portraitMode", "LEFT")
    local c = container(f)
    H.checkTrue("portrait: a container", c)
    H.check("Blizzard's container", c._template, "CustomAuraContainerTemplate")
    H.check("no made-up auras in Edit Mode", c:IsEditModePreviewEnabled(), false)
    M.FireEvent("PLAYER_TARGET_CHANGED")
    H.check("for the target", c:GetUnit(), "target")
    local slot = c._slots.cc
    H.checkTrue("a slot: one aura", slot)
    H.check("crowd control", slot.filter, "HARMFUL|CROWD_CONTROL")
    H.check("slot on", slot.enabled, true)
    H.check("no defensive slot yet", c._slots.defensive, nil)
    local button = slot.frame
    local side = f.portraitBg:GetHeight()
    H.check("as wide as the portrait", button:GetWidth(), side)
    H.check("as tall as the portrait", button:GetHeight(), side)
    local p = { button:GetPoint(1) }
    H.check("centred", p[1], "CENTER")
    H.check("on the portrait", p[2], f.portraitBg)
    H.check("with the time left", button.cooldown._hideNumbers, false)
    H.checkTrue("above the aura icons", button:GetFrameLevel() > f:GetFrameLevel() + ns.Auras.LEVELS)

    -- TOP: a square as tall as the strip, on its middle.
    C.Set("target", "portraitMode", "TOP")
    H.check("strip: as tall as the strip", button:GetHeight(), f.portraitBg:GetHeight())
    H.check("strip: square", button:GetWidth(), button:GetHeight())

    -- Big defensives: a second slot under the crowd control.
    C.Set("target", "portraitAuraDefensive", true)
    local def = c._slots.defensive
    H.checkTrue("defensive slot", def)
    H.check("big defensives", def.filter, "HELPFUL|BIG_DEFENSIVE")
    H.checkTrue("crowd control on top", slot.frame:GetFrameLevel() > def.frame:GetFrameLevel())
    H.check("same place", def.frame:GetPoint(1), "CENTER")
    C.Set("target", "portraitAuraDefensive", false)
    H.check("defensive off", def.enabled, false)

    -- Portrait off: the slots are off.
    C.Set("target", "portraitMode", "OFF")
    H.check("no portrait: crowd control off", slot.enabled, false)
    C.Set("target", "portraitMode", "LEFT")
    H.check("portrait again: on", slot.enabled, true)
    C.Set("target", "portraitAura", false)
    H.check("switched off", slot.enabled, false)
end

-- Switched on in combat: made after combat; party slots follow their unit.
do
    local ns = boot()
    local C = ns.Config
    C.Set("party", "portraitMode", "LEFT")
    M.combat = true
    local ok, err = pcall(C.Set, "party", "portraitAura", true)
    H.check("in combat: no error", ok and "ok" or tostring(err), "ok")
    local b = ns.Party.buttons[1]
    H.check("in combat: not yet", container(b), nil)
    M.SetCombat(false)
    H.checkTrue("after combat: made", container(b))
    M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
    M.SetGroup({ "party1" })
    H.check("party member's unit", container(b):GetUnit(), "party1")
    local updates = container(b)._updates
    M.FireEvent("GROUP_ROSTER_UPDATE")
    H.checkTrue("roster change: looked again", container(b)._updates > updates)
end

-- Test mode: a sample on the portrait, the live icon hidden.
do
    local ns = boot()
    local C, f = ns.Config, ns.Frames.player
    C.Set("player", "portraitMode", "LEFT")
    C.Set("player", "portraitAura", true)
    H.checkTrue("test mode on", ns.TestMode.Set(true))
    local sample = f.portraitAura.sample
    H.checkTrue("sample shown", sample and sample:IsShown())
    H.check("sample as wide as the portrait", sample:GetWidth(), f.portraitBg:GetWidth())
    H.check("live container hidden", container(f):IsShown(), false)
    C.Set("player", "portraitMode", "OFF")
    H.check("no portrait: no sample", sample:IsShown(), false)
    C.Set("player", "portraitMode", "LEFT")
    ns.TestMode.Set(false)
    H.check("test mode off: sample gone", sample:IsShown(), false)
    H.check("live container back", container(f):IsShown(), true)
end
