-- Which size the raid window edits (Raid/Options/Window.lua). Opened
-- without a size it edits the size the panel shows now, not the one
-- edited last time. While it edits another size than the panel shows
-- (test mode off), a note under the tabs says so: typed values of that
-- size change nothing on screen.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, L = ns.RaidOptions, ns.RaidConfig, ns.L

local function click(button) button:GetScript("OnClick")(button) end
local function note() return RO.sizeNotice:IsShown() and RO.sizeNotice.text:GetText() or nil end
local function scrollTop() return select(2, RO.frame.scroll:GetPoint(1)) end

-- Opened without a size: the shown one, whatever was edited before.
RO.Open(20)
H.check("opened on 20", RO.Size(), 20)
RO.Close()
RO.Open()
H.check("reopened: the size shown", RO.Size(), 10)
RO.Close()
SlashCmdList.FOREVERUNITFRAMES("raid")
H.check("/fuf raid: the size shown", RO.Size(), 10)
-- Already open: Open() without a size keeps the edited one.
RO.SelectSize(40)
RO.Open()
H.check("already open: kept", RO.Size(), 40)
RO.Close()
ns.RaidConfig.Set("general", "sizeMode", "20")
RO.Open()
H.check("another size shown: that one", RO.Size(), 20)
ns.RaidConfig.Set("general", "sizeMode", "AUTO")
RO.Close()

-- The note.
RO.Open()
H.check("editing the shown size: no note", note(), nil)
H.check("no note: the page under the tabs", scrollTop(), RO.frame.tabRow)
click(RO.sizeTabs[20])
H.check("editing 20: note",
    note(), "You are editing the 20-player layout — the panel shows 10. Turn on test mode to see it.")
H.check("the page under the note", scrollTop(), RO.sizeNotice)
click(RO.testButton)
H.check("test mode shows 20: no note", note(), nil)
H.check("test mode: the page under the tabs", scrollTop(), RO.frame.tabRow)
click(RO.testButton)
H.check("test mode off: the note again", note() ~= nil, true)
RC.Set("general", "sizeMode", "20")
H.check("20 now shown: no note", note(), nil)
click(RO.sizeTabs[40])
H.check("editing 40", note(), "You are editing the 40-player layout — the panel shows 20. Turn on test mode to see it.")
RC.Set("general", "sizeMode", "AUTO")
H.check("follows the size shown", note(), "You are editing the 40-player layout — the panel shows 10. Turn on test mode to see it.")
-- The unit frames' test mode shows the edited size too.
ns.TestMode.Set(true)
H.check("unit test mode: no note", note(), nil)
ns.TestMode.Set(false)
H.checkTrue("unit test mode off: the note", note() ~= nil)

-- In combat the combat notice comes first, the note under it.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("combat: note under the combat notice", select(2, RO.sizeNotice:GetPoint(1)), RO.combatNotice)
H.check("combat: the page under the note", scrollTop(), RO.sizeNotice)
M.SetCombat(false)
H.check("after combat: note under the tabs", select(2, RO.sizeNotice:GetPoint(1)), RO.frame.tabRow)

-- Every language.
for code, text in pairs({ deDE = "Du bearbeitest die Anordnung für 40 Spieler",
    esES = "Estás editando el diseño de 40 jugadores", frFR = "Vous modifiez la disposition à 40 joueurs" }) do
    ns.Config.Set("general", "language", code)
    H.checkTrue(code .. ": note", (note() or ""):find(text, 1, true) == 1)
    H.checkTrue(code .. ": fits the strip", RO.sizeNotice.text:GetStringHeight() < RO.sizeNotice:GetHeight())
end
ns.Config.Set("general", "language", "enUS")
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    H.checkTrue(code .. ": has the word", type(ns.Locales[code].RAID_EDITING_NOT_SHOWN) == "string")
end
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
