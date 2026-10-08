-- The news of 0.24.0: the three suggestions from a healer. The five-second
-- rule is on by default: its line says so and where to switch it off; the
-- button opens the player frame's Bars tab.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local L, News = ns.L, ns.News

local entry = News.Entry("0.24.0")
H.checkTrue("0.24.0 has news", entry)
H.check("lines", entry and table.concat(entry.lines, ","), "NEWS_0_24_0_FSR,NEWS_0_24_0_GROUP,NEWS_0_24_0_COMBAT")
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    for _, key in ipairs(entry.lines) do
        H.check(code .. " " .. key, type(rawget(ns.Locales[code], key)), "string")
    end
    H.check(code .. " action", type(rawget(ns.Locales[code], entry.action.text)), "string")
end
H.checkTrue("says it is on", L.NEWS_0_24_0_FSR:find("on by default", 1, true))
H.checkTrue("says where to switch it off", L.NEWS_0_24_0_FSR:find(L.SECTION_fiveSecondRule, 1, true))
entry.action.run()
H.check("action: the options", ns.Options.IsOpen(), true)
H.check("action: the player frame", ns.Options.currentScope, "player")
H.check("action: the Bars tab", ns.Options.currentTab, "bars")
