-- Threat glow (Elements/Threat.lua): a coloured glow around the unit while
-- it has threat (player, party, pet) or while you have threat on it
-- (target, focus, target of target). Settings, colours, events, secrets,
-- the docked castbar, combat and test mode.
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

-- Whether the glow shows (either holder; the ring holders pick one), and
-- its colour.
local function glowing(frame)
    local t = frame.threat
    return t.frame:IsShown() and t.block:IsShown()
end
local function color(frame, ns)
    local piece = ns.Border.GlowPieces(frame.threat.frame)[1]
    return piece._color
end

-- Settings -----------------------------------------------------------------------
do
    local ns = H.LoadAddon()
    local S = ns.Settings
    local def = S.Get("threatGlow")
    H.checkTrue("setting", def)
    H.check("code", def and def.code, "TH")
    for _, scope in ipairs({ "player", "target", "targettarget", "pet", "focus", "party" }) do
        H.checkTrue("on " .. scope, S.AppliesTo(def, scope))
    end
    H.check("not general", S.AppliesTo(def, "general"), false)
    H.check("player: on", S.Default(def, "player"), true)
    H.check("party: on", S.Default(def, "party"), true)
    for _, scope in ipairs({ "target", "targettarget", "pet", "focus" }) do
        H.check(scope .. ": off", S.Default(def, scope), false)
    end
    local found
    for _, tab in ipairs(ns.Schema.Tabs("target")) do
        for _, sec in ipairs(tab.sections or {}) do
            if sec.id == "threat" then found = tab.id end
        end
    end
    H.check("threat section on the status tab", found, "status")
    H.check("section label", ns.L.SECTION_threat, "Threat")
    H.checkTrue("label", ns.L.SETTING_threatGlow ~= "SETTING_threatGlow")
end

-- Defaults add nothing to a saved profile.
do
    local ns = boot()
    local C = ns.Config
    C.Set("player", "threatGlow", true)
    C.Set("target", "threatGlow", false)
    H.check("nothing stored", next(C.Profile().player) == nil and next(C.Profile().target) == nil, true)
    C.Set("target", "threatGlow", true)
    H.checkTrue("a change is exported", ns.Codec.Encode(C.Profile()):find("tTH1"))
end

-- Build and placement ----------------------------------------------------------------
do
    local ns = boot()
    local f = ns.Frames.player
    local t = f.threat
    H.checkTrue("player has a glow", t)
    H.check("around the frame: in the frame's ring holder", t.frame:GetParent(), f.frameRing)
    H.check("around the unit box: in the block's ring holder", t.block:GetParent(), f.blockRing)
    local pieces = ns.Border.GlowPieces(t.frame)
    H.check("eight pieces", #pieces, 8)
    H.check("the shadow's soft band", pieces[1]._texture, ns.Border.SHADOW)
    -- The top edge starts outside the border.
    local p = { pieces[1]:GetPoint(1) }
    H.check("outside the ring", p[5], ns.Border.Extent("player"))
    H.check("glow width", pieces[1]:GetHeight(), ns.Threat.SIZE)
    H.check("idle: no glow", t.frame:IsShown(), false)
end

-- The unit's own threat: player, party ----------------------------------------------
do
    local ns = boot()
    local f = ns.Frames.player
    M.units.player.threat = 3
    M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
    H.check("aggro: glow", glowing(f), true)
    local c = color(f, ns)
    H.check("aggro colour from GetThreatStatusColor", c[1] .. "," .. c[2] .. "," .. c[3], "1,0,0")
    M.units.player.threat = 1
    M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
    c = color(f, ns)
    H.check("gaining threat colour", c[1] .. "," .. c[2] .. "," .. c[3], "1,1,0.47")
    M.units.player.threat = 0
    M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
    H.check("no threat: none", glowing(f), false)
    M.units.player.threat = nil
    M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
    H.check("not on a threat list: none", glowing(f), false)

    -- Secret: none, no error.
    M.units.player.threat = M.Secret(3)
    local ok, err = pcall(M.FireEvent, "UNIT_THREAT_SITUATION_UPDATE", "player")
    H.check("secret: no error", ok and "ok" or tostring(err), "ok")
    H.check("secret: none", glowing(f), false)
    M.units.player.threat = 3
    M.units.player.dead = true
    M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
    H.check("dead: none, as Blizzard's", glowing(f), false)
    M.units.player.dead = nil

    -- Party member, in combat: nothing protected touched.
    M.units.party1 = { name = "Ann", isPlayer = true, health = 5, healthMax = 10 }
    M.SetGroup({ "party1" })
    local b = ns.Party.buttons[1]
    M.combat = true
    M.units.party1.threat = 2
    ok = pcall(M.FireEvent, "UNIT_THREAT_LIST_UPDATE", "party1")
    H.check("combat: no error", ok, true)
    H.check("member: glow", glowing(b), true)
    H.check("combat: nothing blocked", #M.blocked, 0)
    M.SetCombat(false)

    -- Off: never.
    ns.Config.Set("party", "threatGlow", false)
    M.FireEvent("UNIT_THREAT_LIST_UPDATE", "party1")
    H.check("off: none", glowing(b), false)
end

-- Your threat on the target -----------------------------------------------------------
do
    local ns = boot()
    local f = ns.Frames.target
    ns.Config.Set("target", "threatGlow", true)
    M.units.target = { name = "Boar", health = 5, healthMax = 10, threat = 3, threatOf = { player = 2 } }
    M.FireEvent("PLAYER_TARGET_CHANGED")
    H.check("your threat on it", glowing(f), true)
    local c = color(f, ns)
    H.check("its colour", c[2], 0.6)
    -- The player's situation changes: the target frame follows.
    M.units.target.threatOf.player = 0
    M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
    H.check("threat gone", glowing(f), false)
    M.units.target.threatOf.player = 3
    M.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
    H.check("threat list of the target", glowing(f), true)
    -- Leaving combat clears it.
    M.units.target.threatOf.player = nil
    M.SetCombat(false)
    H.check("combat over: none", glowing(f), false)
end

-- Test mode: one pretend member glows.
do
    local ns = boot()
    H.checkTrue("test mode on", ns.TestMode.Set(true))
    local fakes = ns.Party.fakes
    H.check("member 4 glows", glowing(fakes[4]), true)
    local c = color(fakes[4], ns)
    H.check("member 4: aggro colour", c[1] .. "," .. c[2] .. "," .. c[3], "1,0,0")
    H.check("member 1 does not", glowing(fakes[1]), false)
    M.units.player.threat = 3
    M.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
    H.check("real threat does not reach the samples", glowing(fakes[1]), false)
    M.units.player.threat = nil
    ns.TestMode.Set(false)
    H.check("off: sample gone", glowing(fakes[4]), false)
end
