-- Up to 0.22 only the docked tools bar folded; a free bar always showed.
-- In 0.23 the free bar obeys toolsOpen (default folded) too, so a free bar
-- of an earlier version is unfolded once, at the first login with this
-- version. A docked bar, a fresh profile and anything written later keep
-- toolsOpen as it is.
local M = H.M
local KEY = "Tester-Testrealm"

local function boot(db)
    local ns = H.LoadAddon()
    _G.ForeverUnitFramesDB = db
    M.FireEvent("ADDON_LOADED", "ForeverUnitFrames")
    M.FireEvent("PLAYER_LOGIN")
    return ns
end

local ns = boot({ raid = { [KEY] = { general = { toolsMode = "FREE" } },
    ["Other-Testrealm"] = { general = { toolsMode = "FREE", toolsOpen = false } },
    ["Docked-Testrealm"] = { general = { toolsMode = "DOCKED" } } } })
H.check("free bar of 0.22: unfolded", ns.RaidConfig.Get("general", "toolsOpen"), true)
H.check("another character's free bar too", ForeverUnitFramesDB.raid["Other-Testrealm"].general.toolsOpen, true)
H.check("docked: untouched", ForeverUnitFramesDB.raid["Docked-Testrealm"].general.toolsOpen, nil)

-- Once only: folded later, it stays folded.
local saved = ForeverUnitFramesDB
saved.raid[KEY].general.toolsOpen = nil
ns = boot(saved)
H.check("second login: no second migration", ns.RaidConfig.Get("general", "toolsOpen"), false)

-- A fresh profile: the default.
ns = boot({})
H.check("fresh profile", ns.RaidConfig.Get("general", "toolsOpen"), false)
