-- The elite / rare marker's size (MARKER style): 0, "Automatic", the
-- default, is the size it always had (the badge 45 % of the frame's
-- height, at least 10; the word two points under the frame's font);
-- otherwise the badge's size or the word's font size, 8 to 64. The word
-- still moves out of the class badge's way at its chosen size.
local M = H.M
local ns = H.LoadAddon()
local S, C, L, Pixel = ns.Settings, ns.Config, ns.L, ns.Pixel

local def = S.Get("eliteMarkerSize")
H.checkTrue("setting", def)
H.check("code", def and def.code, "MZ")
for _, scope in ipairs({ "target", "targettarget", "focus" }) do
    H.checkTrue("on " .. scope, def and S.AppliesTo(def, scope))
end
for _, scope in ipairs({ "general", "player", "pet", "party" }) do
    H.check("not on " .. scope, def and S.AppliesTo(def, scope), false)
end
H.check("automatic by default", def and S.Default(def, "target"), 0)
H.check("zero reads Automatic", def and L[def.zeroText], L.AUTO)
H.check("max", def and def.max, 64)
H.check("1..7 become 8", def and S.Validate(def, 3), 8)
H.check("0 stays", def and S.Validate(def, 0), 0)
H.check("past the max", def and S.Validate(def, 99), 64)
-- In the marker's section, beside the offsets; greyed like them.
local keys
for _, tab in ipairs(ns.Schema.Tabs("target")) do
    for _, sec in ipairs(tab.sections or {}) do
        if sec.id == "eliteMarker" then keys = table.concat(sec.keys, ",") end
    end
end
H.checkTrue("in the section after the offsets", keys and keys:find("eliteMarkerX,eliteMarkerY,eliteMarkerSize", 1, true))
H.checkTrue("label", L.SETTING_eliteMarkerSize ~= "SETTING_eliteMarkerSize")
H.checkTrue("hint", L.HINT_eliteMarkerSize ~= "HINT_eliteMarkerSize")

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local f = ns.Frames.target
local icon, text = f.eliteIcon, f.eliteText
M.units.target = { name = "Ogre", health = 1, healthMax = 1, classification = "elite" }
M.FireEvent("PLAYER_TARGET_CHANGED")

-- The word.
local autoFont = text._font[2]
H.check("auto word: the frame's font less two", autoFont, C.Get("target", "fontSize") - 2)
C.Set("target", "eliteMarkerSize", 20)
H.check("word: its size", text._font[2], 20)
C.Set("target", "eliteMarkerSize", 0)
H.check("word: automatic again", text._font[2], autoFont)

-- The badge.
C.Set("target", "portraitMode", "LEFT")
H.check("auto badge", icon:GetWidth(), Pixel.Snap(46 * 0.45))
C.Set("target", "eliteMarkerSize", 30)
H.check("badge: its size", icon:GetWidth() .. "x" .. icon:GetHeight(), "30x30")
local p = { icon:GetPoint(1) }
H.check("badge: sticks out by a third of its size", p[4], -Pixel.Snap(30 / 3))
C.Set("target", "portraitMode", "OFF")
C.Set("target", "eliteMarkerSize", 0)

-- The word at its size keeps clear of the class badge: a badge high above
-- the corner misses the small word and is in the way of a big one.
M.units.target = { name = "Ogre", isPlayer = true, className = "Warrior", class = "WARRIOR", health = 1,
    healthMax = 1, classification = "elite" }
C.Set("target", "classIconY", 30)
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("the class badge shows", f.classIcon and f.classIcon:IsShown() and f.classBadgeBox)
p = { text:GetPoint(1) }
H.check("auto word: under the badge's reach, not moved", p[4], 0)
C.Set("target", "eliteMarkerSize", 40)
p = { text:GetPoint(1) }
H.check("big word: left of the badge", p[4], f.classBadgeBox.left - Pixel.Snap(2))
H.check("the size asked", ns.Classification.TextSize("target"), 40)
C.Set("target", "eliteMarkerSize", 0)
H.check("auto size asked", ns.Classification.TextSize("target"), ns.Classification.FontSize("target"))
C.Set("target", "classIconY", 2)

-- Greyed with the offsets.
local deps = ns.Options.ROW_ACTIVE.eliteMarkerSize
H.checkTrue("greyed rule", deps)
C.Set("target", "eliteMarkerStyle", "BORDER")
H.check("border: greyed", deps("target"), false)
C.Set("target", "eliteMarkerStyle", "MARKER")
C.Set("target", "eliteMarker", false)
H.check("off: greyed", deps("target"), false)
C.Set("target", "eliteMarker", true)
H.check("marker: active", deps("target"), true)
