local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local C = ns.Config
local f = ns.Frames.player
M.units.player = { name = "Me", health = 5, healthMax = 10 }

-- Layout maths
H.check("left inset", select(1, ns.Layout.PortraitInsets("LEFT", 40)), 40)
H.check("left: no right inset", select(2, ns.Layout.PortraitInsets("LEFT", 40)), 0)
H.check("right inset", select(2, ns.Layout.PortraitInsets("RIGHT", 40)), 40)
H.check("off: none", select(1, ns.Layout.PortraitInsets("OFF", 40)), 0)

-- Off by default: nothing shown, bars use the full width.
H.check("off: background hidden", f.portraitBg:IsShown(), false)
H.check("off: 2D hidden", f.portrait2D:IsShown(), false)
H.check("off: 3D hidden", f.portrait3D:IsShown(), false)
H.check("off: health from the left edge", select(4, f.health:GetPoint(1)), 0)

-- Left, 2D: a square as tall as the frame; the bars start after it.
C.Set("player", "portraitMode", "LEFT")
H.checkTrue("left: shown", f.portrait2D:IsShown())
H.check("left: 3D hidden", f.portrait3D:IsShown(), false)
H.check("left: square width", f.portraitBg:GetWidth(), 46)
H.check("left: square height", f.portraitBg:GetHeight(), 46)
H.check("left: anchored top left", f.portraitBg:GetPoint(1), "TOPLEFT")
H.check("left: health starts after the portrait", select(4, f.health:GetPoint(1)), 46)
H.check("left: health right edge unchanged", select(4, f.health:GetPoint(2)), 0)
H.check("left: power follows", select(4, f.power:GetPoint(1)), 46)
H.check("left: portrait drawn for the unit", f.portrait2D._portraitUnit, "player")

-- Right: the bars end before it.
C.Set("player", "portraitMode", "RIGHT")
H.check("right: anchored top right", f.portraitBg:GetPoint(1), "TOPRIGHT")
H.check("right: health left edge", select(4, f.health:GetPoint(1)), 0)
H.check("right: health right edge", select(4, f.health:GetPoint(2)), -46)

-- 3D: a model of a visible unit, cleared for one out of sight.
C.Set("player", "portraitStyle", "3D")
H.checkTrue("3D shown", f.portrait3D:IsShown())
H.check("2D hidden", f.portrait2D:IsShown(), false)
H.check("model unit", f.portrait3D._modelUnit, "player")
H.check("model zoom", f.portrait3D._zoom, 1)
M.units.player.visible = false
M.FireEvent("UNIT_MODEL_CHANGED", "player")
H.check("out of sight: model cleared", f.portrait3D._modelUnit, nil)
-- A unit the client refuses (restricted identity) clears too.
M.units.player.visible = true
f.portrait3D._cleared = nil
f.portrait3D.SetUnit = function() error("restricted") end
M.FireEvent("UNIT_PORTRAIT_UPDATE", "player")
H.checkTrue("refused unit: cleared, no error", f.portrait3D._cleared)

-- Timer refreshes (target of target) leave the model alone.
local tot = ns.Frames.targettarget
C.Set("targettarget", "portraitMode", "LEFT")
C.Set("targettarget", "portraitStyle", "3D")
M.units.targettarget = { name = "Tank", health = 1, healthMax = 2 }
M.FireEvent("UNIT_TARGET", "target")
H.check("tot model set on a real change", tot.portrait3D._modelUnit, "targettarget")
tot.portrait3D._modelUnit = "untouched"
M.Tick(0.25)
H.check("poll does not reset the model", tot.portrait3D._modelUnit, "untouched")
H.check("poll still updates health", tot.health:GetValue(), 1)

-- Party buttons get portraits too.
local header = ns.Party.Create()
C.Set("party", "portraitMode", "RIGHT")
M.units.party1 = { name = "Ann", health = 1, healthMax = 2 }
M.SetGroup({ "party1" })
local b = header:GetAttribute("child1")
H.checkTrue("party portrait shown", b.portrait2D:IsShown())
H.check("party portrait unit", b.portrait2D._portraitUnit, "party1")
