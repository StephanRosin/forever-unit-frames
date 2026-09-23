local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10 }
ns.Single.CreateAll()
local t = ns.Frames.target

H.checkTrue("target watched before", t._unitWatch)
H.checkTrue("test mode on", ns.TestMode.Set(true))
H.check("target shows player data", t:GetAttribute("unit"), "player")
H.check("target unit field", t.unit, "player")
H.check("watch removed", t._unitWatch, nil)
H.checkTrue("target shown", t:IsShown())
ns.Config.Set("target", "width", 300)
H.check("still in test after restyle", t._unitWatch, nil)
H.checkTrue("still shown after restyle", t:IsShown())
ns.TestMode.Set(false)
H.check("unit restored", t:GetAttribute("unit"), "target")
H.checkTrue("watch restored", t._unitWatch)
H.checkTrue("player watch restored", ns.Frames.player._unitWatch)
H.check("player unit still player", ns.Frames.player.unit, "player")

-- A disabled frame is never shown by test mode.
ns.Config.Set("target", "enabled", false)
H.checkTrue("test mode on with a disabled frame", ns.TestMode.Set(true))
H.check("disabled frame not shown by test mode", t:IsShown(), false)
ns.TestMode.Set(false)
ns.Config.Set("target", "enabled", true)

ns.TestMode.Set(true)
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat ends test mode", ns.TestMode.IsOn(), false)
M.combat = true
H.check("no test mode in combat", ns.TestMode.Set(true), false)
M.combat = false
