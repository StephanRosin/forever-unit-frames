-- The away badge (awayBadge): a pill right after the name in the title
-- row, "AFK" in gold or "DND" in red.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
local C, S, Texts = ns.Config, ns.Settings, ns.Texts
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10, isPlayer = true }
M.units.target = { name = "Friend", level = 60, health = 5, healthMax = 10, isPlayer = true }
ns.Single.CreateAll()
local t = ns.Frames.target
local title, badge = t.texts.title, t.awayBadge

local def = S.Get("awayBadge")
H.checkTrue("setting", def)
H.check("code", def.code, "AK")
H.check("on by default", S.Default(def, "general"), true)
H.checkTrue("label", ns.L.SETTING_awayBadge ~= "SETTING_awayBadge")
H.checkTrue("hint", ns.L.HINT_awayBadge ~= "HINT_awayBadge")
H.checkTrue("in the event list", (function()
    for _, e in ipairs(Texts.unitEvents) do if e == "PLAYER_FLAGS_CHANGED" then return true end end
end)())

M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("present: no badge", badge:IsShown(), false)

M.units.target.afk = true
ns.Single.UpdateAll(t)
H.check("AFK: shown", badge:IsShown(), true)
H.check("AFK: the word", badge.text._text, "AFK")
H.check("AFK: gold text", badge.text._color and badge.text._color[2], Texts.AWAY_STYLES.AFK.text[2])
H.check("AFK: right after the name", select(3, badge:GetPoint(1)), "RIGHT")
H.check("AFK: hangs from the title text", select(2, badge:GetPoint(1)), title)
H.check("name untouched", title._fmt and title._fmt:format(unpack(title._args)) or title._text, "60 Friend")
H.checkTrue("title no wider than the room", title:GetWidth() >= 1)

M.units.target.afk, M.units.target.dnd = false, true
ns.Single.UpdateAll(t)
H.check("DND: the word", badge.text._text, "DND")
H.check("DND: red text", badge.text._color and badge.text._color[2], Texts.AWAY_STYLES.DND.text[2])

-- In an encounter the flags may be secret: no badge, no error.
M.units.target.dnd = M.Secret(true)
ns.Single.UpdateAll(t)
H.check("secret flag: no badge", badge:IsShown(), false)
H.check("secret flag: title back on its anchors", select(2, title:GetPoint(1)), t.title)

-- Switched off.
M.units.target.dnd = true
C.Set("target", "awayBadge", false)
ns.Single.UpdateAll(t)
H.check("off: no badge", badge:IsShown(), false)
C.Set("target", "awayBadge", true)
ns.Single.UpdateAll(t)
H.check("on again", badge:IsShown(), true)

-- Reported 04.10.2026 (CurseForge, by mail): targeting an AFK player threw
-- "attempt to perform arithmetic on a secret number value" in
-- UpdateAwayBadge: the badge's own text width came back secret (its pill
-- hangs from the title text, whose name may be secret). Widths that cannot
-- be read are estimated; nothing is calculated with a secret.
do
    local text = t.awayBadge.text
    local plainWidth = text.GetStringWidth
    text.GetStringWidth = function() return M.Secret(14) end
    local titleWidth = t.title.GetWidth
    t.title.GetWidth = function() return M.Secret(200) end
    local badgeHeight = t.awayBadge.GetHeight
    t.awayBadge.GetHeight = function() return M.Secret(13) end
    M.units.target.afk, M.units.target.dnd = true, false
    local ok, err = pcall(ns.Single.UpdateAll, t)
    H.checkTrue("secret widths: no error (" .. tostring(err) .. ")", ok)
    H.check("secret widths: badge still shown", t.awayBadge:IsShown(), true)
    local w = t.awayBadge:GetWidth()
    H.checkTrue("secret widths: a plain, sensible badge width", type(w) == "number" and w > 10 and w < 60)
    text.GetStringWidth, t.title.GetWidth, t.awayBadge.GetHeight = plainWidth, titleWidth, badgeHeight
end
