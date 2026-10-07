-- The raid window's Profiles tab (Raid/Options/Window.lua, Raid/Options/
-- Profiles.lua): a fourth tab next to the sizes 10, 20 and 40 that shows
-- only the profile page (no menu tabs). On it: copy from another
-- character after a second click, reset a size after a second click,
-- export all sizes or one, import one size into the size picked or a text
-- of several sizes after a second click (one change with Undo); locked in
-- combat.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = { raid = { ["Healer-Testrealm"] = { r20 = { cellWidth = 140 } } } }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, L, P, T = ns.RaidOptions, ns.RaidConfig, ns.L, ns.RaidProfilesPage, ns.RaidTemplates

local function click(button) button:GetScript("OnClick")(button) end
local list
local function items(row)
    click(row.button)
    local texts = {}
    for i, item in ipairs(list.items) do texts[i] = item.text end
    ns.Widgets.CloseList()
    return table.concat(texts, ",")
end
local function pick(row, text)
    click(row.button)
    for _, r in ipairs(list.rows) do
        if r:IsShown() and r.text:GetText() == text then return click(r) end
    end
    error("no item " .. text)
end

RO.Open(40, "layout")
list = ns.Widgets.list
H.check("no copy or reset in the footer", RO.copyRow == nil and RO.resetButton == nil, true)
H.check("the profiles tab", RO.profilesTab.text:GetText(), "Profiles")
H.checkTrue("beside the sizes", select(2, RO.profilesTab:GetPoint(1)) == RO.sizeTabs[40])
H.check("no Profile menu tab any more", (function()
    for _, tab in ipairs(ns.RaidSchema.TABS) do if tab.id == "profile" then return true end end
    return false
end)(), false)

-- Picked: only its page, no menu tabs, no size underlined.
click(RO.profilesTab)
H.checkTrue("profiles shown", RO.profilesShown)
H.check("menu tabs hidden", RO.frame.tabRow:IsShown(), false)
H.checkTrue("its page", P.picker:IsVisible() and RO.page == P.picker:GetParent())
H.check("its tab underlined", RO.profilesTab.underline:IsShown(), true)
H.check("no size underlined", RO.sizeTabs[40].underline:IsShown(), false)
H.check("the page at the top", select(2, RO.frame.scroll:GetPoint(1)), RO.frame.body)
H.check("no note on a size not shown", RO.sizeNotice:IsShown(), false)
-- A size tab: back to the menu tab shown before.
click(RO.sizeTabs[20])
H.check("a size: its settings again", RO.profilesShown, false)
H.check("the tab before", RO.currentTab, "layout")
H.checkTrue("menu tabs back", RO.frame.tabRow:IsShown())
H.check("the size picked", RO.Size(), 20)
RO.SelectSize(40)
click(RO.profilesTab)

-- Copy from another character: every size of each, onto the size picked.
H.check("characters offered", items(P.character), "Healer-Testrealm: 10 players,Healer-Testrealm: 20 players,"
    .. "Healer-Testrealm: 40 players")
H.check("onto: the edited size", P.characterTo.button.text:GetText(), "40 players")
pick(P.character, "Healer-Testrealm: 20 players")
click(P.characterButton)
H.check("armed", P.characterButton.text:GetText(), L.CONFIRM)
H.check("nothing copied yet", RC.Get("r40", "cellWidth"), 80)
click(P.characterButton)
H.check("copied from the character", RC.Get("r40", "cellWidth"), 140)
H.check("the character untouched", ForeverUnitFramesDB.raid["Healer-Testrealm"].r40, nil)
H.check("said", P.characterMessage:GetText(),
    L.RAID_PROFILES_COPIED:format("Healer-Testrealm: 20 players", "40 players"))
-- One change: its Undo takes it back.
H.checkTrue("its undo offered", P.characterUndoButton:IsEnabled())
click(P.characterUndoButton)
H.check("copy undone", RC.Get("r40", "cellWidth"), 80)
H.check("undo said", P.characterMessage:GetText(), L.RAID_TEMPLATE_UNDONE)
-- The character gone between the clicks: said so.
click(P.characterButton)
local saved = ForeverUnitFramesDB.raid["Healer-Testrealm"]
ForeverUnitFramesDB.raid["Healer-Testrealm"] = nil
click(P.characterButton)
H.check("gone: said", P.characterMessage:GetText(), L.RAID_PROFILES_COPY_GONE)
H.check("gone: in red", P.characterMessage._color[1], ns.Style.COLORS.error[1])
ForeverUnitFramesDB.raid["Healer-Testrealm"] = saved
P.Refresh()
pick(P.character, "Healer-Testrealm: 20 players")
click(P.characterButton)
click(P.characterButton)
H.check("copied again", RC.Get("r40", "cellWidth"), 140)
-- Left armed, it disarms after a few seconds.
click(P.characterButton)
M.RunTimers()
H.check("disarmed by time", P.characterButton.text:GetText(), L.RAID_PROFILES_COPY)

