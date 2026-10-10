-- The news of 0.27.0: click-casting picks a spell and its rank from
-- dropdowns (the line names the tab and the kind); the button opens the
-- raid window.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local News = ns.News

local entry = News.Entry("0.27.0")
H.checkTrue("0.27.0 has news", entry)
H.check("lines", entry and table.concat(entry.lines, ","), "NEWS_0_27_0_SPELLS,NEWS_0_27_0_UNIT_TAB")
H.check("its button", entry and entry.action and entry.action.text, "NEWS_OPEN_RAID")
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    local LC = ns.Locales[code]
    local line = rawget(LC, "NEWS_0_27_0_SPELLS") or ""
    H.check(code .. " has the line", type(rawget(LC, "NEWS_0_27_0_SPELLS")), "string")
    H.checkTrue(code .. " names the tab", line:find(LC.RAID_TAB_clickCast, 1, true))
    H.checkTrue(code .. " names the kind", line:find(LC.RAID_CLICK_spell, 1, true))
    H.checkTrue(code .. " names Max", line:find(LC.RAID_CLICK_RANK_MAX, 1, true))
    H.checkTrue(code .. " names Other", line:find(LC.RAID_CLICK_OTHER, 1, true))
    -- The unit frames' window has the editor: the line names where.
    local tab = rawget(LC, "NEWS_0_27_0_UNIT_TAB") or ""
    H.check(code .. " has the tab line", type(rawget(LC, "NEWS_0_27_0_UNIT_TAB")), "string")
    H.checkTrue(code .. " names General", tab:find(LC.GENERAL, 1, true))
    H.checkTrue(code .. " names the tab", tab:find(LC.TAB_clickCast, 1, true))
end
if entry and entry.action then entry.action.run() end
H.check("the button opens the click-casting tab", ns.RaidOptions.currentTab, "clickCast")
