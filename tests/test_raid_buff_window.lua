-- The buff watch window (Raid/BuffWatchWindow.lua): a row per buff somebody
-- needs (icon, the names next to it, or unknown), a click on a row casts
-- that buff on whoever needs it most (a secure button set out of combat);
-- hidden solo and while nothing is
-- watched, optionally while nothing is missing; in combat its last state,
-- greyed, the rows casting nothing. Moved with the raid window's lock.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", className = "Priest", isPlayer = true, auras = {} }
M.known[1243] = true
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RC, Win, Watch, L = ns.RaidConfig, ns.RaidBuffWindow, ns.RaidBuffWatch, ns.L

local f = Win.frame
H.check("built at login", f:GetName(), "ForeverUnitFramesBuffWatch")
H.check("solo: hidden", f:IsShown(), false)
H.check("its mover", f.mover.spec.id, "raidBuffWatch")
H.check("moved with the raid window", f.mover.spec.group, "raid")
H.check("its position shows in the raid window", ns.RaidPanel.ByPositionKey("buffWatchX"), Win)

-- A party: Ann needs Fortitude, Bob has it running out.
local function fortAura(left)
    return { name = "Power Word: Fortitude", spellId = 1243, isHelpful = true, expirationTime = M.now + left }
end
M.units.player.auras = { fortAura(1700) }
M.units.party1 = { name = "Ann", class = "MAGE", className = "Mage", isPlayer = true, auras = {}, distance = 10 }
M.units.party2 = { name = "Bob", class = "MAGE", className = "Mage", isPlayer = true, auras = { fortAura(60) },
    distance = 10 }
M.SetGroup({ "party1", "party2" })
M.Tick(1)
H.check("in a group: shown", f:IsShown(), true)
local row = Win.rows[1]
H.check("one row", row:IsShown() and (not Win.rows[2] or not Win.rows[2]:IsShown()), true)
H.check("a secure button", row._template, "SecureActionButtonTemplate")
H.check("key down and up", table.concat(row._clicks, ","), "AnyUp,AnyDown")
H.check("its icon", row.icon._texture, 100000 + 1243)
H.check("the title alone", Win.title:GetText(), "Smart Buffs")
H.check("no next cast in the header", Win.next, nil)
H.checkTrue("names: who misses it", row.lines[1]:GetText():find("Ann", 1, true))
H.checkTrue("names: who has it running out", row.lines[1]:GetText():find("Bob", 1, true))
H.check("names: without the minutes", row.lines[1]:GetText():find(L.RAID_BUFF_MINUTES:format(1), 1, true), nil)
H.checkTrue("names: next to the icon", select(4, row.lines[1]:GetPoint(1)) == Win.NAMES_INDENT
    and select(5, row.lines[1]:GetPoint(1)) > -Win.ROW_H)
-- A click casts it on Ann.
H.check("a click casts", M.SecureClick(row, "LeftButton"), "spell")
H.check("on Ann", M.casts[1][1] .. "@" .. M.casts[1][2], "1243@party1")
-- The roster changes: the units may be other members now; the rows and
-- the smart buff key cast nothing until the next scan sets them again.
M.FireEvent("GROUP_ROSTER_UPDATE")
H.check("roster changed: the row casts nothing", row:GetAttribute("type"), nil)
H.check("roster changed: the key casts nothing", ns.SmartBuff.button:GetAttribute("type"), nil)
ns.Fire("RAID_TEST_MODE")
H.check("roster changed: a refresh does not re-arm it", row:GetAttribute("unit"), nil)
M.Tick(1)
H.check("the next scan: armed again", row:GetAttribute("unit"), "party1")
H.check("the key too", ns.SmartBuff.button:GetAttribute("unit"), "party1")
-- Its tooltip says on whom.
row:GetScript("OnEnter")(row)
H.check("tooltip", M.tooltipLines[1], "Power Word: Fortitude: Ann")
row:GetScript("OnLeave")(row)

-- Ann too far away (Bob is fine for now): someone misses it, but no cast
-- reaches them; the window says so instead of "nothing to buff".
M.units.party2.auras = { fortAura(1700) }
M.units.party1.distance = 100
M.FireEvent("UNIT_AURA", "party2")
M.Tick(1)
H.checkTrue("out of range: the name greyed", row.lines[1]:GetText():find("|cff808080Ann|r", 1, true))
row:GetScript("OnEnter")(row)
H.check("out of range: the tooltip says so", M.tooltipLines[1], L.RAID_BUFF_OUT_OF_RANGE)
H.check("out of range: and which buff", M.tooltipLines[2], "Power Word: Fortitude")
row:GetScript("OnLeave")(row)
M.units.party1.distance = 10

