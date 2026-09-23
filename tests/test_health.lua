local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()

local f = ns.Frames.player
H.check("secure template", f._template, "SecureUnitButtonTemplate")
H.check("unit attribute", f:GetAttribute("unit"), "player")
H.check("left click targets", f:GetAttribute("*type1"), "target")
H.check("right click menu", f:GetAttribute("*type2"), "togglemenu")
H.checkTrue("unit watch", f._unitWatch)
H.check("width from config", f:GetWidth(), 220)

-- Health bar height follows the layout maths (power bar arrives in Task 9).
local hh = ns.Layout.Bars(46, 75, 25, true)
H.check("health height", f.health:GetHeight(), hh)

-- Secret health values pass straight through to the bar.
local hp, hpMax = M.Secret(900), M.Secret(1000)
M.units.player = { name = "Tester", level = 60, class = "WARLOCK", className = "Warlock",
    isPlayer = true, health = hp, healthMax = hpMax, healthPercent = M.Secret(0.9) }
M.FireEvent("UNIT_HEALTH", "player")
H.check("bar value is the secret", f.health:GetValue(), hp)
local _, max = f.health:GetMinMaxValues()
H.check("bar max is the secret", max, hpMax)

-- Class colour
local c = f.health._color
H.check("class color r", c[1], RAID_CLASS_COLORS.WARLOCK.r)

-- Other units' events do not touch this frame.
M.units.target = { health = 5, healthMax = 10 }
M.FireEvent("UNIT_HEALTH", "target")
H.check("player unchanged by target event", f.health:GetValue(), hp)

-- Reaction mode with a secret reaction falls back to UnitIsFriend.
ns.Config.Set("target", "healthColorMode", "REACTION")
M.units.target = { health = 5, healthMax = 10, reaction = M.Secret(2), friend = false }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("hostile red via fallback", ns.Frames.target.health._color[1], 0.85)

-- Config change restyles out of combat, defers in combat.
ns.Config.Set("player", "width", 250)
H.check("restyled", f:GetWidth(), 250)
M.combat = true
ns.Config.Set("player", "width", 260)
H.check("deferred in combat", f:GetWidth(), 250)
M.SetCombat(false)
H.check("applied after combat", f:GetWidth(), 260)

-- Disabled frames lose their unit watch and hide.
ns.Config.Set("target", "enabled", false)
H.check("disabled: no watch", ns.Frames.target._unitWatch, nil)
H.check("disabled: hidden", ns.Frames.target:IsShown(), false)
