-- Raid profiles at login (Core/Boot.lua): attached to this character in
-- the account-wide SavedVariables, size known, unit-frame profile untouched.
local M = H.M
local ns = H.LoadAddon()
_G.ForeverUnitFramesDB = { profile = { player = { width = 290 } } }

M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
H.check("no raid profile before login", ns.RaidConfig.Profile(), nil)
M.FireEvent("PLAYER_LOGIN")
H.checkTrue("raid profile in SavedVariables", ForeverUnitFramesDB.raid["Tester-Testrealm"] == ns.RaidConfig.Profile())
H.check("size known", ns.RaidSize.Current(), 10)
H.check("unit frames untouched", ns.Config.Get("player", "width"), 290)

-- A raid change is not a unit-frame change: the unit-frame save is not asked for.
ns.RaidConfig.Set("r20", "x", 33)
M.RunTimers()
H.check("raid value saved", ForeverUnitFramesDB.raid["Tester-Testrealm"].r20.x, 33)
H.check("unit-frame profile still the loaded one", ForeverUnitFramesDB.profile.player.width, 290)

-- Next session: the raid profile comes back.
local saved = ForeverUnitFramesDB
ns = H.LoadAddon()
_G.ForeverUnitFramesDB = saved
M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
M.FireEvent("PLAYER_LOGIN")
H.check("raid value back", ns.RaidConfig.Get("r20", "x"), 33)
