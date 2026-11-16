-- The health bar's empty part (missing health): the background colour,
-- or a colour of its own when switched on (CurseForge wish).
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local C, f = ns.Config, ns.Frames.player

local function color() return table.concat(f.healthBg._color, ",") end
local function of(c) return table.concat(c, ",") end

H.check("off by default", C.Get("player", "healthMissingCustom"), false)
H.check("off: the background colour", color(), of(C.Get("player", "backgroundColor")))
C.Set("player", "healthMissingCustom", true)
H.check("on: its own colour", color(), of(C.Get("player", "healthMissingColor")))
C.Set("player", "healthMissingColor", { 0.1, 0.2, 0.3, 0.4 })
H.check("on: a changed colour", color(), "0.1,0.2,0.3,0.4")
H.check("other frames keep the background", table.concat(ns.Frames.target.healthBg._color, ","),
    of(C.Get("target", "backgroundColor")))
C.Set("player", "healthMissingCustom", false)
H.check("off again: the background colour", color(), of(C.Get("player", "backgroundColor")))
