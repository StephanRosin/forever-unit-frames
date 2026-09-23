local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
M.units.player = { name = "Tester", level = 60, class = "WARLOCK", className = "Warlock", isPlayer = true,
    health = M.Secret(900), healthMax = M.Secret(1000), healthPercent = M.Secret(0.9), healthMissing = M.Secret(100),
    power = M.Secret(400), powerMax = M.Secret(500), powerPercent = M.Secret(0.8), powerType = 0 }
ns.Single.CreateAll()
local f = ns.Frames.player

local _, _, ph = ns.Layout.Bars(46, 75, 25, true)
H.check("power height", f.power:GetHeight(), ph)
H.check("power value secret passthrough", f.power:GetValue(), M.units.player.power)
H.check("mana colour", f.power._color[3], ns.Power.COLORS[0][3])

-- Player defaults: health left NAME_LEVEL, health right CURRENT_MAX, power right CURRENT.
local t = f.texts
H.check("name level format", t.healthLeft._fmt, "%s %s")
H.check("name level level arg", t.healthLeft._args[1], "60")
H.check("current/max format", t.healthRight._fmt, "%s / %s")
H.check("current/max passes secret", t.healthRight._args[1], M.units.player.health)
H.check("power current secret", t.powerRight._text, M.units.player.power)
H.check("unused slot empty", t.powerLeft._text, "")

-- Readable values are abbreviated.
M.units.player.health, M.units.player.healthMax = 12345, 20000
M.FireEvent("UNIT_HEALTH", "player")
H.check("abbreviated when readable", t.healthRight._args[1], "12.3k")

-- Percent uses the curve and a format, never Lua maths.
ns.Config.Set("player", "textHealthRight", "PERCENT")
H.check("percent format", t.healthRight._fmt, "%.0f%%")

-- Deficit via TruncateWhenZero
ns.Config.Set("player", "textHealthRight", "DEFICIT")
H.check("deficit passes through", t.healthRight._text, M.units.player.healthMissing)

-- Level ?? for unknown (-1) level
M.units.target = { name = "Boss", level = -1, health = 1, healthMax = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("boss level", ns.Frames.target.texts.healthLeft._args[1], "??")

-- Power bar off hides it and health fills the frame.
ns.Config.Set("player", "powerEnabled", false)
H.check("power hidden", f.power:IsShown(), false)
H.check("health full height", f.health:GetHeight(), 46)

-- Fonts follow config
ns.Config.Set("general", "fontSize", 15)
H.check("font size applied", t.healthLeft._font[2], 15)
H.check("font outline applied", t.healthLeft._font[3], "OUTLINE")

-- Shapeshift: UNIT_DISPLAYPOWER alone must refresh the power texts.
M.units.player.power, M.units.player.powerType = 77, 1
M.FireEvent("UNIT_DISPLAYPOWER", "player")
H.check("power text refreshed on display power change", t.powerRight._text, "77")
