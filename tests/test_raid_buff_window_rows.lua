-- The buff watch window's rows (Raid/BuffWatchWindow.lua): the name gives
-- way to the counts (cut, one line) in every language; the counts as marks;
-- neutral form; at most MAX_ROWS rows; a paladin's blessing rows; its
-- size in test mode (the watched buffs, before any group); kept inside the
-- screen when it grows.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "Priest", isPlayer = true, auras = {} }
M.known[1243], M.known[14752], M.known[976] = true, true, true
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, Win, Watch, L = ns.RaidConfig, ns.RaidBuffWindow, ns.RaidBuffWatch, ns.L
RC.Set("general", "buffShadowProtection", true)
RC.Set("general", "buffWatchOnlyMissing", false)
local f = Win.frame

local function width(text, size)
    local fs = M.newWidget("FontString")
    fs:SetFont("x", size, "")
    fs:SetText(text)
    return fs:GetStringWidth()
end

-- The unknown note leaves the name room (at least 80 px) in every language.
local room = Win.WIDTH - 2 * Win.PADDING - Win.ICON - 2 * Win.GAP
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    H.checkTrue(code .. " RAID_BUFF_UNKNOWN leaves the name room", room - width(ns.Locales[code].RAID_BUFF_UNKNOWN, 11) >= 80)
end

-- Test mode, solo: sized and laid out as in a group, a row per watched
-- buff (its name and icon; no counts, no cast).
ns.RaidTestMode.Set(true)
M.Tick(1)
H.check("test mode: shown", f:IsShown(), true)
local _, h3 = Win.Size()
H.check("test mode: three blocks' height", f:GetHeight(), 2 * Win.PADDING + Win.HEADER_H + Win.LINE_GAP + 3 * Win.BlockHeight(1))
H.check("test mode: the size it says", f:GetHeight(), h3)
H.check("test mode: rows", Win.rows[3] and Win.rows[3]:IsShown(), true)
H.check("test mode: a row's name", Win.rows[2].name:GetText(), "Divine Spirit")
H.checkTrue("test mode: sample name", Win.rows[1].lines[1]:GetText():find(L.RAID_BUFF_SAMPLE_MISSING, 1, true))
ns.Config.Set("general", "language", "deDE")
M.Tick(1)
H.checkTrue("test mode: sample name follows the language", L.RAID_BUFF_SAMPLE_MISSING == "Fehlt"
    and Win.rows[1].lines[1]:GetText():find("Fehlt", 1, true))
ns.Config.Set("general", "language", "enUS")
M.Tick(1)
H.check("test mode: no counts", Win.rows[1].count:GetText(), "")
H.check("test mode: no cast", Win.rows[1]:GetAttribute("type"), nil)
-- Hovering a preview row names no target and raises nothing.
local wasArmed = ns.RaidBuffWatch.armed
ns.RaidBuffWatch.armed = true
local okHover, errHover = pcall(Win.rows[1]:GetScript("OnEnter"), Win.rows[1])
H.check("test mode: hover a preview row" .. (okHover and "" or (": " .. tostring(errHover))), okHover, true)
H.check("test mode: the tooltip names nobody", M.tooltipLines and M.tooltipLines[1], ns.L.RAID_BUFF_NOTHING)
Win.rows[1]:GetScript("OnLeave")(Win.rows[1])
H.check("a preview state: no best", ns.RaidBuffWatch.Best({ entry = Win.rows[1].state.entry, preview = true }), nil)
ns.RaidBuffWatch.armed = wasArmed
ns.RaidTestMode.Set(false)
M.Tick(1)

