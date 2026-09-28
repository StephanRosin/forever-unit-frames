-- Reaction colours of one's own, pet aura count, the elite / rare ring and
-- test mode showing every enabled icon on every frame.
local M = H.M
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C = ns.Settings, ns.Config
M.units.player = M.units.player or { name = "Me", class = "PRIEST", isPlayer = true, health = 1, healthMax = 1 }

-- Reaction colours ------------------------------------------------------------------
for key, code in pairs({ reactionFriendlyColor = "RG", reactionNeutralColor = "RN", reactionHostileColor = "RH",
    partyPetAuraMax = "PZ", eliteMarkerStyle = "EZ", eliteBorderSize = "EU" }) do
    H.check("code of " .. key, S.Get(key).code, code)
end
M.units.target = { name = "Guard", health = 5, healthMax = 10, reaction = 5 }
local t = ns.Frames.target
ns.Single.SetUnit(t, "target")
C.Set("target", "healthColorMode", "REACTION")
C.Set("general", "reactionFriendlyColor", { 0.1, 0.2, 0.9, 1 })
ns.Single.UpdateAll(t)
H.check("friendly: own colour", t.health._color[3], 0.9)
M.units.target.reaction = 2
ns.Single.UpdateAll(t)
H.check("hostile: default red", t.health._color[1], C.Get("target", "reactionHostileColor")[1])
C.Set("target", "reactionHostileColor", { 0.5, 0, 0.5, 1 })
ns.Single.UpdateAll(t)
H.check("hostile: overridden per frame", t.health._color[3], 0.5)
-- The title "by reaction" follows too.
C.Set("target", "titleColorMode", "REACTION")
ns.Single.UpdateAll(t)
H.check("title in the own hostile colour", t.texts.title._color[3], 0.5)
-- Without a scope: the built-in colours (other callers).
H.check("no scope: defaults", ns.Health.ReactionColor("target")[1], 0.85)

-- Pet aura count ---------------------------------------------------------------------
local partyMax = C.Get("party", "buffsMax")
H.check("pets: as the party by default", C.Get("partypet", "buffsMax"), partyMax)
C.Set("party", "partyPetAuraMax", 2)
H.check("pets: two buffs", C.Get("partypet", "buffsMax"), 2)
H.check("pets: two debuffs", C.Get("partypet", "debuffsMax"), 2)
H.check("members unchanged", C.Get("party", "buffsMax"), partyMax)

-- Elite / rare ring -------------------------------------------------------------------
M.units.target = { name = "Ogre", health = 5, healthMax = 10, classification = "elite", hostile = true }
ns.Single.SetUnit(t, "target")
C.Set("target", "eliteMarkerStyle", "BORDER")
ns.Single.UpdateAll(t)
H.check("border: no badge", t.eliteIcon:IsShown(), false)
H.check("border: no word", t.eliteText:IsShown(), false)
local pieces = ns.Border.RingPieces(t.eliteRings[1])
H.checkTrue("a ring", #pieces > 0 and pieces[1]:IsShown())
H.check("elite: gold", pieces[1]._color[3], 0)
M.units.target.classification = "rare"
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.checkTrue("rare: silver", ns.Border.RingPieces(t.eliteRings[1])[1]._color[3] > 0.5)
M.units.target.classification = "normal"
M.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
H.check("normal: no ring", ns.Border.RingPieces(t.eliteRings[1])[1]:IsShown(), false)
C.Set("target", "eliteMarkerStyle", "MARKER")

-- Test mode: every enabled icon on every frame -----------------------------------------
for _, scope in ipairs({ "target", "targettarget", "focus" }) do
    C.Set(scope, "pvpIcon", true)
    C.Set(scope, "combatIcon", true)
end
ns.TestMode.Set(true)
for _, scope in ipairs({ "target", "targettarget", "focus" }) do
    local icons = ns.Frames[scope].unitIcons
    H.checkTrue(scope .. ": crest in test mode", icons.pvpIcon.holder:IsShown())
    H.checkTrue(scope .. ": combat icon in test mode", icons.combatIcon.holder:IsShown())
    H.checkTrue(scope .. ": raid marker in test mode", ns.Frames[scope].raidMarker.icon:IsShown())
end
H.checkTrue("player: dispel ring in test mode", ns.Frames.player.dispel.ring:IsShown())
for i = 1, 4 do
    H.checkTrue("pretend member " .. i .. ": raid marker", ns.Party.fakes[i].raidMarker.icon:IsShown())
end
ns.TestMode.Set(false)
