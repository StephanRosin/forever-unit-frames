-- A right text on the title row (titleTextRight), like the left and right
-- texts on the bars: requested on CurseForge. The left title text ends
-- where it begins; it stays empty by default.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
local C, S = ns.Config, ns.Settings
M.units.player = { name = "Me", level = 60, class = "WARLOCK", className = "Warlock", isPlayer = true,
    health = 5, healthMax = 10 }
M.units.target = { name = "Friend", level = 58, class = "WARRIOR", className = "Warrior", isPlayer = true,
    health = 30, healthMax = 40 }
ns.Single.CreateAll()
M.FireEvent("PLAYER_TARGET_CHANGED")
local t = ns.Frames.target
local left, right = t.texts.title, t.texts.titleRight
local function point(region, name)
    for i = 1, #region._points do
        local p = { region:GetPoint(i) }
        if p[1] == name then return p end
    end
end

local def = S.Get("titleTextRight")
H.check("code", def.code, "NR")
H.check("the bar texts' choices", table.concat(def.values, ","), table.concat(S.TEXT_TAGS, ","))
for _, scope in ipairs({ "player", "target", "targettarget", "pet", "focus", "party" }) do
    H.check("empty by default: " .. scope, S.Default(def, scope), "NONE")
end
H.check("label", ns.L.SETTING_titleTextRight, "Title row, right text")
H.check("left label", ns.L.SETTING_titleText, "Title row, left text")

H.check("empty by default", right._text, "")
H.check("left text ends where the right one begins", point(left, "RIGHT")[2], right)
H.check("right text ends at the class badge", point(right, "RIGHT")[2], t.classBadge)
C.Set("target", "titleClassIcon", false)
H.check("without the badge: at the row's right end", point(right, "RIGHT")[2], t.title)
C.Set("target", "titleClassIcon", true)

-- Split: the name left, the level right.
C.Set("target", "titleText", "NAME")
C.Set("target", "titleTextRight", "LEVEL")
H.check("name left", left._text, "Friend")
H.check("level right", right._text, "58")
H.checkTrue("right-aligned", right._justifyH == nil or right._justifyH == "RIGHT")

-- A value on the right: health of the unit, in white.
C.Set("target", "titleTextRight", "PERCENT")
H.check("percent format", right._fmt, "%.0f%%")
H.check("value in white", right._color[1] .. right._color[2] .. right._color[3], "111")
-- A name on the right takes the title colour.
C.Set("target", "titleTextRight", "NAME")
H.check("name in the title colour", right._color[1], left._color[1])

-- No title row: hidden with the left one.
C.Set("target", "titlePercent", 0)
H.check("no title row: hidden", right:IsShown(), false)
C.Set("target", "titlePercent", 30)
H.checkTrue("title row back: shown", right:IsShown())

-- The away badge leaves room for the right text.
C.Set("target", "titleTextRight", "LEVEL")
C.Set("target", "titleText", "NAME")
M.units.target.afk = true
ns.Single.UpdateAll(t)
local withRight = left:GetWidth()
C.Set("target", "titleTextRight", "NONE")
ns.Single.UpdateAll(t)
H.checkTrue("AFK badge shown", t.awayBadge:IsShown())
H.checkTrue("less room for the name with a right text", withRight <= left:GetWidth())

-- Options: beside the left text (the centre text, decision 59, between them).
local keys
for _, sec in ipairs(ns.Schema.FRAME[4].sections) do
    if sec.id == "titleText" then keys = table.concat(sec.keys, ",") end
end
H.checkTrue("on the Text tab after the left text", keys and keys:find("titleText,titleTextCenter,titleTextRight", 1, true))
