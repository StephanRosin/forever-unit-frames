-- The news of 0.25.1: members who join during combat show their buffs at
-- once.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local News = ns.News

local entry = News.Entry("0.25.1")
H.checkTrue("0.25.1 has news", entry)
H.check("lines", entry and table.concat(entry.lines, ","), "NEWS_0_25_1_COMBAT_JOIN")
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    for _, key in ipairs(entry and entry.lines or {}) do
        H.check(code .. " " .. key, type(rawget(ns.Locales[code], key)), "string")
    end
end
H.check("enUS words", ns.Locales.enUS.NEWS_0_25_1_COMBAT_JOIN,
    "Party/raid members who join during combat show their buffs at once.")