-- Reset a size: two clicks.
RC.Set("r20", "cellHeight", 50)
pick(P.resetSize, "40 players")
click(P.resetButton)
H.check("reset armed", RC.Get("r40", "cellWidth"), 140)
click(P.resetButton)
H.check("reset", RC.Get("r40", "cellWidth"), 80)
H.check("other sizes kept", RC.Get("r20", "cellHeight"), 50)
H.check("reset said", P.resetMessage:GetText(), L.RAID_PROFILES_RESET_DONE:format("40 players"))

-- Export: all sizes by default, or one.
RC.Set("r40", "cellWidth", 90)
H.check("export: all sizes", P.exportWhat.button.text:GetText(), L.RAID_PROFILES_ALL_SIZES)
H.check("export of all", P.exportArea:GetText(), ns.RaidProfiles.ExportAll())
H.check("its hint", P.exportHint:GetText(), L.RAID_EXPORT_ALL_HINT)
pick(P.exportWhat, "40 players")
H.check("export of one size", P.exportArea:GetText(), ns.RaidProfiles.Export(40))
H.check("export hint names it", P.exportHint:GetText(), "Copy this text to share or back up the 40 players profile.")
RC.Set("r40", "cellWidth", 95)
H.check("export follows changes", P.exportArea:GetText(), ns.RaidProfiles.Export(40))

-- The export text is made only when its box shows or the profile changes.
local encoded, exportAll, export = 0, ns.RaidProfiles.ExportAll, ns.RaidProfiles.Export
ns.RaidProfiles.ExportAll = function() encoded = encoded + 1; return exportAll() end
ns.RaidProfiles.Export = function(size) encoded = encoded + 1; return export(size) end
pick(P.exportWhat, L.RAID_PROFILES_ALL_SIZES)
encoded = 0
P.Refresh(); P.Refresh()
H.check("no new text without a change", encoded, 0)
RC.Set("r40", "cellWidth", 96)
H.check("a change: made once", encoded, 1)
H.check("and up to date", P.exportArea:GetText(), exportAll())
RO.SelectTab("layout")
encoded = 0
RC.Set("r40", "cellWidth", 95)
H.check("not shown: not made", encoded, 0)
click(RO.profilesTab)
H.check("shown again: made", encoded, 1)
H.check("shown again: up to date", P.exportArea:GetText(), exportAll())
ns.RaidProfiles.ExportAll, ns.RaidProfiles.Export = exportAll, export
pick(P.exportWhat, "40 players")

-- Import one size into the size picked.
pick(P.importTo, "20 players")
H.check("import hint names the size", P.importHint:GetText(), L.RAID_IMPORT_ANY_HINT:format("20 players"))
P.importArea:SetText("  " .. ns.RaidProfiles.Export(40) .. "  ")
click(P.importButton)
H.check("imported onto 20", RC.Get("r20", "cellWidth"), 95)
H.check("as 40 shows it, its height included", RC.Get("r20", "cellHeight"), 38)
H.check("done", P.importMessage:GetText(), L.IMPORT_DONE)
H.check("area cleared", P.importArea:GetText(), "")
P.importArea:SetText("1;gSM2")
click(P.importButton)
H.check("no size: refused", P.importMessage:GetText(), L.IMPORT_RAID_NO_SIZE)
H.check("refusal in red", P.importMessage._color[1], ns.Style.COLORS.error[1])
P.importArea:SetText("1;bCW100;junk")
click(P.importButton)
H.check("skipped entries counted", P.importMessage:GetText(),
    "Imported; 1 entries could not be read and were left out.")
H.check("readable part imported", RC.Get("r20", "cellWidth"), 100)
P.importArea:SetText("")
click(P.importButton)
H.check("empty", P.importMessage:GetText(), L.IMPORT_CODEC_EMPTY)

