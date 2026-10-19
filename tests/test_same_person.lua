-- The group headers set every button's unit on each roster update; a
-- button that keeps its unit and its person is not drawn anew
-- (ns.Units.SamePerson, Raid/Cell.lua, Units/Party.lua).
local M = H.M
local ns = H.LoadAddon()
M.units.raid1 = { name = "Ann", guid = "Player-1-0001", health = 1, healthMax = 1 }
local updates = 0
local real = ns.Single.UpdateAll
ns.Single.UpdateAll = function() updates = updates + 1 end
local button = { unit = "raid1" }
ns.RaidCell.OnUnitChanged(button, "raid1")
H.check("first time: drawn", updates, 1)
ns.RaidCell.OnUnitChanged(button, "raid1")
H.check("same person: not drawn", updates, 1)
M.units.raid1 = { name = "Bob", guid = "Player-1-0002", health = 1, healthMax = 1 }
ns.RaidCell.OnUnitChanged(button, "raid1")
H.check("someone else on raid1: drawn", updates, 2)
M.units.raid1.name = M.Secret("Bob")
ns.RaidCell.OnUnitChanged(button, "raid1")
ns.RaidCell.OnUnitChanged(button, "raid1")
H.check("secret name: always drawn", updates, 4)
ns.Single.UpdateAll = real
H.check("no unit: no person", ns.Units.SamePerson(button, nil), false)
