local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local C = ns.Config
local f = ns.Frames.player
M.units.player = { name = "Me", level = 60, class = "WARLOCK", className = "Warlock", isPlayer = true,
    health = 5, healthMax = 10 }
M.atlases["classicon-warlock"] = true

H.check("label", ns.L.ENUM_portraitStyle_CLASS, "Class icon")
C.Set("player", "portraitMode", "LEFT")
C.Set("player", "portraitStyle", "CLASS")
local pic = f.portrait2D
H.checkTrue("shown", pic:IsShown())
H.check("class atlas", pic._atlas, "classicon-warlock")

-- Without the atlas: the class sheet; a restyle keeps its cell.
M.atlases["classicon-warlock"] = nil
M.FireEvent("UNIT_PORTRAIT_UPDATE", "player")
local cell = table.concat(CLASS_ICON_TCOORDS.WARLOCK, ",")
H.check("sheet cell", table.concat(pic._texCoord, ","), cell)
ns.Single.StyleContent(f)
H.check("restyle keeps the cell", table.concat(pic._texCoord, ","), cell)

-- Strip: the icon whole, a square in the middle.
C.Set("player", "portraitMode", "TOP")
C.Set("player", "portraitHeight", 30)
H.check("square in the strip", pic:GetWidth(), 30)
H.check("centred", (pic:GetPoint(1)), "CENTER")
H.check("not cropped", table.concat(pic._texCoord, ","), cell)

-- No class (a creature): the 2D picture, whole.
local t = ns.Frames.target
M.units.target = { name = "Wolf", level = 10, health = 5, healthMax = 10 }
C.Set("target", "portraitMode", "LEFT")
C.Set("target", "portraitStyle", "CLASS")
M.FireEvent("UNIT_PORTRAIT_UPDATE", "target")
H.check("creature: the picture", t.portrait2D._portraitUnit, "target")
H.check("creature: whole", table.concat(t.portrait2D._texCoord, ","), "0,1,0,1")

-- Back to 2D in the strip: cropped again, filling it.
C.Set("player", "portraitStyle", "2D")
H.check("2D: band again", pic._texCoord[3], 0.5 - 30 / ns.Single.Size("player") / 2)
H.check("2D: on the strip again", pic._allPoints, f.portraitBg)
