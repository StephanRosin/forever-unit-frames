-- The buff watch window's rows (Raid/BuffWatchWindow.lua): the name gives
-- way to the counts (cut, one line) in every language; the counts in a
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

-- The counts' words: neutral forms, "missing: 1".
H.check("counts: neutral", L.RAID_BUFF_COUNTS:format(1, 0), "missing: 1, expiring: 0")
-- The name's room beside the widest counts (two digits each), at least
-- NAME_MIN, in every language.
local room = Win.WIDTH - 2 * Win.PADDING - Win.ICON - 2 * Win.GAP
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    local words = ns.Locales[code]
    for _, key in ipairs({ "RAID_BUFF_COUNTS", "RAID_BUFF_UNKNOWN" }) do
        local text = key == "RAID_BUFF_COUNTS" and words[key]:format(40, 40) or words[key]
        H.checkTrue(code .. " " .. key .. " leaves the name room", room - width(text, 11) >= Win.NAME_MIN)
    end
end

-- Test mode, solo: sized and laid out as in a group, a row per watched
-- buff (its name and icon; no counts, no cast).
ns.RaidTestMode.Set(true)
M.Tick(1)
H.check("test mode: shown", f:IsShown(), true)
local _, h3 = Win.Size()
H.check("test mode: three rows' height", f:GetHeight(), 2 * Win.PADDING + Win.LINE_H + 3 * Win.ROW_H)
H.check("test mode: the size it says", f:GetHeight(), h3)
H.check("test mode: rows", Win.rows[3] and Win.rows[3]:IsShown(), true)
H.check("test mode: a row's name", Win.rows[2].name:GetText(), "Divine Spirit")
H.check("test mode: no counts", Win.rows[1].count:GetText(), "")
H.check("test mode: no cast", Win.rows[1]:GetAttribute("type"), nil)
ns.RaidTestMode.Set(false)
M.Tick(1)

-- A party: the rows. The name sits between the icon and the counts, one
-- line, cut where the counts begin.
M.units.party1 = { name = "Ann", class = "MAGE", className = "Mage", isPlayer = true, auras = {}, distance = 10 }
M.SetGroup({ "party1" })
M.Tick(1)
local row = Win.rows[1]
H.check("in a group: shown", f:IsShown(), true)
H.check("counts", row.count:GetText(), L.RAID_BUFF_COUNTS:format(2, 0))
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
H.check("size: MAX_ROWS rows", select(2, Win.Size()), 2 * Win.PADDING + Win.LINE_H + Win.MAX_ROWS * Win.ROW_H)

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
H.check("might: the three warriors", Win.rows[1].count:GetText(), L.RAID_BUFF_COUNTS:format(3, 0))
H.check("a click: the greater blessing", M.SecureClick(Win.rows[1], "LeftButton"), "spell")
H.check("cast", M.casts[#M.casts][1] .. "@" .. M.casts[#M.casts][2], "25782@party1")
Win.rows[1]:GetScript("OnEnter")(Win.rows[1])
H.check("its tooltip: the class", M.tooltipLines[1], "Greater Blessing of Might: Warrior")
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
