local M = H.M
local ns = H.LoadAddon()
local S, L, CF = ns.Settings, ns.L, ns.CombatFeedback

local def = S.Get("combatFeedback")
H.check("code", def.code, "CF")
H.check("per frame", def.scope, "frame")
H.check("on for the player", S.Default(def, "player"), true)
H.check("on for the pet", S.Default(def, "pet"), true)
H.check("off for the target", S.Default(def, "target"), false)
H.check("label", L.SETTING_combatFeedback, "Damage and heal numbers")

_G.ForeverUnitFramesDB = nil
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local C = ns.Config
local f = ns.Frames.player
local holder, text, fade = f.feedback, f.feedbackText, f.feedbackFade
M.units.player = { name = "Me", health = 5, healthMax = 10 }

H.check("on the overlay", holder:GetParent(), f.overlay)
H.checkTrue("above the texts' overlay", holder:GetFrameLevel() > f.overlay:GetFrameLevel())
H.checkTrue("below the class badge", holder:GetFrameLevel() < f.classBadge:GetFrameLevel())
H.check("hidden at rest", holder:IsShown(), false)
H.check("mid health bar", select(2, text:GetPoint(1)), f.health)
H.check("font size", text._font[2], CF.Size("player"))
H.check("size from the frame font", CF.Size("player"), 18)
-- The fade: in, hold, out, Blizzard's timings, ending hidden.
H.check("three steps", #fade._anims, 3)
H.check("fade in", fade._anims[1]._from .. ">" .. fade._anims[1]._to, "0>1")
H.check("fade in time", fade._anims[1]._duration, 0.2)
H.check("hold", fade._anims[2]._duration, 0.7)
H.check("fade out", fade._anims[3]._to, 0)
H.check("fade out time", fade._anims[3]._duration, 0.3)
H.check("in order", fade._anims[3]._order, 3)
H.check("ends at its last alpha", fade._toFinal, true)

-- A secret hit: passed through untouched, red.
local hit = M.Secret(532)
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "", hit, 1)
H.checkTrue("shown", holder:IsShown())
H.checkTrue("fading", fade:IsPlaying())
H.check("format", text._fmt, "%s")
H.check("amount is the secret", text._args[1], hit)
H.check("red", text._color[1] .. "," .. text._color[2], "1,0.25")
M.FinishAnimations()
H.check("gone after the fade", holder:IsShown(), false)

-- A secret critical hit: bigger, still untouched.
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "CRITICAL", hit, 1)
H.check("secret critical: bigger", text._font[2], 27)
H.check("secret critical: amount", text._args[1], hit)
-- Secret flags: a plain hit.
M.FireEvent("UNIT_COMBAT", "player", "WOUND", M.Secret("CRITICAL"), 40, 1)
H.check("secret flags: normal size", text._font[2], 18)
H.check("secret flags: amount", text._args[1], "40")
-- A secret amount with a zero-hit flag cannot be told from a hit.
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "ABSORB", hit, 1)
H.check("secret amount: a number", text._args[1], hit)

-- A readable heal: abbreviated, green; a critical one bigger.
M.FireEvent("UNIT_COMBAT", "player", "HEAL", "CRITICAL", 12345, 2)
H.check("heal text", text._args[1], "12.3k")
H.check("green", text._color[2], 1)
H.check("critical: bigger", text._font[2], 27)
M.FireEvent("UNIT_COMBAT", "player", "HEAL", "", 300, 2)
H.check("normal size again", text._font[2], 18)

-- Words: a dodge; a readable zero hit names its flag, else a miss.
M.FireEvent("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
H.check("dodge", text:GetText(), L.FEEDBACK_DODGE)
H.check("white", text._color[3], 1)
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "ABSORB", 0, 1)
H.check("absorbed", text:GetText(), L.FEEDBACK_ABSORB)
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "", 0, 1)
H.check("missed", text:GetText(), L.FEEDBACK_MISS)
M.FireEvent("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
H.check("parry", text:GetText(), "Parry")
H.checkTrue("every word is translated", L.FEEDBACK_IMMUNE ~= "FEEDBACK_IMMUNE" and L.FEEDBACK_INTERRUPT ~= "FEEDBACK_INTERRUPT")

-- Secret or unknown event kinds show nothing new.
M.FinishAnimations()
M.FireEvent("UNIT_COMBAT", "player", M.Secret("WOUND"), "", 5, 1)
H.check("secret kind: nothing", holder:IsShown(), false)
M.FireEvent("UNIT_COMBAT", "player", "ENERGIZE", "", 5, 1)
H.check("energize: nothing", holder:IsShown(), false)
-- Other refreshes are not feedback.
ns.Single.UpdateAll(f, "PLAYER_ENTERING_WORLD")
H.check("refresh: nothing", holder:IsShown(), false)

-- With a portrait the number sits on it.
C.Set("player", "portraitMode", "LEFT")
H.check("on the portrait", select(2, text:GetPoint(1)), f.portraitBg)
C.Set("player", "portraitMode", "OFF")

-- Off for the target by default; switchable per frame.
M.units.target = { name = "Foe", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
M.FireEvent("UNIT_COMBAT", "target", "WOUND", "", 10, 1)
H.check("target: off", ns.Frames.target.feedback:IsShown(), false)
C.Set("target", "combatFeedback", true)
M.FireEvent("UNIT_COMBAT", "target", "WOUND", "", 10, 1)
H.checkTrue("target: on", ns.Frames.target.feedback:IsShown())
H.check("the player's stays quiet", holder:IsShown(), false)
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "", 10, 1)
C.Set("player", "combatFeedback", false)
H.check("switched off: hidden at once", holder:IsShown(), false)
H.check("switched off: fade stopped", fade:IsPlaying(), false)
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "", 10, 1)
H.check("switched off: nothing", holder:IsShown(), false)
C.Set("player", "combatFeedback", true)
M.FinishAnimations()

-- In combat: plain regions only, allowed.
M.SetCombat(true)
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "", 10, 1)
H.checkTrue("in combat: shown", holder:IsShown())
M.SetCombat(false)
M.FinishAnimations()

-- Test mode: a still sample number where feedback is on.
ns.TestMode.Set(true)
H.checkTrue("sample shown", holder:IsShown())
H.check("sample amount", text._args[1], "1234")
H.check("sample still", fade:IsPlaying(), false)
H.check("sample opaque", holder:GetAlpha(), 1)
M.FireEvent("UNIT_COMBAT", "player", "HEAL", "", 1, 2)
H.check("sample kept", text._args[1], "1234")
H.check("off frames: no sample", ns.Frames.focus.feedback:IsShown(), false)
C.Set("focus", "combatFeedback", true)
H.checkTrue("switched on in test mode: sample", ns.Frames.focus.feedback:IsShown())
C.Set("focus", "combatFeedback", false)
H.check("switched off in test mode: gone", ns.Frames.focus.feedback:IsShown(), false)
ns.TestMode.Set(false)
H.check("sample gone", holder:IsShown(), false)
M.FireEvent("UNIT_COMBAT", "player", "WOUND", "", 10, 1)
H.checkTrue("live again", holder:IsShown())
H.check("live amount", text._args[1], "10")

-- Options: next to the elite marker.
local found
for _, tab in ipairs(ns.Schema.FRAME) do
    for _, sec in ipairs(tab.sections or {}) do
        for _, key in ipairs(sec.keys) do
            if key == "combatFeedback" then found = sec.id end
        end
    end
end
H.check("options section", found, "indicators")
