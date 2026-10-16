local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local C = ns.Config
local f = ns.Frames.player
M.units.player = { name = "Me", health = 5, healthMax = 10 }
local w, h = ns.Single.Size("player")

-- Above the health bar: a strip as wide as the frame, the frame grown by it.
C.Set("player", "portraitMode", "TOP")
C.Set("player", "portraitHeight", 30)
H.check("frame grows by the strip", f:GetHeight(), h + 30)
H.check("width unchanged", f:GetWidth(), w)
H.check("strip as wide as the frame", select(4, f.portraitBg:GetPoint(2)), 0)
H.check("strip height", f.portraitBg:GetHeight(), 30)
H.check("strip under the title row", select(5, f.portraitBg:GetPoint(1)), -f.titleHeight)
H.check("health below the strip", select(5, f.health:GetPoint(1)), -(f.titleHeight + 30))
H.check("health from the left edge", select(4, f.health:GetPoint(1)), 0)
H.check("bars keep their height", f.layoutHeight, h)
H.check("2D: the picture's middle band", f.portrait2D._texCoord[3], 0.5 - 30 / w / 2)

-- 3D: zoom and the view's vertical shift.
C.Set("player", "portraitStyle", "3D")
M.FireEvent("UNIT_MODEL_CHANGED", "player")
local model = f.portrait3D
H.check("default zoom: the client's framing", model._camScale, 1)
H.check("default: no shift", model._view and model._view[2], 0)
C.Set("player", "portraitZoom", 200)
C.Set("player", "portraitOffsetY", -12)
H.check("zoomed in", model._camScale, 0.5)
H.check("shifted", model._view[2], -12)
H.check("portrait zoom kept", model._zoom, 1)

-- Back to the side: the strip and its crop go.
C.Set("player", "portraitMode", "LEFT")
H.check("frame back to its height", f:GetHeight(), h)
H.check("full picture again", f.portrait2D._texCoord[3], 0)
H.check("square again", f.portraitBg:GetWidth(), h)
