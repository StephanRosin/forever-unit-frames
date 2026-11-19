-- A theme that is gone (Azeroth, removed with LibForeverThemes 13) still in
-- the saved data with its look live: the unit frames load in Classic with
-- the stored Classic set, the gone theme's set is dropped; the raid cells
-- follow the unit frames; the other themes still switch. A second profile
-- on it does the same when loaded.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "Priest", isPlayer = true, auras = {} }
local function onAzeroth() return { general = { theme = "AZEROTH", fontFace = "Alegreya" }, player = { width = 250 } } end
local classic = { general = { fontFace = "Friz Quadrata" }, player = { width = 300 } }
_G.ForeverUnitFramesDB = {
    profiles = { Default = onAzeroth(), Other = onAzeroth() },
    themeSets = { Default = { CLASSIC = classic, AZEROTH = onAzeroth() },
        Other = { CLASSIC = { player = { width = 280 } } } },
    themeColors = { AZEROTH = "PARCHMENT" },
    raid = { ["Me-" .. M.realm] = { general = { cellTheme = "AZEROTH" } } },
}
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local Themes, Config, db = ns.Themes, ns.Config, ForeverUnitFramesDB

H.check("saved azeroth: classic", Themes.Current(), "CLASSIC")
H.check("saved azeroth: the classic set back", Config.Get("player", "width") .. " " .. Config.Get("general", "fontFace"),
    "300 Friz Quadrata")
H.check("saved azeroth: no sets left behind", tostring(db.themeSets.Default.CLASSIC) .. tostring(db.themeSets.Default.AZEROTH),
    "nilnil")
H.check("saved azeroth: raid cells follow the unit frames", ns.RaidConfig.Get("general", "cellTheme"), "UNITS")
H.checkTrue("another profile on it", ns.UnitProfiles.Switch("Other"))
H.check("another profile: its classic set", Themes.Current() .. " " .. Config.Get("player", "width"), "CLASSIC 280")
H.checkTrue("goblin still switches", Themes.Switch("GOBLIN"))
H.check("no error", #M.errors, 0)
