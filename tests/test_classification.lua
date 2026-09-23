local M = H.M
local ns = H.LoadAddon()
local S, L, Cl = ns.Settings, ns.L, ns.Classification

local def = S.Get("eliteMarker")
H.check("code", def.code, "EM")
for _, scope in ipairs({ "target", "targettarget", "focus", "party" }) do
    H.checkTrue("applies to " .. scope, S.AppliesTo(def, scope))
end
H.check("not on the player", S.AppliesTo(def, "player"), false)
H.check("not on the pet", S.AppliesTo(def, "pet"), false)
H.check("on by default", S.Default(def, "target"), true)
H.check("label", L.SETTING_eliteMarker, "Elite / rare marker")

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
local f = ns.Frames.target
local icon, text = f.eliteIcon, f.eliteText
H.check("player frame has none", ns.Frames.player.eliteIcon, nil)
H.check("icon on the overlay", icon:GetParent(), f.overlay)
H.check("word on the overlay", text:GetParent(), f.overlay)

-- What a unit is.
local function kindOf(fields)
    M.units.target = fields
    return Cl.Kind("target")
end
H.check("elite", kindOf({ classification = "elite" }), "elite")
H.check("rare", kindOf({ classification = "rare" }), "rare")
H.check("rare elite", kindOf({ classification = "rareelite" }), "rareelite")
H.check("world boss", kindOf({ classification = "worldboss" }), "boss")
H.check("boss mob", kindOf({ classification = "elite", bossMob = true }), "boss")
H.check("normal", kindOf({ classification = "normal" }), nil)
H.check("trivial", kindOf({ classification = "trivial" }), nil)
H.check("minus", kindOf({ classification = "minus" }), nil)
H.check("secret: none", kindOf({ classification = M.Secret("elite") }), nil)
H.check("secret boss flag: by classification", kindOf({ classification = "rare", bossMob = M.Secret(true) }), "rare")

-- No portrait: a word above the frame's top right corner.
M.units.target = { name = "Ogre", health = 1, healthMax = 1, classification = "elite" }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("word shown", text:IsShown())
H.check("icon hidden", icon:IsShown(), false)
H.check("word", text:GetText(), L.CLASS_elite)
H.check("gold", text._color[2], 0.82)
local p = { text:GetPoint(1) }
H.check("above the frame", p[1] .. p[3], "BOTTOMRIGHTTOPRIGHT")
-- The unit box: above a castbar docked on top too.
H.check("on the unit box", p[2], f.unitBox)
H.check("no badge: at the corner", p[4], 0)
H.check("clear of the border", p[5], ns.Border.Extent("target") + ns.Pixel.One())
H.checkTrue("font set", text._font)

-- The event changes it.
M.units.target.classification = "rareelite"
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.check("rare elite word", text:GetText(), L.CLASS_rareelite)
H.check("silver", text._color[1], 0.78)
M.units.target.classification = "normal"
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.check("normal: nothing", text:IsShown(), false)

-- Portrait on: the badge on its outer top corner.
M.units.target.classification = "rare"
C.Set("target", "portraitMode", "LEFT")
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.checkTrue("badge shown", icon:IsShown())
H.check("word hidden", text:IsShown(), false)
H.check("rare star", icon._atlas, "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star")
p = { icon:GetPoint(1) }
H.check("on the portrait", p[2], f.portraitBg)
H.check("outer corner", p[1], "TOPLEFT")
H.checkTrue("sticks out to the left", p[4] < 0)
H.check("size", icon:GetWidth(), ns.Pixel.Snap(46 * 0.45))
C.Set("target", "portraitMode", "RIGHT")
H.check("right: outer corner", icon:GetPoint(1), "TOPRIGHT")
H.checkTrue("sticks out to the right", select(4, icon:GetPoint(1)) > 0)
M.units.target.classification = "elite"
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.check("elite badge", icon._atlas, "nameplates-icon-elite-gold")

