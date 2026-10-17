local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local C, S = ns.Config, ns.Settings
local f = ns.Frames.player
M.units.player = { name = "Me", health = 5, healthMax = 10 }
C.Set("player", "castbarEnabled", true)
local bar = f.castbar

H.check("appended (stored by index)", S.Get("castbarPosition").values[4], "PORTRAIT")
H.check("label", ns.L.ENUM_castbarPosition_PORTRAIT, "Over the portrait")
H.check("not on party", S.AppliesTo(S.Get("castbarPosition"), "party"), false)

-- Without a portrait: below the frame.
C.Set("player", "castbarPosition", "PORTRAIT")
H.check("no portrait: below", ns.Castbar.Placement("player"), "BELOW")
H.checkTrue("no portrait: docked", ns.Castbar.Docked("player"))

-- Over the strip: along its bottom, above the 3D model, no room taken.
C.Set("player", "portraitMode", "TOP")
C.Set("player", "portraitHeight", 30)
C.Set("player", "castbarHeight", 16)
C.Set("player", "castbarIcon", false)
H.check("over the portrait", ns.Castbar.Placement("player"), "PORTRAIT")
local point, rel, relPoint = bar:GetPoint(1)
H.check("anchored to the portrait", rel, f.portraitBg)
H.check("along its bottom", point .. relPoint, "BOTTOMLEFTBOTTOMLEFT")
H.check("castbar height", bar:GetHeight(), 16)
H.checkTrue("above the model", bar:GetFrameLevel() > f.portrait3D:GetFrameLevel())
H.check("no docked room", ns.Castbar.DockedDepth("player"), 0)
H.check("no dock side", ns.Shape.DockReach(f), nil)

-- At most as tall as the strip; the icon then as tall as the bar.
C.Set("player", "castbarHeight", 50)
C.Set("player", "castbarIcon", true)
H.check("clamped to the strip", bar:GetHeight(), 30)
H.check("icon as tall", bar.icon:GetHeight(), 30)
H.check("icon inset", select(4, bar:GetPoint(1)), 30)

-- Detached (moved over the portrait by hand): above the model too.
C.Set("player", "castbarPosition", "DETACHED")
H.checkTrue("detached: above the model", bar:GetFrameLevel() > f.portrait3D:GetFrameLevel())
C.Set("player", "castbarPosition", "BELOW")
H.check("below the frame", select(2, bar:GetPoint(1)), f)
