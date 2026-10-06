local _, ns = ...

-- What's new: the news of a version, keyed by the version in the TOC
-- (## Version). An entry lists locale keys, one line each, and may name
-- an action for the window's left button. A version without an entry has
-- no news. Options/News.lua shows an entry.
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