-- An atlas the client does not know: the word instead.
M.atlases["nameplates-icon-elite-gold"] = nil
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.check("no atlas: no badge", icon:IsShown(), false)
H.checkTrue("no atlas: the word", text:IsShown())
H.check("no atlas: word text", text:GetText(), L.CLASS_elite)
M.atlases["nameplates-icon-elite-gold"] = true
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.checkTrue("atlas back: badge", icon:IsShown())

-- Off.
C.Set("target", "eliteMarker", false)
H.check("off: no badge", icon:IsShown(), false)
H.check("off: no word", text:IsShown(), false)
C.Set("target", "eliteMarker", true)
H.checkTrue("on again", icon:IsShown())

-- The class badge (Elements/Texts.lua) sits on the frame's top right
-- corner, for players. Where it shows, the marker moves out of its way.
M.units.target = { name = "Hero", isPlayer = true, class = "WARRIOR", className = "Warrior", health = 1,
    healthMax = 1, classification = "elite" }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("class badge shown", f.classIcon:IsShown())
-- Portrait right: its outer corner is under the badge; the inner one.
p = { icon:GetPoint(1) }
H.check("badge: inner corner", p[1], "TOPLEFT")
H.check("badge: on the portrait", p[2], f.portraitBg)
H.checkTrue("badge: sticks out to the left", p[4] < 0)
C.Set("target", "portraitMode", "LEFT")
H.check("portrait left: outer corner", icon:GetPoint(1), "TOPLEFT")
H.checkTrue("portrait left: outer, to the left", select(4, icon:GetPoint(1)) < 0)
-- No portrait: the word ends left of the badge (default centre -6, size 28).
C.Set("target", "portraitMode", "OFF")
p = { text:GetPoint(1) }
H.check("word left of the badge", p[4], -6 - 14 - 2)
H.check("word still above", p[5], ns.Border.Extent("target") + ns.Pixel.One())
-- A badge moved off the corner leaves the word there.
C.Set("target", "classIconX", 40)
H.check("badge away: word at the corner", select(4, text:GetPoint(1)), 0)
C.Set("target", "classIconX", -6)
-- Without a title row there is no badge.
C.Set("target", "titlePercent", 0)
H.check("no title row: no badge", f.classIcon:IsShown(), false)
H.check("no badge: word at the corner", select(4, text:GetPoint(1)), 0)
C.Set("target", "titlePercent", 30)

M.units.target = { name = "Ogre", health = 1, healthMax = 1, classification = "elite" }
M.FireEvent("PLAYER_TARGET_CHANGED")
C.Set("target", "portraitMode", "RIGHT")

-- Test mode: a sample rare elite marker where markers apply.
ns.TestMode.Set(true)
H.check("sample on target", icon._atlas, "nameplates-icon-elite-silver")
H.checkTrue("sample on focus (word)", ns.Frames.focus.eliteText:IsShown())
H.check("sample word", ns.Frames.focus.eliteText:GetText(), L.CLASS_rareelite)
H.checkTrue("sample on the pretend party", ns.Party.fakes[1].eliteText:IsShown())
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "player")
H.checkTrue("sample kept", ns.Frames.focus.eliteText:IsShown())
C.Set("focus", "fontSize", 14)
H.checkTrue("sample kept through a restyle", ns.Frames.focus.eliteText:IsShown())
ns.TestMode.Set(false)
H.check("target: real marker back", icon._atlas, "nameplates-icon-elite-gold")
H.check("focus: nothing", ns.Frames.focus.eliteText:IsShown(), false)
H.check("party: sample gone", ns.Party.fakes[1].eliteText:IsShown(), false)

-- Options: its own section on the frame's Layout tab.
local found
for _, tab in ipairs(ns.Schema.FRAME) do
    for _, sec in ipairs(tab.sections or {}) do
        for _, key in ipairs(sec.keys) do
            if key == "eliteMarker" then found = sec.id end
        end
    end
end
H.check("options section", found, "indicators")
H.check("section title", L.SECTION_indicators, "Indicators")
