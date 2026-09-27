-- The party member you have targeted gets a bright band around its frame.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local S, C = ns.Settings, ns.Config

local def = S.Get("targetHighlight")
H.check("code", def.code, "TG")
H.checkTrue("on party", S.AppliesTo(def, "party"))
H.check("not on target", S.AppliesTo(def, "target"), false)
C.Use({})
H.check("on by default", C.Get("party", "targetHighlight"), true)

local header = ns.Party.Create()
M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
M.units.party2 = { name = "Bob", health = 1, healthMax = 1 }
M.SetGroup({ "party1", "party2" })
local a, b = header:GetAttribute("child1"), header:GetAttribute("child2")
H.check("nobody targeted: off", a.targetHighlight.frame:IsShown(), false)

M.units.target = M.units.party2
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("targeted member: shown", b.targetHighlight.frame:IsShown(), true)
H.check("the other: hidden", a.targetHighlight.frame:IsShown(), false)

M.units.target = M.units.party1
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("switch: new one shown", a.targetHighlight.frame:IsShown(), true)
H.check("switch: old one hidden", b.targetHighlight.frame:IsShown(), false)

-- Secret answer: the band's opacity follows it without a comparison.
local isUnit = UnitIsUnit
_G.UnitIsUnit = function(x, y) return M.Secret(isUnit(x, y)) end
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("secret: band shown", a.targetHighlight.frame:IsShown(), true)
H.check("secret: opacity from the answer", a.targetHighlight.frame:GetAlpha(), 1)
H.check("secret: other opacity 0", b.targetHighlight.frame:GetAlpha(), 0)
_G.UnitIsUnit = isUnit

C.Set("party", "targetHighlight", false)
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("off: hidden", a.targetHighlight.frame:IsShown(), false)
C.Set("party", "targetHighlight", true)

-- Above the threat glow.
H.checkTrue("above threat", a.targetHighlight.frame:GetFrameLevel() > a.threat.frame:GetFrameLevel())

-- Test mode: pretend member 1 is targeted.
ns.TestMode.Set(true)
H.check("test: member 1 highlighted", ns.Party.fakes[1].targetHighlight.frame:IsShown(), true)
ns.TestMode.Set(false)

-- Colour: General for every frame, overridable per frame; white by default.
local cdef = S.Get("targetHighlightColor")
H.check("colour code", cdef.code, "TK")
H.check("colour inherited", cdef.scope, "inherit")
H.check("white by default", C.Get("party", "targetHighlightColor")[1], 1)
C.Set("general", "targetHighlightColor", { 1, 0.8, 0, 1 })
M.units.target = M.units.party1
M.FireEvent("PLAYER_TARGET_CHANGED")
local piece = ns.Border.GlowPieces(a.targetHighlight.frame)[1]
H.check("band takes the colour", piece._color[3], 0)
