-- What's New at login (Core/News.lua, Core/Boot.lua): once per new
-- version, only after an update (SavedVariables with a unit-frame or raid
-- profile from before), never in combat; a fresh install only records
-- the version. ForeverUnitFramesDB.newsSeen holds the version recorded.
-- The window opens a moment after the login loading screen is gone:
-- UIParent showing again after it closes every UISpecialFrames window
-- (CloseAllWindows), so a window opened at PLAYER_LOGIN never stays.
local M = H.M
local ns

-- A login with these SavedVariables at this TOC version; extra news
-- entries are added before PLAYER_LOGIN.
local function login(db, version, opts)
    opts = opts or {}
    ns = H.LoadAddon()
    M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
    M.addonVersion = version
    _G.ForeverUnitFramesDB = db
    for v, entry in pairs(opts.entries or {}) do ns.News.ENTRIES[v] = entry end
    M.combat = opts.combat or false
    M.LoadingScreenStarts()
    M.FireEvent("PLAYER_LOGIN")
    M.FireEvent("PLAYER_ENTERING_WORLD", true, false)
    M.LoadingScreenEnds()
    M.RunTimers()
    return ns.NewsWindow.IsOpen()
end
local function logout() M.FireEvent("PLAYER_LOGOUT") end
local NEWER = { ["0.23.0"] = { lines = { "NEWS_0_22_0_RAID" } } }

-- Versions compare number by number.
ns = H.LoadAddon()
H.check("older", ns.News.Compare("0.21.0", "0.22.0"), -1)
H.check("same", ns.News.Compare("0.22.0", "0.22.0"), 0)
H.check("newer", ns.News.Compare("0.22.1", "0.22.0"), 1)
H.check("numbers, not letters", ns.News.Compare("0.10.0", "0.9.0"), 1)
H.check("a missing number is 0", ns.News.Compare("1.0", "1.0.0"), 0)

-- A fresh install: nothing shown, the version recorded.
H.check("fresh install: not shown", login(nil, "0.22.0"), false)
H.check("fresh install: no window built", ns.NewsWindow.frame, nil)
H.check("fresh install: recorded", ForeverUnitFramesDB.newsSeen, "0.22.0")
logout()
local db = ForeverUnitFramesDB
H.checkTrue("its profile saved at logout", type(db.profile) == "table")
H.check("next login, same version: not shown", login(db, "0.22.0"), false)
H.check("still recorded", ForeverUnitFramesDB.newsSeen, "0.22.0")
logout()
H.check("a newer version with news: shown", login(db, "0.23.0", { entries = NEWER }), true)
H.check("of that version", ns.NewsWindow.frame.titleBar.title:GetText(), "What's new in 0.23.0")
H.check("the newer one recorded", ForeverUnitFramesDB.newsSeen, "0.23.0")

-- An update from 0.21.0: a unit-frame profile, no newsSeen.
local old = { version = 1, profile = { player = { width = 250 } } }
H.check("update from 0.21.0: shown", login(old, "0.22.0"), true)
H.check("the news of 0.22.0", ns.NewsWindow.frame.titleBar.title:GetText(), "What's new in 0.22.0")
H.check("recorded", ForeverUnitFramesDB.newsSeen, "0.22.0")
H.check("the profile kept", ForeverUnitFramesDB.profile.player.width, 250)
logout()
H.check("same version again: not shown", login(old, "0.22.0"), false)
logout()
H.check("newer version later: shown", login(old, "0.23.0", { entries = NEWER }), true)
H.check("recorded again", ForeverUnitFramesDB.newsSeen, "0.23.0")
logout()

-- Raid profiles alone count as an update too.
H.check("raid profiles only: shown", login({ raid = { ["Other-Realm"] = { r10 = {} } } }, "0.22.0"), true)

-- A newer version without news: nothing shown, nothing recorded.
H.check("no news for 0.22.1: not shown", login({ profile = {}, newsSeen = "0.22.0" }, "0.22.1"), false)
H.check("no news: newsSeen kept", ForeverUnitFramesDB.newsSeen, "0.22.0")
H.check("no news: no window built", ns.NewsWindow.frame, nil)

