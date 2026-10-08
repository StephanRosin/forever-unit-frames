-- Never fade in a group (playerFadeGroup, 0.24.0): while in a party or a
-- raid the player frame's out-of-combat fade does not apply, so a healer
-- who heals by mouse-over without a target still sees the frame. The pet
-- frame that follows the fade shows in full with it. Off by default.
local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config

local def = S.Get("playerFadeGroup")
H.checkTrue("setting", def)
H.check("code", def and def.code, "WG")
H.check("a switch", def and def.type, "bool")
H.check("player only", def and S.AppliesTo(def, "pet"), false)
H.check("off by default", def and S.Default(def, "player"), false)
H.check("label", ns.L.SETTING_playerFadeGroup, "Never fade in a group")
local keys
for _, tab in ipairs(ns.Schema.Tabs("player")) do
    for _, sec in ipairs(tab.sections or {}) do
        if sec.id == "outOfCombat" then keys = table.concat(sec.keys, ",") end
    end
end
H.check("in the player's fade section", keys,
    "playerFadeOOC,playerFadeAlpha,playerFadeTarget,playerFadeGroup,playerFadePet")

M.units.player = { name = "Me", health = 100, healthMax = 100, power = 50, powerMax = 50, powerType = 0 }
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local f, pet = ns.Frames.player, ns.Frames.pet
M.units.pet = { name = "Wolf", health = 10, healthMax = 10 }
M.FireEvent("UNIT_PET", "player")
C.Set("player", "playerFadeOOC", true)
C.Set("player", "playerFadeAlpha", 20)
C.Set("player", "playerFadePet", true)

-- Off (default): a group changes nothing.
M.SetGroup({ "party1" })
H.check("off: faded in a party", f:GetAlpha(), 0.2)
M.SetGroup({})

C.Set("player", "playerFadeGroup", true)
H.check("on, solo: faded", f:GetAlpha(), 0.2)
H.check("on, solo: the blocker", ns.CombatFade.Blocker(), nil)
M.SetGroup({ "party1" })
H.check("party: in full", f:GetAlpha(), 1)
H.check("party: the pet in full", pet:GetAlpha(), 1)
H.check("party: the blocker", ns.CombatFade.Blocker(), "GROUP")
H.check("status word", ns.L.FADE_GROUP, "you are in a group")
M.SetGroup({})
H.check("left the party: faded again", f:GetAlpha(), 0.2)
H.check("left the party: pet faded again", pet:GetAlpha(), 0.2)

M.SetRaidRoster({ { name = "Me", class = "PRIEST", subgroup = 1 }, { name = "Other", class = "MAGE", subgroup = 1 } })
H.check("raid: in full", f:GetAlpha(), 1)
M.SetRaidRoster({})
H.check("left the raid: faded", f:GetAlpha(), 0.2)

-- Switched off again while grouped: the fade applies again.
M.SetGroup({ "party1" })
C.Set("player", "playerFadeGroup", false)
H.check("off again in a party: faded", f:GetAlpha(), 0.2)
M.SetGroup({})
