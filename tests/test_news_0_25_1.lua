-- The news of 0.25.1: members who join during combat show their buffs at
-- once; the shield watch can hang from the player frame (its line names
-- the section and the setting).
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local News = ns.News

local entry = News.Entry("0.25.1")
H.checkTrue("0.25.1 has news", entry)
H.check("lines", entry and table.concat(entry.lines, ","), "NEWS_0_25_1_COMBAT_JOIN,NEWS_0_25_1_SHIELDS_PLACE")
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    local LC = ns.Locales[code]
    for _, key in ipairs(entry and entry.lines or {}) do
        H.check(code .. " " .. key, type(rawget(LC, key)), "string")
    end
    local line = rawget(LC, "NEWS_0_25_1_SHIELDS_PLACE") or ""
    -- The section was renamed in 0.40.0 (Shield watch): the old news keep the old name.
    H.checkTrue(code .. " names the setting", line:find(LC.SETTING_shieldsAnchor, 1, true))
end
H.check("enUS words", ns.Locales.enUS.NEWS_0_25_1_COMBAT_JOIN,
    "Party/raid members who join during combat show their buffs at once.")
