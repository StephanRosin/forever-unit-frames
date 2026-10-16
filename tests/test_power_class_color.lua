local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
M.units.player = { name = "Tester", class = "WARLOCK", isPlayer = true, health = 9, healthMax = 10,
    power = 4, powerMax = 5, powerType = 0 }
M.units.target = { name = "Boar", health = 9, healthMax = 10, power = 4, powerMax = 5, powerType = 1 }
ns.Single.CreateAll()
local C = ns.Config
local p, t = ns.Frames.player, ns.Frames.target
M.FireEvent("PLAYER_TARGET_CHANGED")

H.check("by power type by default", p.power._color[3], C.Get("player", "powerColorMana")[3])
C.Set("general", "powerColorMode", "CLASS")
M.FireEvent("UNIT_POWER_FREQUENT", "player")
M.FireEvent("UNIT_POWER_FREQUENT", "target")
H.check("class: a player in their class colour", p.power._color[1], RAID_CLASS_COLORS.WARLOCK.r)
H.check("class: an NPC keeps its power type", t.power._color[1], C.Get("target", "powerColorRage")[1])
M.units.player.dead = true
M.FireEvent("UNIT_POWER_FREQUENT", "player")
H.check("dead stays grey", p.power._color[1], ns.UnitStatus.GREY[1])
