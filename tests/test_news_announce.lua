-- What's New pops up by itself only for big releases (Core/News.lua: an
-- entry's announce = true). A small release's news shows nothing at login
-- and records nothing, so a later announced version still shows;
-- /fuf news opens it all the same.
local M = H.M
local ns

local function login(db, version, entries)
    ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
    M.addonVersion = version
    _G.ForeverUnitFramesDB = db
    for v, entry in pairs(entries or {}) do ns.News.ENTRIES[v] = entry end
    M.combat = false
    M.LoadingScreenStarts()
    M.FireEvent("PLAYER_LOGIN")
    M.FireEvent("PLAYER_ENTERING_WORLD", true, false)
    M.LoadingScreenEnds()
    M.RunTimers()
    return ns.NewsWindow.IsOpen()
end

-- The shipped entries: the big ones announced, the small ones not.
ns = H.LoadAddon()
for _, v in ipairs({ "0.22.0", "0.23.0", "0.24.0", "0.25.0", "0.26.0" }) do
    H.check(v .. " announced", ns.News.Entry(v).announce, true)
end
for _, v in ipairs({ "0.25.1", "0.27.0" }) do
    H.check(v .. " not announced", ns.News.Entry(v).announce, nil)
end

local SMALL = { ["9.1.0"] = { lines = { "NEWS_0_22_0_RAID" } } }
local BIG = { ["9.1.0"] = { lines = { "NEWS_0_22_0_RAID" } }, ["9.2.0"] = { lines = { "NEWS_0_22_0_RAID" }, announce = true } }

-- An update to a small release: no popup, nothing recorded.
H.check("small: no popup", login({ profile = {}, newsSeen = "9.0.0" }, "9.1.0", SMALL), false)
H.check("small: newsSeen kept", ForeverUnitFramesDB.newsSeen, "9.0.0")
H.check("small: not due", ns.News.Due(), false)
-- /fuf news still shows it.
SlashCmdList.FOREVERUNITFRAMES("news")
H.check("/fuf news opens it", ns.NewsWindow.IsOpen(), true)
H.check("its version", ns.NewsWindow.frame.titleBar.title:GetText(), "What's new in 9.1.0")
-- Then a big release: shown as before.
H.check("big: popup", login({ profile = {}, newsSeen = "9.0.0" }, "9.2.0", BIG), true)
H.check("big: recorded", ForeverUnitFramesDB.newsSeen, "9.2.0")
