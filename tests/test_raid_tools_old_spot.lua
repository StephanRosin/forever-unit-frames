-- The tools bar's free spot moved from (300, 300) to (-60, 370) in 0.23.
-- A raid profile of an earlier version stored no axis left at 300 (Config
-- keeps no value equal to the default): such a free bar keeps its old spot
-- once, at the first login with this version. A fresh profile, a docked
-- bar and anything written later take the new default.
local M = H.M
local KEY = "Tester-Testrealm"

local function boot(db)
    local ns = H.LoadAddon()
    _G.ForeverUnitFramesDB = db
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    return ns
end

local function spot(ns)
    return ns.RaidConfig.Get("general", "toolsX") .. "," .. ns.RaidConfig.Get("general", "toolsY")
end

-- Free, only y moved: x was 300 and stays there.
local ns = boot({ raid = { [KEY] = { general = { toolsMode = "FREE", toolsY = 120 } },
    ["Other-Testrealm"] = { general = { toolsMode = "FREE" } } } })
H.check("free, y stored: x keeps 300", spot(ns), "300,120")
H.check("another character's free bar too", ForeverUnitFramesDB.raid["Other-Testrealm"].general.toolsX, 300)
H.check("... both axes", ForeverUnitFramesDB.raid["Other-Testrealm"].general.toolsY, 300)

-- Once only: a later profile without stored axes takes the new default.
local saved = ForeverUnitFramesDB
saved.raid[KEY].general.toolsX, saved.raid[KEY].general.toolsY = nil, nil
ns = boot(saved)
H.check("second login: no second migration", spot(ns), "-60,370")

-- Docked, nothing stored: untouched.
ns = boot({ raid = { [KEY] = { general = { toolsMode = "DOCKED" } } } })
H.check("docked: untouched", ForeverUnitFramesDB.raid[KEY].general.toolsX, nil)
H.check("docked: the new default", spot(ns), "-60,370")
ns = boot({ raid = { [KEY] = { general = {} } } })
H.check("default mode: untouched", ForeverUnitFramesDB.raid[KEY].general.toolsY, nil)

-- A fresh profile: the new default.
ns = boot({})
H.check("fresh profile", spot(ns), "-60,370")
ns.RaidConfig.Set("general", "toolsMode", "FREE")
H.check("fresh, switched to free", spot(ns), "-60,370")
