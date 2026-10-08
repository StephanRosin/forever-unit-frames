-- The news of 0.25.0: the shield watch. It is off by default: its lines
-- say where to switch it on; the button opens the player frame's Auras
-- tab, where its section is.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local L, News = ns.L, ns.News

local entry = News.Entry("0.25.0")
H.checkTrue("0.25.0 has news", entry)
H.check("lines", entry and table.concat(entry.lines, ","), "NEWS_0_25_0_SHIELDS,NEWS_0_25_0_SHIELDS_MORE")
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    for _, key in ipairs(entry and entry.lines or {}) do
        H.check(code .. " " .. key, type(rawget(ns.Locales[code], key)), "string")
    end
    H.check(code .. " action", entry and type(rawget(ns.Locales[code], entry.action.text)), "string")
    H.checkTrue(code .. " names the section",
        (rawget(ns.Locales[code], "NEWS_0_25_0_SHIELDS") or ""):find(ns.Locales[code].SECTION_shields, 1, true))
    H.checkTrue(code .. " names the switch",
        (rawget(ns.Locales[code], "NEWS_0_25_0_SHIELDS") or ""):find(ns.Locales[code].SETTING_shieldsEnabled, 1, true))
end
H.checkTrue("says it is off", (L.NEWS_0_25_0_SHIELDS or ""):find("off by default", 1, true))
entry.action.run()
H.check("action: the options", ns.Options.IsOpen(), true)
H.check("action: the player frame", ns.Options.currentScope, "player")
H.check("action: the Auras tab", ns.Options.currentTab, "auras")

-- The section's spell list: the hidden-auras editor with a note of its own
-- and no marks.
local row
for _, r in ipairs(ns.Options.rows) do
    if r.key == "shieldsExtra" then row = r end
end
H.checkTrue("the additions' row", row)
local editor = row and (row.control or row)
local function find(frame, field, depth)
    if depth > 4 or type(frame) ~= "table" then return nil end
    if rawget(frame, field) then return frame end
    for _, child in ipairs(frame.GetChildren and { frame:GetChildren() } or {}) do
        local hit = find(child, field, depth + 1)
        if hit then return hit end
    end
end
local list = find(editor, "note", 0)
H.checkTrue("an editor", list)
H.check("its own note", list and list.note:GetText(), L.SPELL_LIST_NOTE)
ns.Config.Set("player", "shieldsExtra", "17")
list:Refresh()
H.check("no mark", list.lines[1].mark:GetText(), "")
ns.Config.Set("player", "shieldsExtra", "")
list:Refresh()
H.check("empty: its own text", list.lines[1].text:GetText(), L.SPELL_LIST_EMPTY)
