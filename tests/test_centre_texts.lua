-- A centre text on the title row and on the health and power bars
-- (titleTextCenter, textHealthCenter, textPowerCenter), the same choices
-- as the left and right texts, empty by default. While one is set, the
-- left and right texts of its row are kept to their third and cut off.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
local C, S, L = ns.Config, ns.Settings, ns.L
M.units.player = { name = "Me", level = 60, class = "WARLOCK", className = "Warlock", isPlayer = true,
    health = 5, healthMax = 10, power = 20, powerMax = 50 }
M.units.target = { name = "Friend", level = 58, class = "WARRIOR", className = "Warrior", isPlayer = true,
    health = 30, healthMax = 40, power = 10, powerMax = 100 }
ns.Single.CreateAll()
M.FireEvent("PLAYER_TARGET_CHANGED")

local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

-- Settings ------------------------------------------------------------------------
local CODES = { titleTextCenter = "NM", textHealthCenter = "TM", textPowerCenter = "UC" }
for key, code in pairs(CODES) do
    local def = S.Get(key)
    H.checkTrue("setting " .. key, def)
    H.check("code of " .. key, def and def.code, code)
    H.check(key .. ": the texts' choices", def and table.concat(def.values, ","), table.concat(S.TEXT_TAGS, ","))
    for _, scope in ipairs({ "player", "target", "targettarget", "pet", "focus", "party" }) do
        H.check(key .. " empty by default on " .. scope, def and S.Default(def, scope), "NONE")
    end
    H.check(key .. " not in General", def and S.AppliesTo(def, "general"), false)
end
H.check("label", L.SETTING_titleTextCenter, "Title row, centre text")
H.check("health label", L.SETTING_textHealthCenter, "Health bar, centre text")
H.check("power label", L.SETTING_textPowerCenter, "Power bar, centre text")

-- On the Text tab, between the left and the right text of its row.
local sections = {}
for _, tab in ipairs(ns.Schema.Tabs("target")) do
    for _, sec in ipairs(tab.sections or {}) do sections[sec.id] = table.concat(sec.keys, ",") end
end
H.checkTrue("title: left, centre, right", sections.titleText:find("titleText,titleTextCenter,titleTextRight", 1, true))
H.check("health: left, centre, right", sections.healthText, "textHealthLeft,textHealthCenter,textHealthRight")
H.check("power: left, centre, right", sections.powerText, "textPowerLeft,textPowerCenter,textPowerRight")

