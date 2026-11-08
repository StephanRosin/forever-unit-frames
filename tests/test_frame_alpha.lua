-- The frames' own opacity (frameAlpha): General for every frame,
-- overridable per frame; range and out-of-combat fading are a share of it,
-- the 3D portrait follows.
local M = H.M

local function near(label, got, want) H.checkTrue(label .. " (" .. tostring(got) .. ")", math.abs(got - want) < 1e-6) end

local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "WARRIOR", className = "WARRIOR", isPlayer = true, health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C = ns.Settings, ns.Config

local def = S.Get("frameAlpha")
H.check("code", def.code, "OA")
H.check("inherited", def.scope, "inherit")
H.check("full by default", S.Default(def, "party"), 100)
H.check("never invisible", def.min, 10)
H.checkTrue("label", ns.L.SETTING_frameAlpha ~= "SETTING_frameAlpha")
for _, scope in ipairs({ "general", "player" }) do
    local tab
    for _, t in ipairs(scope == "general" and ns.Schema.GENERAL or ns.Schema.Tabs(scope)) do
        for _, sec in ipairs(t.sections or {}) do
            if sec.id == "visibility" then tab = t.id end
        end
    end
    H.check(scope .. ": opacity section", tab, scope == "general" and "appearance" or "layout")
end

C.Set("general", "frameAlpha", 80)
M.RunTimers()
local player = ns.Frames.player
near("player at 80%", player:GetAlpha(), 0.8)
near("its 3D portrait too", player.portrait3D:GetAlpha(), 0.8)

-- Range fading: a share of it.
M.units.party1 = { name = "Ann", isPlayer = true, health = 5, healthMax = 10 }
M.SetGroup({ "party1" })
local b = ns.Party.buttons[1]
near("party in range: 80%", b:GetAlpha(), 0.8)
M.units.party1.inRange = false
M.Tick(0.25)
near("out of range: half of it", b:GetAlpha(), 0.4)
M.units.party1.inRange = true
M.Tick(0.25)
near("back in range", b:GetAlpha(), 0.8)

-- A frame overrides General.
C.Set("party", "frameAlpha", 60)
M.RunTimers()
M.Tick(0.25)
near("party override", b:GetAlpha(), 0.6)
near("player keeps General", player:GetAlpha(), 0.8)

-- Range fading off: the frame's own opacity, not full.
C.Set("party", "rangeFade", false)
M.RunTimers()
M.units.party1.inRange = false
M.Tick(0.25)
near("fading off: still 60%", b:GetAlpha(), 0.6)

-- Out of combat: a share of it, back to it in combat.
M.SetGroup({})
C.Set("player", "playerFadeOOC", true)
C.Set("player", "playerFadeAlpha", 50)
M.RunTimers()
near("idle: half of 80%", player:GetAlpha(), 0.4)
near("idle: portrait too", player.portrait3D:GetAlpha(), 0.4)
M.SetCombat(true)
M.FireEvent("PLAYER_REGEN_DISABLED")
near("combat: 80%", player:GetAlpha(), 0.8)
M.SetCombat(false)
M.FireEvent("PLAYER_REGEN_ENABLED")
M.units.player.health, M.units.player.healthMax = 1, 2
M.FireEvent("UNIT_HEALTH", "player")
near("hurt: 80%, not full", player:GetAlpha(), 0.8)

-- Raid cells: the raid profile's own opacity, range fading a share of it.
do
    local ns = H.LoadAddon()
    local RC, Header = ns.RaidConfig, ns.RaidHeader
    M.units.player = { name = "Me", class = "WARRIOR", className = "Warrior", isPlayer = true, level = 60,
        health = 100, healthMax = 100 }
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    M.RunTimers()
    local rdef = ns.RaidSettings.Get("frameAlpha")
    H.check("raid: one for every size", rdef.scope, "general")
    H.check("raid: full by default", ns.RaidSettings.Default(rdef, "general"), 100)
    H.checkTrue("raid: label", ns.L.RAID_SETTING_frameAlpha ~= nil)
    local tab
    for _, t in ipairs(ns.RaidSchema and ns.RaidSchema.TABS or {}) do
        for _, sec in ipairs(t.sections or {}) do
            for _, k in ipairs(sec.keys or {}) do if k == "frameAlpha" then tab = t.id .. "/" .. sec.id end end
        end
    end
    H.check("raid: on the General tab", tab, "general/appearance")
    M.SetRaidRoster({ { name = "Ann", class = "PRIEST", subgroup = 1 },
        { name = "Bob", class = "MAGE", subgroup = 1, unit = { inRange = false } } })
    M.RunTimers()
    local function cell(i) return Header.headers[1]:GetAttribute("child" .. i) end
    M.Tick(0.25)
    near("raid: full", cell(1):GetAlpha(), 1)
    RC.Set("general", "frameAlpha", 80)
    M.RunTimers()
    M.Tick(0.25)
    near("raid: 80%", cell(1):GetAlpha(), 0.8)
    near("raid: out of range a share of it", cell(2):GetAlpha(), 0.32)
    near("unit frames untouched", ns.Frames.player:GetAlpha(), 1)
    RC.Set("r10", "rangeFade", false)
    M.RunTimers()
    M.Tick(0.25)
    near("raid fading off: still 80%", cell(2):GetAlpha(), 0.8)
end
