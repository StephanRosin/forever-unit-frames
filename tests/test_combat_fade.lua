-- Player frame out of combat: optionally faded while nothing is going on
-- (no combat, no target, full health and power, no cast).
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C = ns.Settings, ns.Config

H.check("code", S.Get("playerFadeOOC").code, "WF")
H.check("opacity code", S.Get("playerFadeAlpha").code, "WA")
H.check("player only", S.AppliesTo(S.Get("playerFadeOOC"), "target"), false)
C.Use({})
H.check("off by default", C.Get("player", "playerFadeOOC"), false)

local f = ns.Frames.player
M.units.player = { name = "Me", health = 100, healthMax = 100, power = 50, powerMax = 50, powerType = 0 }
M.FireEvent("UNIT_HEALTH", "player")
H.check("off: full", f:GetAlpha(), 1)

C.Set("player", "playerFadeOOC", true)
C.Set("player", "playerFadeAlpha", 20)
H.check("idle: faded", f:GetAlpha(), 0.2)
H.check("idle: 3D portrait faded too", f.portrait3D:GetAlpha(), 0.2)

M.SetCombat(true)
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: full", f:GetAlpha(), 1)
H.check("combat: portrait full", f.portrait3D:GetAlpha(), 1)
M.SetCombat(false)
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("after combat: faded", f:GetAlpha(), 0.2)

-- A target does not matter.
M.units.target = { name = "Foe", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
M.FireEvent("UNIT_HEALTH", "player")
H.check("target: still faded", f:GetAlpha(), 0.2)
M.units.target = nil

M.units.player.health = 60
M.FireEvent("UNIT_HEALTH", "player")
H.check("hurt: full", f:GetAlpha(), 1)
M.units.player.health = 100
M.FireEvent("UNIT_HEALTH", "player")
-- Power is not looked at.
M.units.player.power = 10
M.FireEvent("UNIT_POWER_UPDATE", "player")
H.check("mana missing: still faded", f:GetAlpha(), 0.2)

-- Secret health (as the client gives it to addons): the curve still
-- decides, and the frame takes the secret opacity.
M.units.player.health = M.Secret(100)
M.FireEvent("UNIT_HEALTH", "player")
H.check("secret full health: faded", f:GetAlpha(), 0.2)
H.checkTrue("opacity is the secret", f._alphaSecret)
M.units.player.health = M.Secret(70)
M.FireEvent("UNIT_HEALTH", "player")
H.check("secret hurt: full", f:GetAlpha(), 1)
M.units.player.health = 100
M.FireEvent("UNIT_HEALTH", "player")

-- Test mode and unlocked frames: always full, to set things up.
ns.TestMode.Set(true)
H.check("test mode: full", f:GetAlpha(), 1)
ns.TestMode.Set(false)
H.check("test mode off: faded", f:GetAlpha(), 0.2)

C.Set("player", "playerFadeOOC", false)
H.check("off again: full", f:GetAlpha(), 1)

-- /fuf status says what keeps it from fading.
H.check("reason: off", ns.CombatFade.Blocker(), "OFF")
C.Set("player", "playerFadeOOC", true)
H.check("reason: none", ns.CombatFade.Blocker(), nil)
M.SetCombat(true)
H.check("reason: combat", ns.CombatFade.Blocker(), "COMBAT")
M.SetCombat(false)
