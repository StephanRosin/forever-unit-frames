-- The player frame hidden in a party or raid (playerHideInGroup): the
-- game's visibility driver "[group] hide; show" instead of the unit watch,
-- so it holds in combat too. Off: the unit watch as before. Test mode shows
-- it while on and gives the driver back after.
local M = H.M
local ns = H.LoadAddon()
local C = ns.Config
C.Use({})
M.units.player = { name = "Me", level = 60, health = 5, healthMax = 10 }
M.units.party1 = { name = "Ann", health = 5, healthMax = 10 }
ns.Single.CreateAll()
local p = ns.Frames.player

H.checkTrue("off: unit watch", p._unitWatch)
H.check("off: no driver", M.drivers[p], nil)

C.Set("player", "playerHideInGroup", true)
H.check("on: no unit watch", p._unitWatch, nil)
H.check("on: the group driver", M.drivers[p], "[group] hide; show")
H.checkTrue("on, solo: shown", p:IsShown())
M.SetGroup({ "party1" })
H.check("on, in a party: hidden", p:IsShown(), false)
M.SetGroup({})
H.checkTrue("on, solo again: shown", p:IsShown())
M.SetGroup({ "party1" })

H.checkTrue("test mode on", ns.TestMode.Set(true))
H.checkTrue("test mode: shown in a party", p:IsShown())
H.check("test mode: no driver", M.drivers[p], nil)
ns.TestMode.Set(false)
H.check("test mode off: driver back", M.drivers[p], "[group] hide; show")
H.check("test mode off: hidden again", p:IsShown(), false)

C.Set("player", "playerHideInGroup", false)
H.check("off again: no driver", M.drivers[p], nil)
H.checkTrue("off again: unit watch", p._unitWatch)

-- Other frames never take the driver.
H.check("target: no driver", M.drivers[ns.Frames.target], nil)
H.check("no errors", #M.errors, 0)
