local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config

-- "Always show": the castbar stays in the frame as an empty bar while the
-- unit casts nothing, so whatever sits below it keeps its place.
H.checkTrue("always-show applies to target", S.AppliesTo(S.Get("castbarAlwaysShow"), "target"))
H.checkTrue("always-show applies to party", S.AppliesTo(S.Get("castbarAlwaysShow"), "party"))
H.check("not on the pet", S.AppliesTo(S.Get("castbarAlwaysShow"), "pet"), false)
C.Use({})
H.check("off by default", C.Get("target", "castbarAlwaysShow"), false)

ns.Single.CreateAll()
local bar = ns.Frames.target.castbar
M.units.target = { name = "Foe", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("default: hidden while idle", bar:IsShown(), false)

C.Set("target", "castbarAlwaysShow", true)
H.checkTrue("always: shown while idle", bar:IsShown())
H.check("idle: empty fill", bar:GetValue(), 0)
H.check("idle: no name", bar.text:GetText(), "")
H.check("idle: no time", bar.time:GetText(), "")
H.check("idle: no spell icon", bar.icon._texture, nil)
H.checkTrue("icon slot keeps its background", bar.iconBg:IsShown())

-- A cast fills it; its end leaves the empty bar, not a hole.
M.units.target.cast = { name = "Fireball", texture = 135812, startMs = 1000000, endMs = 1002500 }
M.FireEvent("UNIT_SPELLCAST_START", "target", "cast-1", 133)
H.check("cast: name", bar.text:GetText(), "Fireball")
H.check("cast: icon", bar.icon._texture, 135812)
M.units.target.cast = nil
M.FireEvent("UNIT_SPELLCAST_STOP", "target", "cast-1", 133)
H.checkTrue("after the cast: still shown", bar:IsShown())
H.check("after the cast: empty again", bar:GetValue(), 0)
H.check("after the cast: name cleared", bar.text:GetText(), "")
H.check("after the cast: icon cleared", bar.icon._texture, nil)

-- A new target that casts nothing: empty bar.
M.FireEvent("PLAYER_TARGET_CHANGED")
H.checkTrue("new idle target: shown", bar:IsShown())

-- Test mode: sample cast, then back to the empty bar.
ns.Castbar.Preview(ns.Frames.target, true)
H.check("preview: sample name", bar.text:GetText(), ns.L.TEST_CAST)
ns.Castbar.Preview(ns.Frames.target, false)
H.checkTrue("preview off: empty bar", bar:IsShown())
H.check("preview off: name cleared", bar.text:GetText(), "")

-- Icon off: no background slot either.
C.Set("target", "castbarIcon", false)
H.check("no icon: no slot background", bar.iconBg:IsShown(), false)
C.Set("target", "castbarIcon", true)

-- The castbar switched off wins over always-show.
C.Set("target", "castbarEnabled", false)
H.check("disabled: hidden", bar:IsShown(), false)
M.FireEvent("PLAYER_TARGET_CHANGED")
H.check("disabled: stays hidden", bar:IsShown(), false)
C.Set("target", "castbarEnabled", true)
H.checkTrue("enabled again: empty bar", bar:IsShown())

-- Switched back off: idle bar hides.
C.Set("target", "castbarAlwaysShow", false)
H.check("always off: hidden while idle", bar:IsShown(), false)

-- Party members too.
C.Set("party", "castbarAlwaysShow", true)
local header = ns.Party.Create()
M.units.party1 = { name = "Ann", health = 1, healthMax = 1 }
M.SetGroup({ "party1" })
local member = header:GetAttribute("child1")
H.checkTrue("party: empty bar while idle", member.castbar:IsShown())

-- Switched off mid-cast: gone at once, not left on the cast.
M.units.party1.cast = { name = "Renew", startMs = 1002000, endMs = 1020000 }
M.FireEvent("UNIT_SPELLCAST_START", "party1", "r-1", 139)
H.check("party: casting", member.castbar.text:GetText(), "Renew")
C.Set("party", "castbarEnabled", false)
H.check("disabled mid-cast: hidden", member.castbar:IsShown(), false)