-- Everyone buffed: no row, no cast, the window only its header.
M.units.party1.auras = { fortAura(1700) }
M.units.party2.auras = { fortAura(1700) }
M.FireEvent("UNIT_AURA", "party1")
M.Tick(1)
H.check("nothing missing: no row", row:IsShown(), false)
H.check("nothing missing: the header's height", f:GetHeight(), 2 * Win.PADDING + Win.HEADER_H + Win.LINE_GAP)
H.check("a click casts nothing", M.SecureClick(row, "LeftButton"), nil)
-- Only while something is missing: hidden now.
RC.Set("general", "buffWatchOnlyMissing", true)
M.Tick(1)
H.check("only when missing: hidden", f:IsShown(), false)
M.units.party1.auras = {}
M.FireEvent("UNIT_AURA", "party1")
M.Tick(1)
H.check("something missing: shown", f:IsShown(), true)
RC.Set("general", "buffWatchOnlyMissing", false)

-- Auras secret: unknown, nothing cast.
M.aurasSecret = true
Watch.Scan()
H.check("unknown", row.lines[1]:GetText(), L.RAID_BUFF_UNKNOWN)
H.check("unknown: no cast", row:GetAttribute("type"), nil)
M.aurasSecret = false
Watch.Scan()

-- Combat: the rows cast nothing (emptied as it starts), the texts grey,
-- the window stays with its last state; nothing protected is touched.
M.FireEvent("PLAYER_REGEN_DISABLED")
M.SetCombat(true)
H.check("combat: shown", f:IsShown(), true)
H.check("combat: no cast", row:GetAttribute("type"), nil)
H.check("combat: a click does nothing", M.SecureClick(row, "LeftButton"), nil)
local r, g, b = Win.title:GetTextColor()
H.check("combat: greyed", table.concat({ r, g, b }, ","), table.concat({ unpack(ns.Style.COLORS.muted, 1, 3) }, ","))
H.check("combat: names dimmed", row.lines[1]:GetAlpha(), 0.4)
-- The tooltip in combat: nothing to cast, no range asked.
local rangeQueries = M.spellQueries
row:GetScript("OnEnter")(row)
H.check("combat tooltip: nothing", M.tooltipLines[1], L.RAID_BUFF_NOTHING)
H.check("combat tooltip: no range asked", M.spellQueries, rangeQueries)
row:GetScript("OnLeave")(row)
M.SetGroup({})
M.Tick(1)
H.check("combat: kept until combat ends", f:IsShown(), true)
H.check("nothing blocked", #M.blocked, 0)
M.SetCombat(false)
M.Tick(1)
H.check("after combat, solo: hidden", f:IsShown(), false)
M.SetGroup({ "party1", "party2" })
M.Tick(1)
H.check("again: shown", f:IsShown(), true)
r, g, b = Win.title:GetTextColor()
H.check("not grey any more", r, ns.Style.COLORS.text[1])
H.check("names undimmed", row.lines[1]:GetAlpha(), 1)

-- Switched off; nothing watched.
RC.Set("general", "buffWatchShow", false)
M.Tick(1)
H.check("off: hidden", f:IsShown(), false)
RC.Set("general", "buffWatchShow", true)
RC.Set("general", "buffFortitude", false)
M.Tick(1)
H.check("nothing watched: hidden", f:IsShown(), false)
RC.Set("general", "buffFortitude", true)
M.Tick(1)
H.check("watched again", f:IsShown(), true)

-- Its position: the mover, from the settings.
local function point(frame)
    local p, rel, relPoint, x, y = frame:GetPoint(1)
    local name = rel == UIParent and "UIParent" or rel == f.mover and "mover" or "?"
    return table.concat({ p, name, relPoint, x, y }, " ")
end
H.check("at its position", point(f.mover), "TOPLEFT UIParent CENTER 300 120")
H.check("hangs from its mover", point(f), "TOPLEFT mover TOPLEFT 0 0")
RC.Set("general", "buffWatchX", 200)
H.check("moved", point(f.mover), "TOPLEFT UIParent CENTER 200 120")
H.check("no error", #M.errors, 0)
