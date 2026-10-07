-- The elite / rare marker (MARKER style) can be moved (decision 61): a
-- point on the frame, the marker's own point and an offset. "Automatic",
-- the default, is the place it always had (on the portrait's corner, or
-- the word above the frame's top right corner, out of the class badge's
-- way); the offset then moves it from there.
local M = H.M
local ns = H.LoadAddon()
local S, C, L = ns.Settings, ns.Config, ns.L

-- Settings ------------------------------------------------------------------------
local CODES = { eliteMarkerFramePoint = "MF", eliteMarkerPoint = "MO", eliteMarkerX = "MX", eliteMarkerY = "MY" }
for key, code in pairs(CODES) do
    local def = S.Get(key)
    H.checkTrue("setting " .. key, def)
    H.check("code of " .. key, def and def.code, code)
    for _, scope in ipairs({ "target", "targettarget", "focus" }) do
        H.checkTrue(key .. " on " .. scope, def and S.AppliesTo(def, scope))
    end
    for _, scope in ipairs({ "general", "player", "pet", "party" }) do
        H.check(key .. " not on " .. scope, def and S.AppliesTo(def, scope), false)
    end
end
local fp = S.Get("eliteMarkerFramePoint")
H.check("automatic first, then the points", fp and table.concat(fp.values, ","),
    "AUTO," .. table.concat(S.POINTS, ","))
H.check("automatic by default", fp and S.Default(fp, "target"), "AUTO")
H.check("marker point default", S.Get("eliteMarkerPoint") and S.Default(S.Get("eliteMarkerPoint"), "target"), "CENTER")
H.check("x default", S.Get("eliteMarkerX") and S.Default(S.Get("eliteMarkerX"), "target"), 0)
H.check("y default", S.Get("eliteMarkerY") and S.Default(S.Get("eliteMarkerY"), "target"), 0)
H.check("automatic label", ns.Schema.EnumText(fp or {}, "AUTO"), "Automatic")
-- In the elite marker's section after the marker's other settings.
local keys
for _, tab in ipairs(ns.Schema.Tabs("target")) do
    for _, sec in ipairs(tab.sections or {}) do
        if sec.id == "eliteMarker" then keys = table.concat(sec.keys, ",") end
    end
end
H.checkTrue("in the elite marker's section", keys and keys:find(
    "eliteBorderSize,eliteMarkerFramePoint,eliteMarkerPoint,eliteMarkerX,eliteMarkerY", 1, true))
H.checkTrue("labels", L.SETTING_eliteMarkerX ~= "SETTING_eliteMarkerX")

-- Placing --------------------------------------------------------------------------
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local f = ns.Frames.target
local icon, text = f.eliteIcon, f.eliteText
M.units.target = { name = "Ogre", health = 1, healthMax = 1, classification = "elite" }
M.FireEvent("PLAYER_TARGET_CHANGED")
local function pts(region)
    local p = { region:GetPoint(1) }
    return table.concat({ tostring(p[1]), tostring(p[2] == f and "frame" or p[2] == f.portraitBg and "portrait"
        or "?"), tostring(p[3]), tostring(p[4]), tostring(p[5]) }, ",")
end
local autoWord = pts(text)
H.check("word: one point", #text._points, 1)

-- Automatic with an offset: from the automatic place.
C.Set("target", "eliteMarkerX", -10)
C.Set("target", "eliteMarkerY", 5)
local p = { text:GetPoint(1) }
local q = {}
for v in autoWord:gmatch("[^,]+") do q[#q + 1] = v end
H.check("auto + offset: same point", p[1], q[1])
H.check("auto + offset: x moved", p[4], tonumber(q[4]) - 10)
H.check("auto + offset: y moved", p[5], tonumber(q[5]) + 5)

-- A point of its own: the word's own point there (it has no width, so
-- no justification: the point alone places it).
C.Set("target", "eliteMarkerFramePoint", "BOTTOMLEFT")
C.Set("target", "eliteMarkerPoint", "TOPLEFT")
H.check("own point: the word", pts(text), "TOPLEFT,frame,BOTTOMLEFT,-10,5")
H.checkTrue("still shown", text:IsShown())
C.Set("target", "eliteMarkerPoint", "CENTER")
H.check("centre: the word's centre there", pts(text), "CENTER,frame,BOTTOMLEFT,-10,5")
H.check("no width of its own", text:GetWidth(), 0)

-- The portrait badge: at the frame's point too.
C.Set("target", "portraitMode", "LEFT")
H.checkTrue("badge shown", icon:IsShown())
H.check("own point: the badge", pts(icon), "CENTER,frame,BOTTOMLEFT,-10,5")
H.check("badge keeps its size", icon:GetWidth(), ns.Pixel.Snap(46 * 0.45))

-- Back to automatic, no offset: exactly as before.
C.Set("target", "eliteMarkerFramePoint", "AUTO")
C.Set("target", "eliteMarkerX", 0)
C.Set("target", "eliteMarkerY", 0)
H.check("auto badge: the portrait's outer corner", pts(icon), "TOPLEFT,portrait,TOPLEFT," ..
    tostring(-ns.Pixel.Snap(ns.Pixel.Snap(46 * 0.45) / 3)) .. "," .. tostring(ns.Pixel.Snap(ns.Pixel.Snap(46 * 0.45) / 3)))
C.Set("target", "portraitMode", "OFF")
H.check("auto word: as before", pts(text), autoWord)

-- The border style ignores it; the other frames keep their own.
C.Set("target", "eliteMarkerFramePoint", "LEFT")
C.Set("target", "eliteMarkerStyle", "BORDER")
H.check("border: no word", text:IsShown(), false)
C.Set("target", "eliteMarkerStyle", "MARKER")
H.check("focus untouched", C.Get("focus", "eliteMarkerFramePoint"), "AUTO")