-- Nothing set: empty, and the left and right texts as before -----------------------
local t = ns.Frames.target
local tx = t.texts
H.check("health centre empty", tx.healthCenter._text, "")
H.check("left ends at the right text", point(tx.healthLeft, "RIGHT")[2], tx.healthRight)
H.check("right text: one point", #tx.healthRight._points, 1)

-- Health centre set: in the middle third, left and right in theirs ---------------
C.Set("target", "textHealthCenter", "PERCENT")
local third = ns.Pixel.Snap(t.healthWidth / 3)
local c = tx.healthCenter
H.check("centre shows the value", c._fmt, "%.0f%%")
H.checkTrue("centre shown", c:IsShown())
H.check("centre: from the first third", table.concat({ point(c, "LEFT")[3], point(c, "LEFT")[4] }, ","),
    "LEFT," .. third)
H.check("centre: to the last third", table.concat({ point(c, "RIGHT")[3], point(c, "RIGHT")[4] }, ","),
    "RIGHT," .. -third)
H.check("centre: on the health bar", point(c, "LEFT")[2], t.health)
H.check("centre: centred", c._justifyH, "CENTER")
H.check("centre: one line", c:GetWordWrap(), false)
H.check("left ends at the centre", point(tx.healthLeft, "RIGHT")[2], c)
H.check("left: no wrap", tx.healthLeft:GetWordWrap(), false)
H.check("right begins after the centre", point(tx.healthRight, "LEFT")[2], c)
H.check("right: still at the bar's end", point(tx.healthRight, "RIGHT")[2], t.health)
H.check("right: no wrap", tx.healthRight:GetWordWrap(), false)
H.check("right: right-aligned", tx.healthRight._justifyH, "RIGHT")
-- The power bar keeps its own layout.
H.check("power: untouched", point(tx.powerLeft, "RIGHT")[2], tx.powerRight)
H.check("power centre hidden while empty", tx.powerCenter:IsShown(), false)

-- Back to nothing: as before.
C.Set("target", "textHealthCenter", "NONE")
H.check("unset: left ends at the right text", point(tx.healthLeft, "RIGHT")[2], tx.healthRight)
H.check("unset: right text back to one point", #tx.healthRight._points, 1)
H.check("unset: centre hidden", c:IsShown(), false)

-- Power centre: the power bar's values.
C.Set("target", "textPowerCenter", "CURRENT_MAX")
H.check("power centre: power values", table.concat(tx.powerCenter._args, ","), "10,100")
H.check("power centre: on the power bar", point(tx.powerCenter, "LEFT")[2], t.power)
H.check("power centre: power bar's third", point(tx.powerCenter, "LEFT")[4], ns.Pixel.Snap(t.powerWidth / 3))
C.Set("target", "textPowerCenter", "NONE")

-- Title centre: the title texts keep to their thirds, the right one still
-- ends at the class badge.
C.Set("target", "titleText", "NAME")
C.Set("target", "titleTextCenter", "LEVEL")
C.Set("target", "titleTextRight", "PERCENT")
local tc = tx.titleCenter
H.check("title centre: the level", tc._text, "58")
H.check("title centre: on the title row", point(tc, "LEFT")[2], t.title)
H.check("title centre: the row's third", point(tc, "LEFT")[4], ns.Pixel.Snap(t.titleWidth / 3))
H.check("title: left ends at the centre", point(tx.title, "RIGHT")[2], tc)
H.check("title: right begins after the centre", point(tx.titleRight, "LEFT")[2], tc)
H.check("title: right still ends at the badge", point(tx.titleRight, "RIGHT")[2], t.classBadge)
-- A name in the centre takes the title colour, a value stays white.
H.check("title centre: level in white", tc._color[1] .. tc._color[2] .. tc._color[3], "111")
C.Set("target", "titleTextCenter", "NAME")
H.check("title centre: a name in the title colour", tc._color[1], tx.title._color[1])
-- No title row: hidden with the others.
C.Set("target", "titlePercent", 0)
H.check("no title row: centre hidden", tc:IsShown(), false)
C.Set("target", "titlePercent", 30)
H.checkTrue("title row back: centre shown", tc:IsShown())

-- The away badge: the name keeps to its third.
M.units.target.afk = true
M.FireEvent("PLAYER_FLAGS_CHANGED", "target")
H.checkTrue("badge shown", t.awayBadge:IsShown())
H.checkTrue("name within its third", tx.title._w <= ns.Pixel.Snap(t.titleWidth / 3))
M.units.target.afk = nil
M.FireEvent("PLAYER_FLAGS_CHANGED", "target")
H.check("badge gone: left ends at the centre again", point(tx.title, "RIGHT")[2], tc)
C.Set("target", "titleTextCenter", "NONE")
H.check("title centre unset: left ends at the right text", point(tx.title, "RIGHT")[2], tx.titleRight)
H.check("title centre unset: right text one point", #tx.titleRight._points, 1)

-- Secret values go to the font string untouched.
C.Set("player", "textHealthCenter", "CURRENT")
M.units.player.health = M.Secret(7)
M.FireEvent("UNIT_HEALTH", "player")
local pc = ns.Frames.player.texts.healthCenter
H.checkTrue("secret health: shown as given", M.IsSecret(pc._text) or (pc._args and M.IsSecret(pc._args[1])))

-- Dead: the word goes to the first value text, the centre one too when
-- it is the only one.
M.units.player.health = 0
M.units.player.dead = true
C.Set("player", "textHealthLeft", "NONE")
C.Set("player", "textHealthRight", "NONE")
H.check("dead: the word in the centre", pc._text, L.STATUS_DEAD)
M.units.player.dead = nil
M.units.player.health = 5
C.Set("player", "textHealthCenter", "NONE")
M.units.player.dead = true
M.units.player.health = 0
M.FireEvent("UNIT_HEALTH", "player")
H.check("dead, no centre text: the word on the right as before",
    ns.Frames.player.texts.healthRight._text, L.STATUS_DEAD)
M.units.player.dead = nil
M.units.player.health = 5

-- Raid cells never show one.
do
    local cell = ns.RaidCell
    for _, key in ipairs({ "titleTextCenter", "textHealthCenter", "textPowerCenter" }) do
        H.check("raid cell: no " .. key, cell.Resolve(key), "NONE")
    end
end