-- An older version than the one recorded (a downgrade): not shown, kept.
H.check("downgrade: not shown", login({ profile = {}, newsSeen = "0.23.0" }, "0.22.0"), false)
H.check("downgrade: newsSeen kept", ForeverUnitFramesDB.newsSeen, "0.23.0")

-- A newsSeen that is no version string counts as none.
H.check("unreadable newsSeen: shown", login({ profile = {}, newsSeen = 5 }, "0.22.0"), true)
H.check("unreadable newsSeen: replaced", ForeverUnitFramesDB.newsSeen, "0.22.0")

-- Logging in in combat: after combat, after the frames.
local chatBefore
H.check("combat: not shown", login({ profile = {} }, "0.22.0", { combat = true }), false)
H.check("combat: not yet recorded", ForeverUnitFramesDB.newsSeen, nil)
chatBefore = #M.chat
M.SetCombat(false)
H.checkTrue("after combat: shown", ns.NewsWindow.IsOpen())
H.check("after combat: recorded", ForeverUnitFramesDB.newsSeen, "0.22.0")
H.checkTrue("the unit frames built", ns.Frames.player)
H.checkTrue("the raid panel built", ns.RaidHeader.anchor)
H.check("nothing printed", #M.chat, chatBefore)
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)

-- A fresh install that logs in in combat and logs out before combat ends:
-- the version is recorded at login already, so the next login shows
-- nothing either.
H.check("fresh install in combat: not shown", login(nil, "0.22.0", { combat = true }), false)
H.check("fresh install in combat: recorded at once", ForeverUnitFramesDB.newsSeen, "0.22.0")
logout()
local fresh = ForeverUnitFramesDB
H.check("next login: not shown", login(fresh, "0.22.0"), false)
H.check("next login: still recorded", ForeverUnitFramesDB.newsSeen, "0.22.0")

-- The bug of 0.22.0: opened at PLAYER_LOGIN, the window was closed again
-- when UIParent showed after the loading screen. Now it waits for the
-- loading screen to end and a moment more.
ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.addonVersion = "0.22.0"
_G.ForeverUnitFramesDB = { profile = {} }
M.LoadingScreenStarts()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
H.check("loading screen up: not shown yet", ns.NewsWindow.IsOpen(), false)
H.check("loading screen up: not recorded yet", ForeverUnitFramesDB.newsSeen, nil)
M.LoadingScreenEnds()
H.check("loading screen gone: not before the delay", ns.NewsWindow.IsOpen(), false)
H.check("not recorded before it opens", ForeverUnitFramesDB.newsSeen, nil)
M.RunTimers()
H.checkTrue("after the delay: shown", ns.NewsWindow.IsOpen())
H.checkTrue("and visible", ns.NewsWindow.frame:IsVisible())
H.check("recorded once shown", ForeverUnitFramesDB.newsSeen, "0.22.0")
-- A later loading screen (a zone change) does not open it again.
ns.NewsWindow.Close()
M.LoadingScreenStarts()
M.LoadingScreenEnds()
M.RunTimers()
H.check("zone change: not shown again", ns.NewsWindow.IsOpen(), false)
-- UIParent hidden and shown (Alt+Z) closes it, like Blizzard's windows.
ns.NewsWindow.Open("0.22.0")
UIParent:Hide(); UIParent:Show()
H.check("UIParent shown again: closed like any special frame", ns.NewsWindow.IsOpen(), false)

-- In combat when the loading screen ends: after combat.
ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.addonVersion = "0.22.0"
_G.ForeverUnitFramesDB = { profile = {} }
M.LoadingScreenStarts()
M.FireEvent("PLAYER_LOGIN")
M.LoadingScreenEnds()
M.combat = true
M.RunTimers()
H.check("combat after the loading screen: not shown", ns.NewsWindow.IsOpen(), false)
H.check("combat after the loading screen: not recorded", ForeverUnitFramesDB.newsSeen, nil)
M.SetCombat(false)
H.checkTrue("after combat: shown", ns.NewsWindow.IsOpen())
H.check("after combat: recorded", ForeverUnitFramesDB.newsSeen, "0.22.0")
