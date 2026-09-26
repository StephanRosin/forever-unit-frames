-- Dead, ghost and offline units (Elements/UnitStatus.lua): grey bars, a
-- word instead of the health values, a grey portrait; events, secrets and
-- test mode.
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

-- What a text shows: its plain text, or its format.
local function shown(fs) return fs._fmt and not fs._text and fs._fmt or fs._text end

local function isGrey(bar, ns)
    local c, g = bar._color, ns.UnitStatus.GREY
    return c[1] == g[1] and c[2] == g[2] and c[3] == g[3]
end

do
    local ns = boot()
    local L = ns.L
    H.check("dead word", L.STATUS_DEAD, "Dead")
    H.check("ghost word", L.STATUS_GHOST, "Ghost")
    H.check("offline word", L.STATUS_OFFLINE, "Offline")

    local f = ns.Frames.target
    M.units.target = { name = "Ann", isPlayer = true, class = "WARRIOR", className = "WARRIOR", health = 5,
        healthMax = 10, powerMax = 10, power = 5 }
    M.FireEvent("PLAYER_TARGET_CHANGED")
    H.check("alive: values", shown(f.texts.healthLeft), "%s / %s")
    H.check("alive: percent", shown(f.texts.healthRight), "%.0f%%")
    H.check("alive: not grey", isGrey(f.health, ns), false)
    H.check("status of a living unit", ns.UnitStatus.Of(f), nil)

    -- Dead: the first value text says so, the other is empty, bars grey.
    M.units.target.dead = true
    M.units.target.health = 0
    M.FireEvent("UNIT_HEALTH", "target")
    H.check("dead: status", ns.UnitStatus.Of(f), "DEAD")
    H.check("dead: word instead of values", shown(f.texts.healthLeft), "Dead")
    H.check("dead: percent gone", shown(f.texts.healthRight), "")
    H.checkTrue("dead: health bar grey", isGrey(f.health, ns))
    H.checkTrue("dead: power bar grey", isGrey(f.power, ns))
    H.check("dead: the name stays", f.texts.title._fmt, "%s %s")

    -- A ghost.
    M.units.target.ghost = true
    M.units.target.dead = nil
    M.FireEvent("UNIT_HEALTH", "target")
    H.check("ghost: word", shown(f.texts.healthLeft), "Ghost")

    -- Alive again: values and colours come back.
    M.units.target.ghost = nil
    M.units.target.health = 10
    M.FireEvent("UNIT_HEALTH", "target")
    H.check("alive again: values", shown(f.texts.healthLeft), "%s / %s")
    H.check("alive again: percent", shown(f.texts.healthRight), "%.0f%%")
    H.check("alive again: colour", isGrey(f.health, ns), false)

    -- Offline: the word, a full grey bar (Blizzard's party frames).
    M.units.target.offline = true
    M.FireEvent("UNIT_CONNECTION", "target", false)
    H.check("offline: word", shown(f.texts.healthLeft), "Offline")
    H.checkTrue("offline: grey", isGrey(f.health, ns))
    H.check("offline: bar full", f.health:GetValue(), 1)
    H.check("offline: of one", select(2, f.health:GetMinMaxValues()), 1)
    H.checkTrue("offline: power grey", isGrey(f.power, ns))
    M.units.target.offline = nil
    M.FireEvent("UNIT_CONNECTION", "target", true)
    H.check("online: values", shown(f.texts.healthLeft), "%s / %s")
    H.check("online: health back", f.health:GetValue(), 10)

    -- NPCs are never offline.
    M.units.target = { name = "Boar", health = 5, healthMax = 10, offline = true }
    M.FireEvent("PLAYER_TARGET_CHANGED")
    H.check("an NPC is never offline", ns.UnitStatus.Of(f), nil)

    -- Secret answers: treated as alive and online, no error.
    M.units.target = { name = "Ann", isPlayer = true, health = 5, healthMax = 10, dead = M.Secret(true),
        offline = M.Secret(true) }
    local ok, err = pcall(M.FireEvent, "PLAYER_TARGET_CHANGED")
    H.check("secret: no error", ok and "ok" or tostring(err), "ok")
    H.check("secret: no status", ns.UnitStatus.Of(f), nil)
end

-- Frames without a value text: the word takes the empty right text.
do
    local ns = boot()
    local f = ns.Frames.targettarget
    M.units.targettarget = { name = "Bob", health = 0, healthMax = 10, dead = true }
    M.Tick(0.25)
    H.check("tot: name stays", f.texts.healthLeft._text, "Bob")
    H.check("tot: word on the right", shown(f.texts.healthRight), "Dead")
    M.units.targettarget.dead = nil
    M.units.targettarget.health = 10
    M.Tick(0.25)
    H.check("tot alive: right empty", shown(f.texts.healthRight), "")
end

-- A 2D portrait turns grey; party members; the player's own death events.
do
    local ns = boot()
    local C = ns.Config
    C.Set("party", "portraitMode", "LEFT")
    M.units.party1 = { name = "Ann", isPlayer = true, health = 5, healthMax = 10 }
    M.SetGroup({ "party1" })
    local b = ns.Party.buttons[1]
    H.check("alive: portrait in colour", b.portrait2D._desaturated, false)
    M.units.party1.offline = true
    M.FireEvent("UNIT_CONNECTION", "party1", false)
    H.check("member offline: word", shown(b.texts.healthRight), "Offline")
    H.check("member offline: grey portrait", b.portrait2D._desaturated, true)
    M.units.party1.offline = nil
    M.FireEvent("UNIT_CONNECTION", "party1", true)
    H.check("member back: portrait in colour", b.portrait2D._desaturated, false)

    local p = ns.Frames.player
    M.units.player.dead = true
    M.FireEvent("PLAYER_DEAD")
    H.check("player dead", shown(p.texts.healthLeft), "Dead")
    M.units.player.dead = nil
    M.units.player.ghost = true
    M.FireEvent("PLAYER_ALIVE")
    H.check("player released: ghost", shown(p.texts.healthLeft), "Ghost")
    M.units.player.ghost = nil
    M.FireEvent("PLAYER_UNGHOST")
    H.check("player alive", shown(p.texts.healthLeft), "%s / %s")

    -- In combat: nothing protected touched.
    M.combat = true
    M.units.party1.dead = true
    local ok = pcall(M.FireEvent, "UNIT_HEALTH", "party1")
    H.check("combat: no error", ok, true)
    H.check("combat: nothing blocked", #M.blocked, 0)
    H.check("combat: word", shown(b.texts.healthRight), "Dead")
    M.SetCombat(false)
end

-- Test mode: one pretend member dead, one offline.
do
    local ns = boot()
    H.checkTrue("test mode on", ns.TestMode.Set(true))
    local fakes = ns.Party.fakes
    H.check("member 1 alive", ns.UnitStatus.Of(fakes[1]), nil)
    H.check("member 2 dead", ns.UnitStatus.Of(fakes[2]), "DEAD")
    H.check("member 2: word", shown(fakes[2].texts.healthRight), "Dead")
    H.checkTrue("member 2: grey", isGrey(fakes[2].health, ns))
    H.check("member 3 offline", shown(fakes[3].texts.healthRight), "Offline")
    H.check("member 1: sample values", shown(fakes[1].texts.healthRight), "%.0f%%")
    -- The player really dead: samples still show their own states.
    M.units.player.dead = true
    M.FireEvent("UNIT_HEALTH", "player")
    H.check("real death does not reach the samples", ns.UnitStatus.Of(fakes[1]), nil)
    M.units.player.dead = nil
    ns.TestMode.Set(false)
    H.check("off: sample gone", ns.UnitStatus.Of(fakes[2]), nil)
end
