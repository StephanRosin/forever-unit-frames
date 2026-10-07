-- The news of 0.23.0: the hidden auras (package B) and the elite marker's
-- size; its button opens the account's list.
local M = H.M
local ns = H.LoadAddon()
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local L, News = ns.L, ns.News

local entry = News.Entry("0.23.0")
H.checkTrue("0.23.0 has news", entry)
H.check("lines", entry and table.concat(entry.lines, ","), "NEWS_0_23_0_HIDDEN,NEWS_0_23_0_ADD,NEWS_0_23_0_ELITE")
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    for _, key in ipairs(entry.lines) do
        H.check(code .. " " .. key, type(rawget(ns.Locales[code], key)), "string")
    end
    H.check(code .. " action", type(rawget(ns.Locales[code], entry.action.text)), "string")
end
entry.action.run()
H.check("action: the options", ns.Options.IsOpen(), true)
H.check("action: General", ns.Options.currentScope, "general")
H.check("action: the tab with the list", ns.Options.currentTab, "appearance")
H.checkTrue("help names the undo", L.HELP:find("/fuf auras undo", 1, true))
