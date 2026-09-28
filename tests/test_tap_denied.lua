-- Tapped by someone else: the health bar turns Blizzard's grey (target,
-- target of target, focus), players never; a secret answer changes nothing.
local M = H.M
local ns = H.LoadAddon()
local S, C = ns.Settings, ns.Config
C.Use({})
M.units.player = { name = "Me", isPlayer = true, health = 1, healthMax = 1 }
M.units.target = { name = "Boar", hostile = true, reaction = 2, health = 5, healthMax = 10 }
ns.Single.CreateAll()
local t = ns.Frames.target
H.check("code", S.Get("tapDenied").code, "TD")
H.check("on by default", C.Get("target", "tapDenied"), true)
H.check("not on the party", S.AppliesTo(S.Get("tapDenied"), "party"), false)
C.Set("target", "healthColorMode", "REACTION")
ns.Single.UpdateAll(t)
local red = t.health._color[1]
M.units.target.tapDenied = true
M.FireEvent("UNIT_FACTION", "target")
H.check("tapped: grey", table.concat({ t.health._color[1], t.health._color[2], t.health._color[3] }, ","), "0.5,0.5,0.5")
M.units.target.tapDenied = false
M.FireEvent("UNIT_FACTION", "target")
H.check("free again: its colour", t.health._color[1], red)
M.units.target.tapDenied = M.Secret(true)
M.FireEvent("UNIT_FACTION", "target")
H.check("secret: unchanged", t.health._color[1], red)
M.units.target = { name = "Rogue", isPlayer = true, health = 5, healthMax = 10, tapDenied = true }
M.FireEvent("PLAYER_TARGET_CHANGED")
ns.Single.UpdateAll(t)
H.checkTrue("players never grey", t.health._color[1] ~= 0.5)
M.units.target = { name = "Boar", hostile = true, reaction = 2, health = 5, healthMax = 10, tapDenied = true }
C.Set("target", "tapDenied", false)
ns.Single.UpdateAll(t)
H.check("switched off: its colour", t.health._color[1], red)
