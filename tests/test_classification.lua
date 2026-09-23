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
-- Its own layer: above aura icons that overlap the frame's top (their
-- holders at + Auras.LEVELS, a button's count cover the highest), below
-- the class badge.
local layer = f.eliteLayer
H.check("icon on the marker layer", icon:GetParent(), layer)
H.check("word on the marker layer", text:GetParent(), layer)
H.check("layer covers the frame", layer._allPoints, f)
H.check("layer level", layer:GetFrameLevel(), f:GetFrameLevel() + Cl.LEVELS)
local probe = CreateFrame("Frame", nil, f)
probe:SetFrameLevel(f:GetFrameLevel() + ns.Auras.LEVELS)
local auraButton = ns.AuraButton.Create(probe, false)
H.checkTrue("above an aura icon", layer:GetFrameLevel() > auraButton.cover:GetFrameLevel())
H.checkTrue("above the texts' overlay", layer:GetFrameLevel() > f.overlay:GetFrameLevel())
H.checkTrue("below the class badge", layer:GetFrameLevel() < f.classBadge:GetFrameLevel())

-- What a unit is.
local function kindOf(fields)
    M.units.target = fields
    return Cl.Kind("target")
end
H.check("elite", kindOf({ classification = "elite" }), "elite")
H.check("rare", kindOf({ classification = "rare" }), "rare")
H.check("rare elite", kindOf({ classification = "rareelite" }), "rareelite")
H.check("world boss", kindOf({ classification = "worldboss" }), "boss")
H.check("boss: its own badge", Cl.MARKERS.boss.atlas, "UI-HUD-UnitFrame-Target-HighLevelTarget_Icon")
H.check("boss: the elite badge if missing", Cl.MARKERS.boss.fallback, "nameplates-icon-elite-gold")
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
H.check("on the frame", p[2], f)
H.check("no badge: at the corner", p[4], 0)
H.check("clear of the border", p[5], ns.Border.Extent("target") + ns.Pixel.One())
H.checkTrue("font set", text._font)
H.check("no shadow by default", text._shadow[1], 0)
C.Set("target", "fontShadow", true)
H.check("font shadow", text._shadow[1] .. "," .. text._shadow[2], "1,-1")
C.Set("target", "fontShadow", false)

-- A castbar docked on top: the word goes above it (frame coordinates).
C.Set("target", "castbarPosition", "ABOVE")
local reach = ns.Castbar.Height("target")
p = { text:GetPoint(1) }
H.check("castbar above: on the frame", p[2], f)
H.check("castbar above: above the castbar", p[5], reach + ns.Border.Extent("target") + ns.Pixel.One())
C.Set("target", "castbarPosition", "BELOW")
H.check("castbar below: at the frame", select(5, text:GetPoint(1)), ns.Border.Extent("target") + ns.Pixel.One())

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
M.units.target.classification = "worldboss"
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.check("boss badge", icon._atlas, "UI-HUD-UnitFrame-Target-HighLevelTarget_Icon")
M.units.target.classification = "elite"
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.check("elite badge", icon._atlas, "nameplates-icon-elite-gold")
H.check("sticks out above", select(5, icon:GetPoint(1)), ns.Pixel.Snap(ns.Pixel.Snap(46 * 0.45) / 3))
-- A castbar docked on top: the badge stays below its top edge.
C.Set("target", "castbarPosition", "ABOVE")
H.check("castbar above: not up into it", select(5, icon:GetPoint(1)), 0)
H.checkTrue("castbar above: still out to the side", select(4, icon:GetPoint(1)) > 0)
C.Set("target", "castbarPosition", "BELOW")

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

-- Target of target: refreshed by a timer. An unchanged marker is not
-- drawn again, the atlas lookup is made once per atlas.
local tot = ns.Frames.targettarget
C.Set("targettarget", "portraitMode", "LEFT")
M.units.targettarget = { name = "Add", health = 1, healthMax = 1, classification = "elite" }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("tot badge", tot.eliteIcon._atlas, "nameplates-icon-elite-gold")
local lookups, draws = 0, 0
local lookup = C_Texture.GetAtlasInfo
C_Texture.GetAtlasInfo = function(...) lookups = lookups + 1; return lookup(...) end
local setAtlas = tot.eliteIcon.SetAtlas
tot.eliteIcon.SetAtlas = function(...) draws = draws + 1; return setAtlas(...) end
for _ = 1, 5 do M.Tick(0.25) end
H.check("polls: no lookups", lookups, 0)
H.check("polls: not redrawn", draws, 0)
M.units.targettarget.classification = "rareelite"
M.Tick(0.25)
H.check("poll: a change is drawn", tot.eliteIcon._atlas, "nameplates-icon-elite-silver")
C_Texture.GetAtlasInfo = lookup
C.Set("targettarget", "portraitMode", "OFF")

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

-- Atlases the client does not know (fresh load: lookups are cached).
ns = H.LoadAddon()
M.atlases["nameplates-icon-elite-gold"] = nil
M.atlases["UI-HUD-UnitFrame-Target-HighLevelTarget_Icon"] = nil
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
f = ns.Frames.target
ns.Config.Set("target", "portraitMode", "LEFT")
M.units.target = { name = "Ogre", health = 1, healthMax = 1, classification = "elite" }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("no atlas: no badge", f.eliteIcon:IsShown(), false)
H.checkTrue("no atlas: the word", f.eliteText:IsShown())
H.check("no atlas: word text", f.eliteText:GetText(), ns.L.CLASS_elite)
M.units.target.classification = "rare"
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.checkTrue("known atlas: badge", f.eliteIcon:IsShown())
M.atlases["nameplates-icon-elite-gold"] = true
ns = H.LoadAddon()
M.atlases["UI-HUD-UnitFrame-Target-HighLevelTarget_Icon"] = nil
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
f = ns.Frames.target
ns.Config.Set("target", "portraitMode", "LEFT")
M.units.target = { name = "Ogre", health = 1, healthMax = 1, classification = "worldboss" }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("no boss atlas: the elite badge", f.eliteIcon._atlas, "nameplates-icon-elite-gold")
H.checkTrue("no boss atlas: shown", f.eliteIcon:IsShown())

-- The shipped look: target 70 high, portrait left, buffs just above the
-- frame's top left. The badge draws over them.
ns = H.LoadShipped()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
f = ns.Frames.target
M.units.target = { name = "Ogre", health = 1, healthMax = 1, classification = "elite" }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("shipped: badge shown", f.eliteIcon:IsShown())
H.check("shipped: outer corner", f.eliteIcon:GetPoint(1), "TOPLEFT")
local buffLevel = f:GetFrameLevel() + ns.Auras.LEVELS
H.checkTrue("shipped: above the buffs", f.eliteLayer:GetFrameLevel() > buffLevel + 3)
