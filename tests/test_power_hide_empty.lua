-- "Hide without power" (powerHideEmpty): an NPC without mana, rage or energy
-- shows no empty power bar; the health bar takes its row.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
local C, S = ns.Config, ns.Settings
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10, power = 50, powerMax = 100 }
M.units.target = { name = "Boar", level = 12, health = 5, healthMax = 10 }
ns.Single.CreateAll()
local t = ns.Frames.target

local function bottom(f) return f.titleHeight + f.health:GetHeight() end

-- The setting.
local def = S.Get("powerHideEmpty")
H.checkTrue("setting", def)
H.check("code", def.code, "PN")
H.check("off by default", S.Default(def, "target"), false)
H.check("off by default: empty bar shown", t.power:IsShown(), true)
C.Set("target", "powerHideEmpty", true)
for _, key in ipairs({ "target", "targettarget", "focus" }) do
    H.checkTrue(key .. " has it", S.AppliesTo(def, key))
end
for _, key in ipairs({ "player", "pet", "party" }) do
    H.check(key .. " has it not", S.AppliesTo(def, key), false)
end
H.checkTrue("label", ns.L.SETTING_powerHideEmpty ~= "SETTING_powerHideEmpty")
H.checkTrue("hint", ns.L.HINT_powerHideEmpty ~= "HINT_powerHideEmpty")

-- Switched on, a unit without power: no bar, health down to the frame's bottom.
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("no power: bar hidden", t.power:IsShown(), false)
H.check("no power: health fills the frame", bottom(t), t.layoutHeight)

-- A unit with power: the bar is back, health gives up its row.
M.units.target = { name = "Mage", level = 12, health = 5, healthMax = 10, power = 50, powerMax = 100 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("power: bar shown", t.power:IsShown(), true)
H.checkTrue("power: health shorter", bottom(t) < t.layoutHeight)
H.check("power: rows fill the frame", bottom(t) + t.power:GetHeight(), t.layoutHeight)

-- Forever hands out an enemy NPC's power as secrets. An NPC with rage
-- (type 1) never builds any: hidden.
M.units.target = { name = "Defias Thug", level = 12, health = 5, healthMax = 10,
    power = M.Secret(0), powerMax = M.Secret(100), powerType = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("secret, NPC with rage: hidden", t.power:IsShown(), false)
-- A secret maximum with mana cannot be told apart from a caster: stays.
M.units.target = { name = "Defias Mage", level = 12, health = 5, healthMax = 10,
    power = M.Secret(0), powerMax = M.Secret(0), powerType = 0 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("secret, NPC with mana: bar stays", t.power:IsShown(), true)
-- Players and their pets do build rage.
M.units.target = { name = "Warrior", level = 12, health = 5, healthMax = 10, isPlayer = true,
    power = M.Secret(0), powerMax = M.Secret(100), powerType = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("secret, player with rage: bar stays", t.power:IsShown(), true)
M.units.target = { name = "Wolf", level = 12, health = 5, healthMax = 10, playerControlled = true,
    power = M.Secret(0), powerMax = M.Secret(100), powerType = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("secret, a pet with rage: bar stays", t.power:IsShown(), true)

-- Switched off: the empty bar as before.
M.units.target = { name = "Boar", level = 12, health = 5, healthMax = 10 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("again without power: hidden", t.power:IsShown(), false)
C.Set("target", "powerHideEmpty", false)
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("off: empty bar shown", t.power:IsShown(), true)

-- The player's frame never hides its bar, whatever the value.
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10 }
ns.Single.UpdateAll(ns.Frames.player)
H.check("player: bar stays", ns.Frames.player.power:IsShown(), true)
