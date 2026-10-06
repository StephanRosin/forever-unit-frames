local _, ns = ...

-- What's new: the news of a version, keyed by the version in the TOC
-- (## Version). An entry lists locale keys, one line each, and may name
-- an action for the window's left button. A version without an entry has
-- no news. Options/News.lua shows an entry.
--
-- Once per new version, after login: a moment after the login loading
-- screen is gone (LOADING_SCREEN_DISABLED, then SHOW_DELAY seconds) and
-- out of combat. Not at PLAYER_LOGIN: UIParent shows again after the
-- loading screen, and its OnShow closes every UISpecialFrames window
-- (Blizzard_UIParent/UIParent.lua "UI.TopLevelParentShown" ->
-- Blizzard_Game/Shared/Game.lua CloseAllWindows), ours included; the
-- delay lets that OnShow run first. ForeverUnitFramesDB.newsSeen is the newest
-- version this account has had news for. The news of the TOC version
-- shows when that version has an entry and
--   * newsSeen is an older version, or
--   * there is no newsSeen (or none that is a string), but the
--     SavedVariables held a unit-frame profile or raid profiles before
--     this login: an update from a version before the news.
-- A fresh install (neither) shows nothing and records the version at once
-- (News.Begin), so a logout before the deferred check still counts. A
-- login that shows the news records its version as newsSeen (a downgrade
-- shows nothing and keeps the newer one). A version without news shows
-- and records nothing.
local News = {}
ns.News = News

News.ENTRIES = {
    ["0.22.0"] = {
        lines = { "NEWS_0_22_0_RAID", "NEWS_0_22_0_BLOCKS", "NEWS_0_22_0_PROFILES", "NEWS_0_22_0_DEBUFFS",
            "NEWS_0_22_0_ICONS", "NEWS_0_22_0_WINDOW", "NEWS_0_22_0_BLIZZARD" },
        action = { text = "NEWS_OPEN_RAID", run = function() ns.RaidOptions.Open() end },
    },
}

-- The version this client loaded (## Version in the TOC).
function News.Current()
    return C_AddOns.GetAddOnMetadata(ns.name, "Version")
end

-- The news of a version, or nil.
function News.Entry(version)
    if type(version) ~= "string" then return nil end
    return News.ENTRIES[version]
end

-- -1, 0 or 1 as version a is older than, the same as or newer than b:
-- numbers compared one by one, a missing number counts as 0.
function News.Compare(a, b)
    local pa, pb = {}, {}
    for n in a:gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
    for n in b:gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

local SHOW_DELAY = 1   -- seconds after the loading screen

local db            -- ForeverUnitFramesDB
local hadSettings   -- it held a profile before this login
local waiting       -- logged in, the loading screen not yet gone

local function seenVersion()
    local seen = db.newsSeen
    if type(seen) == "string" then return seen end
    return nil
end

-- At PLAYER_LOGIN, before anything writes to the SavedVariables. A fresh
-- install records the version here already: News.AtLogin waits for the
-- loading screen and the end of combat, which a logout may come before.
function News.Begin(saved)
    db = saved
    waiting = true
    hadSettings = type(saved.profile) == "table" or type(saved.raid) == "table"
    local current = News.Current()
    if not hadSettings and not seenVersion() and News.Entry(current) then db.newsSeen = current end
end

-- Whether this login shows the news of the TOC version (see above).
function News.Due()
    local current = News.Current()
    if not News.Entry(current) then return false end
    local seen = seenVersion()
    if seen then return News.Compare(seen, current) < 0 end
    return hadSettings
end

-- Out of combat, after the loading screen: shows the news if due and
-- records the version it showed.
function News.AtLogin()
    local current = News.Current()
    if News.Due() and ns.NewsWindow.Open(current) then db.newsSeen = current end
end

-- The first loading screen after login only; later ones (zone changes)
-- show nothing.
ns.On("LOADING_SCREEN_DISABLED", function()
    if not waiting then return end
    waiting = false
    C_Timer.After(SHOW_DELAY, function() ns.AfterCombat("news", News.AtLogin) end)
end)
