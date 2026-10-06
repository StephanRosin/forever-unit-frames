-- The raid options window (Raid/Options/Window.lua): opened with
-- /fuf raid; the edited size and the size shown in the header bar; the
-- raid menu's tabs and rows; names typed for classes and spells; the
-- combat lock; a new window for a new language.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, L = ns.RaidOptions, ns.RaidConfig, ns.L

local function click(button) button:GetScript("OnClick")(button) end
local function rowFor(key)
    for _, row in ipairs(RO.rows) do if row.key == key then return row end end
end
local function keys()
    local list = {}
    for _, row in ipairs(RO.rows) do if row.key then list[#list + 1] = row.key end end
    return table.concat(list, ",")
end
local function enter(row, text)
    M.Type(row.edit, text)
    M.PressEnter(row.edit)
end
local function errorBorder(box)
    return box.edges[1]._color[1] == ns.Style.COLORS.error[1]
end

-- Opening.
SlashCmdList.FOREVERUNITFRAMES("raid")
H.checkTrue("/fuf raid opens it", RO.IsOpen())
H.check("not the unit frames' window", ns.Options.IsOpen(), false)
local count = 0
for _, name in ipairs(UISpecialFrames) do if name == "ForeverUnitFramesRaidOptions" then count = count + 1 end end
H.check("ESC closes it", count, 1)
H.check("title", RO.frame.titleBar.title:GetText(), "Raid frames")

-- The header bar: solo, the 10-player profile is shown and edited.
H.check("edits the size shown", RO.Size(), 10)
H.check("10: shown", RO.sizeTabs[10].text:GetText(), "10 players (shown)")
H.check("20: plain", RO.sizeTabs[20].text:GetText(), "20 players")
H.checkTrue("edited size underlined", RO.sizeTabs[10].underline:IsShown())
H.check("others not", RO.sizeTabs[40].underline:IsShown(), false)
H.check("size switch", RO.sizeModeRow.button.text:GetText(), "Automatic")

-- The menu.
local titles = {}
for i, b in ipairs(RO.tabButtons) do titles[i] = b.text:GetText() end
H.check("tabs", table.concat(titles, ","), "General,Layout,Cell,Texts,Debuffs,Indicators,Icons & states,Profile")
H.check("first tab", RO.currentTab, "general")
H.check("general rows", keys(), "enabled,showInParty,hideBlizzard,minimapShow,minimapAngle")
H.check("label", rowFor("showInParty").label:GetText(), "Raid view in a party")
H.check("hint", rowFor("hideBlizzard").hintText:GetText(), "Needs /reload to show them again")
click(rowFor("showInParty").box)
H.check("character-wide setting", RC.Get("general", "showInParty"), true)
click(rowFor("showInParty").box)

RO.SelectTab("layout")
H.checkTrue("selected tab underlined", RO.tabButtons[2].underline:IsShown())
enter(rowFor("cellsPerLine"), "4")
H.check("set on the edited size", RC.Get("r10", "cellsPerLine"), 4)
H.check("other sizes untouched", RC.Get("r40", "cellsPerLine"), 5)
H.check("choice words", rowFor("blockDirection").button.text:GetText(), "Side by side")

-- Another size: the rows show and change its profile.
click(RO.sizeTabs[40])
H.check("edits 40", RO.Size(), 40)
H.checkTrue("40 underlined", RO.sizeTabs[40].underline:IsShown())
H.check("10 still shown", RO.sizeTabs[10].text:GetText(), "10 players (shown)")
H.check("row reads 40", rowFor("cellsPerLine").edit:GetText(), "5")
enter(rowFor("blocksPerLine"), "2")
H.check("set on 40", RC.Get("r40", "blocksPerLine"), 2)
H.check("10 untouched", RC.Get("r10", "blocksPerLine"), 8)
RO.SelectTab("cell")
H.check("cell width of 40", rowFor("cellWidth").edit:GetText(), "80")
H.check("the cell's note", RO.page.note:GetText(), L.RAID_NOTE_cell)

-- The size switch: the panel shows 20; the marker follows.
click(RO.sizeModeRow.button)
local list = ns.Widgets.list
H.checkTrue("size list open", list:IsShown())
H.check("four choices", #list.items, 4)
click(list.rows[3])
H.check("switch set", RC.Get("general", "sizeMode"), "20")
H.check("20 now shown", RO.sizeTabs[20].text:GetText(), "20 players (shown)")
H.check("10 no longer", RO.sizeTabs[10].text:GetText(), "10 players")
H.check("still editing 40", RO.Size(), 40)
RC.Set("general", "sizeMode", "AUTO")
H.check("switch follows a change from elsewhere", RO.sizeModeRow.button.text:GetText(), "Automatic")

-- Typed names: class names to tokens, spell names to their ranks' IDs.
RO.SelectTab("layout")
-- The field only takes text while the size groups by class.
RC.Set("r40", "groupBy", "CLASS")
enter(rowFor("classOrder"), "priest, Druid")
H.check("class order stored as tokens", RC.Get("r40", "classOrder"), "PRIEST,DRUID")
H.check("shown as stored", rowFor("classOrder").edit:GetText(), "PRIEST,DRUID")
enter(rowFor("classOrder"), "Priest, Monk")
H.check("unknown class refused", RC.Get("r40", "classOrder"), "PRIEST,DRUID")
H.checkTrue("refusal flashes", errorBorder(rowFor("classOrder").edit))
RO.SelectTab("indicators")
H.check("five positions", #RO.rows, 5 * 6)
M.known[2050], M.known[2052] = true, true
local spells = rowFor("indicatorTopLeftSpells")
H.check("spells hint", spells.hintText:GetText(), "Spell IDs, or names from your spell book")
enter(spells, "139, Lesser Heal")
H.check("names to the IDs of their ranks", RC.Get("r40", "indicatorTopLeftSpells"), "139,2050,2052")
enter(spells, "Nope")
H.check("unknown spell refused", RC.Get("r40", "indicatorTopLeftSpells"), "139,2050,2052")
H.checkTrue("spell refusal flashes", errorBorder(spells.edit))
H.check("point words", ns.RaidSchema.EnumText(ns.RaidSettings.Get("roleIconPoint"), "LEFT"), "Left")

-- Live refresh from outside.
RC.Set("r40", "indicatorTopLeftSize", 12)
H.check("row follows", rowFor("indicatorTopLeftSize").edit:GetText(), "12")

-- Combat: rows and the size switch lock, the notice shows.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("row locked", rowFor("indicatorTopLeftSize").edit._enabled, false)
H.check("size switch locked", RO.sizeModeRow.button:IsEnabled(), false)
H.checkTrue("notice", RO.combatNotice:IsShown())
H.check("sizes stay selectable", RO.sizeTabs[20]:IsEnabled(), true)
M.SetCombat(false)
H.check("row unlocked", rowFor("indicatorTopLeftSize").edit._enabled, true)
H.check("notice gone", RO.combatNotice:IsShown(), false)

-- Position saved, toggled closed by the slash command.
local f = RO.frame
f._points = { { "TOPLEFT", UIParent, "TOPLEFT", 120, -80 } }
f.titleBar:GetScript("OnDragStop")(f.titleBar)
H.check("position saved", ForeverUnitFramesDB.raidWindow.x, 120)
SlashCmdList.FOREVERUNITFRAMES("raid")
H.check("toggled closed", RO.IsOpen(), false)
RO.Open()
-- On the size shown, not the one edited before (tests/test_raid_window_size_note.lua).
H.check("reopens on the size shown", RO.Size(), 10)
H.check("on the same tab", RO.currentTab, "indicators")
RO.SelectSize(40)
H.check("where it was", select(4, RO.frame:GetPoint(1)), 120)

-- A new language: a new window on the same size and tab.
ns.Config.Set("general", "language", "deDE")
H.checkTrue("new window", RO.frame ~= f)
H.check("old one hidden", f:IsShown(), false)
H.checkTrue("open", RO.IsOpen())
H.check("German tabs", RO.tabButtons[1].text:GetText(), "Allgemein")
H.check("German sizes", RO.sizeTabs[10].text:GetText(), "10 Spieler (angezeigt)")
H.check("size kept", RO.Size(), 40)
count = 0
for _, name in ipairs(UISpecialFrames) do if name == "ForeverUnitFramesRaidOptions" then count = count + 1 end end
H.check("ESC entry not doubled", count, 1)
ns.Config.Set("general", "language", "AUTO")

-- The slash help names it.
SlashCmdList.FOREVERUNITFRAMES("help")
H.checkTrue("help names /fuf raid", M.chat[#M.chat]:find("/fuf raid", 1, true))
H.check("nothing blocked", #M.blocked, 0)
