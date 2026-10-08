-- Combat numbers: place, font, size and outline of their own (0.24.0).
-- Defaults keep today's look: the centre of the portrait or health bar,
-- the frame's font and outline, the size steps from the frame's font size.
local M = H.M
local ns = H.LoadAddon()
local S, L, CF = ns.Settings, ns.L, ns.CombatFeedback

local EXPECTED = {
    combatFeedbackPoint = { "CG", "enum", "CENTER" },
    combatFeedbackX = { "CJ", "int", 0 },
    combatFeedbackY = { "CM", "int", 0 },
    combatFeedbackFont = { "CO", "media", "" },
    combatFeedbackSize = { "CS", "int", 0 },
    combatFeedbackOutline = { "CU", "enum", "FRAME" },
}
for key, want in pairs(EXPECTED) do
    local def = S.Get(key)
    H.checkTrue(key .. " defined", def)
    H.check(key .. " code", def and def.code, want[1])
    H.check(key .. " type", def and def.type, want[2])
    H.check(key .. " per frame", def and def.scope, "frame")
    H.check(key .. " default", def and S.Default(def, "target"), want[3])
    H.check(key .. " label", type(rawget(ns.Locales.enUS, "SETTING_" .. key)), "string")
end
H.check("points", table.concat(S.Get("combatFeedbackPoint").values, ","), "LEFT,CENTER,RIGHT")
H.check("outlines: the frame's first", table.concat(S.Get("combatFeedbackOutline").values, ","),
    "FRAME,NONE,OUTLINE,THICKOUTLINE,MONOCHROME,SOFT")
H.check("size: 0 is automatic", S.Get("combatFeedbackSize").zeroText, "AUTO")
H.check("font: empty is the frame's", S.Validate(S.Get("combatFeedbackFont"), ""), "")
H.check("other fonts: empty refused", S.Validate(S.Get("fontFace"), ""), nil)

local keys
for _, tab in ipairs(ns.Schema.Tabs("player")) do
    for _, sec in ipairs(tab.sections or {}) do
        if sec.id == "combatFeedback" then keys = table.concat(sec.keys, ",") end
    end
end
H.check("rows in the combat numbers section", keys, "combatFeedback,combatFeedbackPoint,combatFeedbackX,"
    .. "combatFeedbackY,combatFeedbackFont,combatFeedbackSize,combatFeedbackOutline")

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
local f = ns.Frames.player
local text = f.feedbackText
M.units.player = { name = "Me", health = 5, healthMax = 10 }

-- Defaults: today's place, font and size.
local point, anchor, relative, x, y = text:GetPoint(1)
H.check("default point", point .. ">" .. relative, "CENTER>CENTER")
H.check("default anchor", anchor, f.health)
H.check("default offset", x .. "," .. y, "0,0")
H.check("default font: the frame's", text._font[1], ns.Media.Font(C.Get("player", "fontFace")))
H.check("default size", text._font[2], 18)

-- Left and right: on the health bar's edge, plus the offset.
C.Set("player", "combatFeedbackPoint", "LEFT")
C.Set("player", "combatFeedbackX", 4)
C.Set("player", "combatFeedbackY", -2)
point, anchor, relative, x, y = text:GetPoint(1)
H.check("left", point .. ">" .. relative, "LEFT>LEFT")
H.check("left: on the health bar", anchor, f.health)
H.check("left: offset", x .. "," .. y, "4,-2")
C.Set("player", "combatFeedbackPoint", "RIGHT")
point, _, relative = text:GetPoint(1)
H.check("right", point .. ">" .. relative, "RIGHT>RIGHT")
H.check("one point only", text:GetNumPoints(), 1)
C.Set("player", "combatFeedbackPoint", "CENTER")
H.check("centre with an offset", select(4, text:GetPoint(1)), 4)

-- A portrait: the centre stays over it as before; left and right on the bar.
C.Set("player", "portraitMode", "LEFT")
H.check("portrait: centre over it", select(2, text:GetPoint(1)), f.portraitBg)
C.Set("player", "combatFeedbackPoint", "LEFT")
H.check("portrait: left on the bar", select(2, text:GetPoint(1)), f.health)
C.ResetScope("player")

-- Font, size and outline of their own.
C.Set("player", "combatFeedbackFont", "Morpheus")
H.check("own font", text._font[1], ns.Media.Font("Morpheus"))
C.Set("player", "combatFeedbackSize", 20)
H.check("own size", text._font[2], 20)
H.check("own size: the base of the steps", CF.Size("player"), 20)
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "CRITICAL", 40, 1)
H.check("own size: critical bigger", text._font[2], 30)
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "", 40, 1)
H.check("own size: normal hit", text._font[2], 20)
H.check("own font on a hit", text._font[1], ns.Media.Font("Morpheus"))
C.Set("player", "combatFeedbackSize", 3)
H.check("size: at least 6", C.Get("player", "combatFeedbackSize"), 6)
C.Set("player", "combatFeedbackOutline", "THICKOUTLINE")
H.check("own outline", text._font[3], "THICKOUTLINE")
C.Set("player", "combatFeedbackOutline", "FRAME")
C.Set("player", "fontOutline", "OUTLINE")
H.check("the frame's outline", text._font[3], "OUTLINE")
C.Set("player", "combatFeedbackFont", "")
C.Set("player", "fontFace", "Skurri")
H.check("the frame's font again", text._font[1], ns.Media.Font("Skurri"))
C.ResetScope("player")
C.ResetScope("general")

-- Another frame keeps its own: the target's settings do not move the player's.
C.Set("target", "combatFeedbackPoint", "RIGHT")
H.check("per frame", (text:GetPoint(1)), "CENTER")
C.ResetScope("target")

-- Export and import: an empty font (the frame's) survives the trip.
C.Set("player", "combatFeedbackFont", "Morpheus")
C.Set("player", "combatFeedbackFont", "")
local profile = { player = { combatFeedbackFont = "", combatFeedbackOutline = "SOFT" } }
local decoded = ns.Codec.Decode(ns.Codec.Encode(profile))
H.check("codec: empty font", decoded and decoded.player and decoded.player.combatFeedbackFont, "")
H.check("codec: outline", decoded and decoded.player and decoded.player.combatFeedbackOutline, "SOFT")
C.ResetScope("player")
