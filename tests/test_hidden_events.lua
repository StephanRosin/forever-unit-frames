-- A hidden frame skips its unit events (Units/Events.lua) and catches up
-- when it shows.
local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
ns.Single.CreateAll()
local f = ns.Frames.player
M.units.player = { name = "Me", class = "PRIEST", isPlayer = true, health = 100, healthMax = 100 }
M.FireEvent("UNIT_HEALTH", "player")
H.check("shown: updated", f.health:GetValue(), 100)
f:Hide()
M.units.player.health = 40
M.FireEvent("UNIT_HEALTH", "player")
H.check("hidden: not updated", f.health:GetValue(), 100)
f:Show()
H.check("shown again: caught up", f.health:GetValue(), 40)
