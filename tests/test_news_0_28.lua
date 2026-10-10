-- The news of 0.28.0 (not announced): the debuff-coloured border (the
-- line names the Debuffs tab and the row) and the power strip's height
-- (the Cell tab and the row); the button opens the raid window.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local News = ns.News

local entry = News.Entry("0.28.0")
H.checkTrue("0.28.0 has news", entry)
H.check("lines", entry and table.concat(entry.lines, ","), "NEWS_0_28_0_DISPEL_BORDER,NEWS_0_28_0_POWER_HEIGHT")
H.check("not announced", entry and entry.announce, nil)
H.check("its button", entry and entry.action and entry.action.text, "NEWS_OPEN_RAID")
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    local LC = ns.Locales[code]
    local border = rawget(LC, "NEWS_0_28_0_DISPEL_BORDER")
    H.check(code .. " has the border line", type(border), "string")
    H.checkTrue(code .. " names the Debuffs tab", (border or ""):find(LC.RAID_TAB_debuffs, 1, true))
    H.checkTrue(code .. " names the border row", (border or ""):find(LC.RAID_SETTING_dispelBorder, 1, true))
    local power = rawget(LC, "NEWS_0_28_0_POWER_HEIGHT")
    H.check(code .. " has the power line", type(power), "string")
    H.checkTrue(code .. " names the Cell tab", (power or ""):find(LC.RAID_TAB_cell, 1, true))
end
if entry and entry.action then entry.action.run() end
H.check("the button opens the debuffs tab", ns.RaidOptions.currentTab, "debuffs")
