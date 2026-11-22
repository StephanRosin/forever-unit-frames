-- CurseForge wishes (22.11.2026): the 2D portrait mirrored, a detached
-- castbar's own width, each text moved on its own, buffs and debuffs free
-- on the screen.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local C = ns.Config
local f = ns.Frames.target
M.units.target = { name = "Foe", health = 5, healthMax = 10 }

-- Mirrored portrait: left and right of the picture swapped.
C.Set("target", "portraitMode", "LEFT")
H.check("portrait: as is", f.portrait2D._texCoord[1], 0)
C.Set("target", "portraitMirror", true)
H.check("portrait mirrored: left edge from the right", f.portrait2D._texCoord[1], 1)
H.check("portrait mirrored: right edge from the left", f.portrait2D._texCoord[2], 0)
C.Set("target", "portraitSquare", true)
H.check("mirrored square: inner square, swapped", f.portrait2D._texCoord[1], 1 - ns.Portrait.SQUARE_INSET)

-- Castbar width: only when detached; 0 is the frame's.
local spec = ns.Castbar.MoverSpec(f)
local frameWidth = ns.Pixel.Snap(C.Get("target", "width"))
C.Set("target", "castbarWidth", 300)
H.check("docked: the frame's width", (spec.size()), frameWidth)
C.Set("target", "castbarPosition", "DETACHED")
H.check("detached: its own width", (spec.size()), 300)
C.Set("target", "castbarWidth", 0)
H.check("detached, Auto: the frame's width", (spec.size()), frameWidth)

-- Text offsets: every point of the text moves by them.
local fs = f.texts.healthRight
local _, _, _, x0, y0 = fs:GetPoint(1)
C.Set("target", "textHealthRightX", 7)
C.Set("target", "textHealthRightY", -3)
local _, _, _, x1, y1 = fs:GetPoint(1)
H.check("text moved right", x1 - x0, 7)
H.check("text moved down", y1 - y0, -3)
H.check("other texts stay", f.texts.healthLeft.offsetX, 0)

-- Free auras: on their handle, at the group's own point; party may not.
ns.Auras.AttachMovers(f)
H.checkTrue("not free by default", not ns.Auras.Free(f, "debuffs"))
C.Set("target", "debuffsAnchor", "FREE")
H.checkTrue("free", ns.Auras.Free(f, "debuffs"))
local holder = f.auras.debuffs.holder
H.check("hangs from its handle", ns.Auras.AnchorRegion(f, "debuffs"), holder.mover)
H.check("at its own point", ns.Auras.FramePoint(f, "debuffs"), C.Get("target", "debuffsPoint"))
H.check("no offset", select(2, ns.Auras.AnchorOffset(f, "debuffs", holder.mover)), 0)
local w, h = holder.mover.spec.size()
H.checkTrue("handle as big as the group", w >= f.auras.debuffs.size and h >= f.auras.debuffs.size)
C.Set("target", "debuffsFreeX", 120)
H.check("handle moves with the setting", select(4, holder.mover:GetPoint(1)), ns.Pixel.Centre(120, w))
H.checkTrue("party cannot be free", not ns.Settings.FREE_AURA_SCOPES[ns.Party.KEY])
