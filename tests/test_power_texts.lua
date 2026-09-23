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

-- Left texts stop short of the right text on narrow bars: a second anchor
-- to the right text's left edge and no wrapping (no measuring, so secret
-- text is fine; an empty right text is zero wide).
do
    local function pointOf(fs, name)
        for i = 1, #fs._points do
            local p = { fs:GetPoint(i) }
            if p[1] == name then return p end
        end
    end
    local texts = ns.Frames.player.texts
    for _, pair in ipairs({ { "healthLeft", "healthRight" }, { "powerLeft", "powerRight" } }) do
        local left, right = texts[pair[1]], texts[pair[2]]
        local p = pointOf(left, "RIGHT")
        H.checkTrue(pair[1] .. ": right anchor", p)
        H.check(pair[1] .. ": anchored to the right text", p[2], right)
        H.check(pair[1] .. ": its left edge", p[3], "LEFT")
        H.check(pair[1] .. ": gap", p[4], -4)
        H.check(pair[1] .. ": still starts at the bar", pointOf(left, "LEFT")[2], ns.Frames.player[pair[1]:sub(1, -5) == "health" and "health" or "power"])
        H.check(pair[1] .. ": no word wrap", left:GetWordWrap(), false)
        H.check(pair[2] .. ": single anchor", #right._points, 1)
    end
end