-- A text of all sizes: a second click, then every size, one change.
RC.Set("r10", "cellWidth", 111)
local all = ns.RaidProfiles.ExportAll()
RC.Set("r10", "cellWidth", 60)
RC.Set("r40", "cellWidth", 61)
P.importArea:SetText(all)
click(P.importButton)
H.check("all sizes: asks", P.importMessage:GetText(),
    L.RAID_IMPORT_ALL_ASK:format("10 players, 20 players, 40 players"))
H.check("all sizes: armed", P.importButton.text:GetText(), L.CONFIRM)
H.check("all sizes: nothing yet", RC.Get("r10", "cellWidth"), 60)
click(P.importButton)
H.check("all sizes: 10", RC.Get("r10", "cellWidth"), 111)
H.check("all sizes: 40", RC.Get("r40", "cellWidth"), 95)
H.check("all sizes: said", P.importMessage:GetText(),
    L.RAID_IMPORT_ALL_DONE:format("10 players, 20 players, 40 players"))
click(P.copyUndoButton)
H.check("all sizes: one undo", RC.Get("r10", "cellWidth"), 60)
H.check("all sizes: one undo 40", RC.Get("r40", "cellWidth"), 61)
-- Left armed, it disarms after a few seconds and the question goes too.
P.importArea:SetText(all)
click(P.importButton)
M.RunTimers()
H.check("import disarmed by time", P.importButton.text:GetText(), L.IMPORT)
H.check("its question gone", P.importMessage:GetText(), "")
-- Another text typed: the question was about the old one.
click(P.importButton)
H.checkTrue("typed", M.Type(P.importArea.edit, ns.RaidProfiles.Export(10)))
H.check("typing disarms", P.importButton.text:GetText(), L.IMPORT)
H.check("typing: the question gone", P.importMessage:GetText(), "")
-- Entries left out: still names the sizes and the undo.
P.importArea:SetText(all .. ";junk")
click(P.importButton)
click(P.importButton)
H.check("all sizes, entries left out: said", P.importMessage:GetText(),
    L.RAID_IMPORT_ALL_SKIPPED:format("10 players, 20 players, 40 players", 1))
click(P.copyUndoButton)

-- Shown again: the messages cleared.
RO.SelectTab("layout")
H.check("another tab hides it", P.importButton:IsVisible(), false)
click(RO.profilesTab)
H.check("back on it: the message cleared", P.importMessage:GetText(), "")

-- Combat locks what changes the profile; the tab stays reachable.
local refreshes, refresh = 0, P.Refresh
P.Refresh = function() refreshes = refreshes + 1; return refresh() end
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
P.Refresh = refresh
H.check("the lock refreshes the page once", refreshes, 1)
H.check("character copy locked", P.characterButton:IsEnabled(), false)
H.check("reset locked", P.resetButton:IsEnabled(), false)
H.check("import locked", P.importButton:IsEnabled(), false)
H.check("import area locked", P.importArea.edit:IsEnabled(), false)
H.check("copy locked", P.copyButton:IsEnabled(), false)
H.check("apply locked", P.applyButton:IsEnabled(), false)
H.check("save locked", P.saveButton:IsEnabled(), false)
H.check("picker locked", P.picker.button:IsEnabled(), false)
H.check("combat notice at the top", select(2, RO.combatNotice:GetPoint(1)), RO.frame.body)
H.check("profiles tab still reachable", RO.profilesTab:IsEnabled(), true)
M.SetCombat(false)
H.check("character copy unlocked", P.characterButton:IsEnabled(), true)
H.check("import unlocked", P.importButton:IsEnabled(), true)

-- Closing disarms; reopened, the Profiles page again.
click(P.resetButton)
RO.Close()
H.check("closing disarms reset", P.resetButton.text:GetText(), L.RAID_PROFILES_RESET)
RO.Open()
H.check("reopened on the profiles page", RO.profilesShown, true)
H.check("reopened: tabs still hidden", RO.frame.tabRow:IsShown(), false)
-- A new language: a new window, still on the Profiles page.
ns.Config.Set("general", "language", "deDE")
H.check("rebuilt on the profiles page", RO.profilesShown, true)
H.check("its word", RO.profilesTab.text:GetText(), "Profile")
ns.Config.Set("general", "language", "AUTO")
RO.Close()
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
