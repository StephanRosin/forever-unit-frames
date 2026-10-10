local _, ns = ...

-- What's new: the news of a version, keyed by the version in the TOC
-- (## Version). An entry lists locale keys, one line each, and may name
-- an action for the window's left button. A version without an entry has
-- no news. Options/News.lua shows an entry; /fuf news shows any.
--
-- Only an entry with announce = true (a big release) shows by itself; a
-- small release's news waits for /fuf news, and its login records
-- nothing, so a later announced version still shows.
--
-- Once per new announced version, after login: a moment after the login loading
-- screen is gone (LOADING_SCREEN_DISABLED, then SHOW_DELAY seconds) and
-- out of combat. Not at PLAYER_LOGIN: UIParent shows again after the
-- loading screen, and its OnShow closes every UISpecialFrames window
-- (Blizzard_UIParent/UIParent.lua "UI.TopLevelParentShown" ->
-- Blizzard_Game/Shared/Game.lua CloseAllWindows), ours included; the
-- delay lets that OnShow run first. If UIParent is still hidden when the
-- delay ran out, the news waits for its next OnShow (once) and the delay
-- again. ForeverUnitFramesDB.newsSeen is the newest
-- version this account has had news for. The news of the TOC version
-- shows when that version has an announced entry and
--   * newsSeen is an older version, or
--   * there is no newsSeen (or none that is a string), but the
--     SavedVariables held a unit-frame profile or raid profiles before
--     this login: an update from a version before the news.
-- A fresh install (neither) shows nothing and records the version at once
-- (News.Begin), so a logout before the deferred check still counts. A
-- login that shows the news records its version as newsSeen once the
-- window is visible (a downgrade
-- shows nothing and keeps the newer one). A version without news shows
-- and records nothing.
local News = {}
ns.News = News

News.ENTRIES = {
    ["0.22.0"] = {
        announce = true,
        lines = { "NEWS_0_22_0_RAID", "NEWS_0_22_0_BLOCKS", "NEWS_0_22_0_PROFILES", "NEWS_0_22_0_TEMPLATES",
            "NEWS_0_22_0_PANELS", "NEWS_0_22_0_OWN", "NEWS_0_22_0_DEBUFFS", "NEWS_0_22_0_ICONS",
            "NEWS_0_22_0_CLICK", "NEWS_0_22_0_BUFFS", "NEWS_0_22_0_WINDOW", "NEWS_0_22_0_BLIZZARD",
            "NEWS_0_22_0_UNITS", "NEWS_0_22_0_MENUS", "NEWS_0_22_0_RAID_OFF",
            "NEWS_0_22_0_LOOK" },
        action = { text = "NEWS_OPEN_RAID", run = function() ns.RaidOptions.Open() end },
    },
    -- The account's list of hidden auras is on General > Appearance.
    ["0.23.0"] = {
        announce = true,
        lines = { "NEWS_0_23_0_HIDDEN", "NEWS_0_23_0_ADD", "NEWS_0_23_0_CLICK", "NEWS_0_23_0_OWN",
            "NEWS_0_23_0_ELITE", "NEWS_0_23_0_TOOLS", "NEWS_0_23_0_LOOK" },
        action = { text = "NEWS_OPEN_HIDDEN", run = function() ns.Options.Open("general", "appearance") end },
    },
    -- The five-second rule is on by default: its button opens where it is
    -- switched off (the player frame's Bars tab).
    ["0.24.0"] = {
        announce = true,
        lines = { "NEWS_0_24_0_FSR", "NEWS_0_24_0_GROUP", "NEWS_0_24_0_COMBAT" },
        action = { text = "NEWS_OPEN_FSR", run = function() ns.Options.Open("player", "bars") end },
    },
    -- The shield watch is off by default: the button opens where it is
    -- switched on (the player frame's Auras tab, section Shields).
    ["0.25.0"] = {
        announce = true,
        lines = { "NEWS_0_25_0_SHIELDS", "NEWS_0_25_0_SHIELDS_MORE" },
        action = { text = "NEWS_OPEN_SHIELDS", run = function() ns.Options.Open("player", "auras") end },
    },
    ["0.25.1"] = {
        lines = { "NEWS_0_25_1_COMBAT_JOIN", "NEWS_0_25_1_SHIELDS_PLACE" },
    },
    ["0.26.0"] = {
        announce = true,
        lines = { "NEWS_0_26_0_NAMES", "NEWS_0_26_0_SWITCH", "NEWS_0_26_0_EXPIRING" },
        action = { text = "NEWS_OPEN_RAID", run = function() ns.RaidOptions.Open() end },
    },
    -- Click-casting's spell and rank dropdowns: the button opens its tab.
    ["0.27.0"] = {
        lines = { "NEWS_0_27_0_SPELLS", "NEWS_0_27_0_UNIT_TAB" },
        action = { text = "NEWS_OPEN_RAID", run = function() ns.RaidOptions.Open(nil, "clickCast") end },
    },
    -- The debuff-coloured cell border and the power strip's height: the
    -- button opens the Debuffs tab.
    ["0.28.0"] = {
        lines = { "NEWS_0_28_0_DISPEL_BORDER", "NEWS_0_28_0_POWER_HEIGHT" },
        action = { text = "NEWS_OPEN_RAID", run = function() ns.RaidOptions.Open(nil, "debuffs") end },
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

-- Whether this login shows the news of the TOC version (see above): an
-- announced entry only.
function News.Due()
    local current = News.Current()
    local entry = News.Entry(current)
    if not (entry and entry.announce) then return false end
    local seen = seenVersion()
    if seen then return News.Compare(seen, current) < 0 end
    return hadSettings
end

local function later() C_Timer.After(SHOW_DELAY, function() ns.AfterCombat("news", News.AtLogin) end) end

-- UIParent's next OnShow, once (a hooked script stays: a flag turns it
-- off).
local hooked, waitingForUIParent = false, false
local function afterUIParentShows()
    waitingForUIParent = true
    if hooked then return end
    hooked = true
    UIParent:HookScript("OnShow", function()
        if not waitingForUIParent then return end
        waitingForUIParent = false
        later()
    end)
end

-- Out of combat, after the loading screen: shows the news if due and
-- records the version once the window is visible. With UIParent hidden
-- it would not be (and its OnShow would close it): it waits for it.
function News.AtLogin()
    if not News.Due() then return end
    if not UIParent:IsShown() then return afterUIParentShows() end
    local current = News.Current()
    -- Opened but not visible with UIParent shown (not expected): nothing
    -- is recorded and nothing waits; the news shows at the next login.
    -- Safe by design: never recorded unseen.
    if ns.NewsWindow.Open(current) and ns.NewsWindow.frame:IsVisible() then db.newsSeen = current end
end

-- The first loading screen after login only; later ones (zone changes)
-- show nothing.
ns.On("LOADING_SCREEN_DISABLED", function()
    if not waiting then return end
    waiting = false
    later()
end)
