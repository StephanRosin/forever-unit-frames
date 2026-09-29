-- Heals past the frame (healBeyond): the clip reaches one more bar width
-- past the right edge, and the heal bars skip the rounded mask, which
-- would cut off what lies outside the frame.
local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config
C.Use({})
M.units.player = { name = "Me", isPlayer = true, health = 1000, healthMax = 1000 }
ns.Single.CreateAll()
local p = ns.Frames.player
H.check("code", S.Get("healBeyond").code, "OB")
H.check("off by default", C.Get("player", "healBeyond"), false)
C.Set("player", "cornerRadius", 6)
local tex = p.healAll:GetStatusBarTexture()
H.check("off: rounded with the frame", tex.fufMask, p.clip.mask)
local _, _, _, x = p.healClip:GetPoint(2)
H.check("off: cut at the bar's end", x, 0)

C.Set("player", "healBeyond", true)
_, _, _, x = p.healClip:GetPoint(2)
H.check("on: one bar width past the edge", x, p.healthWidth)
H.check("on: no rounded mask (all)", p.healAll:GetStatusBarTexture().fufMask, nil)
H.check("on: no rounded mask (mine)", p.healMine:GetStatusBarTexture().fufMask, nil)
-- A restyle (the rounding is applied again) keeps it off.
C.Set("player", "cornerRadius", 8)
H.check("restyle: still no mask", p.healAll:GetStatusBarTexture().fufMask, nil)

C.Set("player", "healBeyond", false)
H.check("off again: rounded", p.healAll:GetStatusBarTexture().fufMask, p.clip.mask)
_, _, _, x = p.healClip:GetPoint(2)
H.check("off again: cut at the end", x, 0)
