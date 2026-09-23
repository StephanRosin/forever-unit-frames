local M = H.M
local ns = H.LoadAddon()
ns.Config.Use({})
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10 }
ns.Single.CreateAll()
local t = ns.Frames.target
local p = ns.Frames.player

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
H.checkTrue("player watch restored", p._unitWatch)
H.check("player unit still player", p.unit, "player")

-- A real unit is ignored: test mode always forces "player", so clearing the
-- unit later cannot leave stale data behind (the unit watch stays off for
-- as long as test mode owns the frame).
M.units.target = { name = "Foe", level = 60, health = 3, healthMax = 10 }
ns.TestMode.Set(true)
H.check("real target ignored, forced to player", t:GetAttribute("unit"), "player")
H.check("real target unit field forced to player", t.unit, "player")
ns.TestMode.Set(false)
H.check("exact unit restored regardless", t:GetAttribute("unit"), "target")
M.units.target = nil

-- A disabled frame is never shown by test mode.
ns.Config.Set("target", "enabled", false)
H.checkTrue("test mode on with a disabled frame", ns.TestMode.Set(true))
H.check("disabled frame not shown by test mode", t:IsShown(), false)
ns.TestMode.Set(false)
ns.Config.Set("target", "enabled", true)

-- Disabling a frame while test mode is already on releases it at once:
-- hidden immediately, and the exact unit/attribute stay restored even
-- after test mode later ends for the remaining frames.
ns.TestMode.Set(true)
ns.Config.Set("target", "enabled", false)
H.check("disabled during test mode: hidden at once", t:IsShown(), false)
H.check("disabled during test mode: watch stays off", t._unitWatch, nil)
H.check("disabled during test mode: unit restored at once", t:GetAttribute("unit"), "target")
H.check("disabled during test mode: unit field restored", t.unit, "target")
ns.TestMode.Set(false)
H.check("still hidden after test mode ends", t:IsShown(), false)
H.check("still correct unit after test mode ends", t:GetAttribute("unit"), "target")
ns.Config.Set("target", "enabled", true)

-- Enabling a frame while test mode is already on takes it over at once,
-- and it is restored like any other frame when test mode ends.
ns.Config.Set("target", "enabled", false)
ns.TestMode.Set(true)
H.check("still disabled: not taken over yet", t:IsShown(), false)
ns.Config.Set("target", "enabled", true)
H.checkTrue("enabled during test mode: shown", t:IsShown())
H.check("enabled during test mode: player data", t:GetAttribute("unit"), "player")
H.check("enabled during test mode: unit field", t.unit, "player")
H.check("enabled during test mode: no watch", t._unitWatch, nil)
ns.TestMode.Set(false)
H.check("restored on off after being enabled mid-test", t:GetAttribute("unit"), "target")
H.check("restored unit field after being enabled mid-test", t.unit, "target")
H.checkTrue("watch restored after being enabled mid-test", t._unitWatch)

-- The test-mode re-apply must run after every restyle queued in combat,
-- not just the first one: two scopes changing must not leave one of them
-- re-registered.
ns.TestMode.Set(true)
M.combat = true
ns.Config.Set("target", "width", 320)
ns.Config.Set("player", "width", 260)
M.SetCombat(false)
H.check("target still owned by test mode after two queued restyles", t._unitWatch, nil)
H.check("player still owned by test mode after two queued restyles", p._unitWatch, nil)
H.checkTrue("target still shown", t:IsShown())
H.checkTrue("player still shown", p:IsShown())
H.check("target attribute still player", t:GetAttribute("unit"), "player")
H.check("player attribute still player", p:GetAttribute("unit"), "player")
ns.TestMode.Set(false)

ns.TestMode.Set(true)
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat ends test mode", ns.TestMode.IsOn(), false)
M.combat = true
H.check("no test mode in combat", ns.TestMode.Set(true), false)
M.combat = false
