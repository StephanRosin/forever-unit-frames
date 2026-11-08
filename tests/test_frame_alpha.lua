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
            if sec.id == "opacity" then tab = t.id end
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
