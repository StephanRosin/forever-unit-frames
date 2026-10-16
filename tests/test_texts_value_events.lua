-- Health and power ticks set only that bar's value texts; the rest (title,
-- class icon, badge) waits for a full refresh. A changed status word
-- (dead) still redraws everything.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
M.units.player = { name = "Tester", level = 60, class = "WARLOCK", className = "Warlock", isPlayer = true,
    health = 900, healthMax = 1000, power = 400, powerMax = 500, powerType = 0 }
ns.Single.CreateAll()
local f = ns.Frames.player
local t = f.texts
local titleSets = 0
local realSet = t.title.SetFormattedText
t.title.SetFormattedText = function(...) titleSets = titleSets + 1; return realSet(...) end
local before = titleSets

M.units.player.power = 300
M.FireEvent("UNIT_POWER_FREQUENT", "player")
H.check("power text follows", t.powerRight._text, "300")
M.units.player.health = 800
M.FireEvent("UNIT_HEALTH", "player")
H.check("health text follows", t.healthLeft._args[1], "800")
H.check("title left alone on ticks", titleSets, before)

M.units.player.dead = true
M.units.player.health = 0
M.FireEvent("UNIT_HEALTH", "player")
H.check("dead: the word replaces the value", t.healthLeft._text, ns.UnitStatus.Word(ns.UnitStatus.Of(f)))
H.checkTrue("dead: full redraw", titleSets > before)
M.units.player.dead = nil
M.units.player.health = 500
M.FireEvent("UNIT_HEALTH", "player")
H.check("alive again: the value back", t.healthLeft._args[1], "500")