-- A party: the rows. The name sits between the icon and the counts, one
-- line, cut where the counts begin.
M.units.party1 = { name = "Ann", class = "MAGE", className = "Mage", isPlayer = true, auras = {}, distance = 10 }
M.SetGroup({ "party1" })
M.Tick(1)
local row = Win.rows[1]
H.check("in a group: shown", f:IsShown(), true)
H.check("counts: the missing mark", row.count:GetText(), Win.CountText({ missing = 2, expiring = 0 }))
H.checkTrue("counts: red number", Win.CountText({ missing = 2, expiring = 0 }):find("|cffe64d4d2|r", 1, true))
H.checkTrue("counts: decline mark", Win.CountText({ missing = 2, expiring = 0 }):find("UI-LFG-DeclineMark", 1, true))
H.check("counts: running out only", Win.CountText({ missing = 0, expiring = 1 }):find("DeclineMark", 1, true), nil)
H.checkTrue("counts: nothing needed, a check", Win.CountText({ missing = 0, expiring = 0 }):find("UI-LFG-ReadyMark", 1, true))
H.check("counts: unknown", Win.CountText({ unknown = true }), L.RAID_BUFF_UNKNOWN)
H.check("counts: preview none", Win.CountText({ preview = true }), "")
-- The names under the row: who misses it (you and Ann miss Fortitude here).
H.checkTrue("names: a line", row.lines[1]:IsShown())
H.checkTrue("names: Ann", row.lines[1]:GetText():find("Ann", 1, true))
H.check("names: one line only", row.lines[2]:IsShown(), false)
H.check("height: the block grows by its line", row:GetHeight(), Win.BlockHeight(1))
-- Right-click: nothing secure, and the buff is no longer watched.
H.check("right button casts nothing", row:GetAttribute("type2"), "")
local before = #M.casts
H.check("right-click: no secure action", M.SecureClick(row, "RightButton"), nil)
H.check("right-click: no cast", #M.casts, before)
row:GetScript("PostClick")(row, "RightButton", false)
M.Tick(1)
H.check("right-click: switched off", ns.RaidConfig.Get("general", "buffFortitude"), false)
ns.RaidConfig.Set("general", "buffFortitude", true)
M.Tick(1)
-- The tooltip: the cast, then every name, then the hint.
row = Win.rows[1]
row:GetScript("OnEnter")(row)
local all = table.concat(M.tooltipLines or {}, "\n")
H.checkTrue("tooltip: Ann", all:find("Ann", 1, true))
H.checkTrue("tooltip: the right-click hint", all:find(L.RAID_BUFF_RIGHT_CLICK, 1, true))
row:GetScript("OnLeave")(row)
-- In combat a right-click does nothing.
M.SetCombat(true)
row:GetScript("PostClick")(row, "RightButton", false)
H.check("in combat: still watched", ns.RaidConfig.Get("general", "buffFortitude"), true)
M.SetCombat(false)
M.Tick(1)
-- The header: title and the next cast.
H.check("title", Win.title:GetText(), L.RAID_BUFF_WATCH_TITLE)
H.checkTrue("next cast in the header", Win.next:GetText() ~= nil)
local function anchor(region, i)
    local p, rel, relPoint, x = region:GetPoint(i)
    local name = rel == row.icon and "icon" or rel == row.count and "count" or rel == row and "row" or "?"
    return table.concat({ p, name, relPoint, x }, " ")
end
H.check("name: after the icon", anchor(row.name, 1), "LEFT icon RIGHT " .. Win.GAP)
H.check("name: up to the counts", anchor(row.name, 2), "RIGHT count LEFT " .. -Win.GAP)
H.check("name: one line", row.name:GetWordWrap(), false)
H.check("name: from the left", row.name._justifyH, "LEFT")

-- Kept inside the screen when it grows: placed low, three rows would
-- reach below the bottom; the window is lifted (the setting stays).
RC.Set("general", "buffWatchY", -500)
M.Tick(1)
local _, h = Win.Size()
local lift = ns.RaidPanel.Reach(Win.WIDTH, h, "y", -500) + 500
H.checkTrue("it would leave the screen", lift > 0)
local _, rel, _, x, y = f:GetPoint(1)
H.check("lifted inside the screen", y, lift)
H.check("from its mover", rel, f.mover)
H.check("not sideways", x, 0)
H.check("the setting stays", RC.Get("general", "buffWatchY"), -500)
RC.Set("general", "buffWatchY", 120)
M.Tick(1)
H.check("room enough: on its mover", select(5, f:GetPoint(1)), 0)

-- More watched buffs than rows: at most MAX_ROWS, the size too.
local many = {}
for i = 1, Win.MAX_ROWS + 2 do many[i] = Watch.state.entries[1] end
Watch.state = { entries = many, missingUnits = {}, missingGUIDs = {} }
ns.Fire("RAID_BUFFS_CHANGED")
local shownRows = 0
for _, r in ipairs(Win.rows) do if r:IsShown() then shownRows = shownRows + 1 end end
H.check("rows: at most MAX_ROWS", shownRows, Win.MAX_ROWS)
H.check("rows made: no more", #Win.rows, Win.MAX_ROWS)
-- (each of these states has members missing it: one name line apiece)
H.check("size: MAX_ROWS blocks", select(2, Win.Size()), 2 * Win.PADDING + Win.HEADER_H + Win.LINE_GAP + Win.MAX_ROWS * Win.BlockHeight(1))

-- A paladin: a row per blessing chosen; three warriors without Might and
-- Symbols of Kings in the bags: a click blesses them all at once.
M.units.player.class = "PALADIN"
M.known[19740], M.known[25782], M.known[19742] = true, true, true
M.bagItems[21177] = 5
local function warrior(name)
    return { name = name, class = "WARRIOR", className = "Warrior", isPlayer = true, auras = {}, distance = 10 }
end
M.units.party1, M.units.party2, M.units.party3 = warrior("W1"), warrior("W2"), warrior("W3")
M.units.party4 = { name = "Mia", class = "MAGE", className = "Mage", isPlayer = true, auras = {}, distance = 10 }
M.SetGroup({ "party1", "party2", "party3", "party4" })
M.Tick(1)
H.check("paladin: might's row", Win.rows[1].name:GetText(), "Blessing of Might")
H.check("paladin: wisdom's row", Win.rows[2].name:GetText(), "Blessing of Wisdom")
H.check("paladin: two rows", Win.rows[3]:IsShown(), false)
H.check("might: the three warriors", Win.rows[1].count:GetText(), Win.CountText({ missing = 3, expiring = 0 }))
H.check("a click: the greater blessing", M.SecureClick(Win.rows[1], "LeftButton"), "spell")
H.check("cast", M.casts[#M.casts][1] .. "@" .. M.casts[#M.casts][2], "25782@party1")
Win.rows[1]:GetScript("OnEnter")(Win.rows[1])
H.check("its tooltip: the class", M.tooltipLines[1], "Greater Blessing of Might: Warrior")
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
