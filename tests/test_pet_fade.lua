-- The pet frame fades with the player frame out of combat (playerFadePet,
-- decision 63): the same opacity, the same (secret or plain) value handed
-- to SetAlpha. Off by default. While the player frame is in full (combat,
-- a target, test mode, unlocked frames, fading off) the pet frame's own
-- range fading has it again.
local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config

local def = S.Get("playerFadePet")
H.checkTrue("setting", def)
H.check("code", def and def.code, "WP")
H.check("a switch", def and def.type, "bool")
H.check("player only", def and S.AppliesTo(def, "pet"), false)
H.checkTrue("on the player", def and S.AppliesTo(def, "player"))
H.check("off by default", def and S.Default(def, "player"), false)
H.check("label", ns.L.SETTING_playerFadePet, "Pet frame fades too")
local keys
for _, tab in ipairs(ns.Schema.Tabs("player")) do
    for _, sec in ipairs(tab.sections or {}) do
        if sec.id == "outOfCombat" then keys = table.concat(sec.keys, ",") end
    end
end
H.check("in the player's fade section", keys, "playerFadeOOC,playerFadeAlpha,playerFadeTarget,playerFadePet")

M.units.player = { name = "Me", health = 100, healthMax = 100, power = 50, powerMax = 50, powerType = 0 }
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local f, pet = ns.Frames.player, ns.Frames.pet
M.units.pet = { name = "Wolf", health = 10, healthMax = 10 }
M.FireEvent("UNIT_PET", "player")
C.Set("player", "playerFadeOOC", true)
C.Set("player", "playerFadeAlpha", 20)
H.check("player faded", f:GetAlpha(), 0.2)
H.check("off: the pet in full", pet:GetAlpha(), 1)

C.Set("player", "playerFadePet", true)
H.check("on: the pet faded with it", pet:GetAlpha(), 0.2)
-- The range poll leaves it alone while it follows.
M.Tick(0.5)
H.check("poll: still faded", pet:GetAlpha(), 0.2)

-- Secret health: the same secret value.
M.units.player.health = M.Secret(100)
M.FireEvent("UNIT_HEALTH", "player")
H.check("secret: faded", pet:GetAlpha(), 0.2)
H.checkTrue("secret: the opacity is the secret", pet._alphaSecret)
M.units.player.health = M.Secret(50)
M.FireEvent("UNIT_HEALTH", "player")
H.check("secret hurt: in full", pet:GetAlpha(), 1)
M.units.player.health = 100
M.FireEvent("UNIT_HEALTH", "player")
H.check("back to faded", pet:GetAlpha(), 0.2)

-- Combat: the player in full, the pet's range fading back in charge.
M.units.pet.near = false
M.SetCombat(true)
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: player full", f:GetAlpha(), 1)
-- (A friendly unit is not measured in combat: unknown, in full.)
H.check("combat: pet as its range says", pet:GetAlpha(), 1)
M.SetCombat(false)
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("after combat: faded again", pet:GetAlpha(), 0.2)
-- A target: the player frame in full, the pet's range fading again
-- (out of range out of combat: faded by range).
M.units.target = { name = "Foe", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("target: player full", f:GetAlpha(), 1)
H.check("target: the pet's range fading", pet:GetAlpha(), 0.5)
M.units.target = nil
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("no target: faded with the player", pet:GetAlpha(), 0.2)
M.units.pet.near = nil

-- Test mode and unlocked frames: in full.
ns.TestMode.Set(true)
H.check("test mode: pet full", pet:GetAlpha(), 1)
ns.TestMode.Set(false)
H.check("test mode off: faded", pet:GetAlpha(), 0.2)
ns.Movers.Unlock()
H.check("unlocked: pet full", pet:GetAlpha(), 1)
ns.Movers.Lock()
H.check("locked: faded", pet:GetAlpha(), 0.2)

-- A pet that comes later takes the faded opacity at once.
M.units.pet = nil
M.FireEvent("UNIT_PET", "player")
pet:SetAlpha(1)
M.units.pet = { name = "Imp", health = 10, healthMax = 10 }
M.FireEvent("UNIT_PET", "player")
H.check("new pet: faded", pet:GetAlpha(), 0.2)

-- Switched off: the pet back in full.
C.Set("player", "playerFadePet", false)
H.check("off again: pet full", pet:GetAlpha(), 1)
H.check("off again: player still faded", f:GetAlpha(), 0.2)
C.Set("player", "playerFadePet", true)
C.Set("player", "playerFadeOOC", false)
H.check("fading off: pet full", pet:GetAlpha(), 1)
