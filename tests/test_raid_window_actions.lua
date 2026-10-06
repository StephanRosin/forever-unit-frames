-- What the raid options window does with the edited size as a whole
-- (Raid/Options/Window.lua): copy from another size or another
-- character after a second click, reset after a second click, export and
-- import as a string, locked in combat.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "MAGE", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = { raid = { ["Healer-Testrealm"] = { r20 = { cellWidth = 140 } } } }
M.FireEvent("PLAYER_LOGIN")
M.RunTimers()
local RO, RC, L = ns.RaidOptions, ns.RaidConfig, ns.L

local function click(button) button:GetScript("OnClick")(button) end
local list
local function pick(text)
    click(RO.copyRow.button)
    for _, r in ipairs(list.rows) do
        if r:IsShown() and r.text:GetText() == text then return click(r) end
    end
    error("no item " .. text)
end

RO.Open(40)
list = ns.Widgets.list
H.check("copy button", RO.copyRow.button.text:GetText(), "Copy from…")
H.check("reset button", RO.resetButton.text:GetText(), "Reset this size")
H.check("share button", RO.shareButton.text:GetText(), "Export / Import")

-- Copy from: the other sizes, then every size of the other characters.
click(RO.copyRow.button)
local texts = {}
for i, item in ipairs(list.items) do texts[i] = item.text end
H.check("copy choices", table.concat(texts, ","), "10 players,20 players,Healer-Testrealm: 10 players,"
    .. "Healer-Testrealm: 20 players,Healer-Testrealm: 40 players")
ns.Widgets.CloseList()

-- A pick arms the button; the second click copies.
RC.Set("r20", "cellHeight", 50)
pick("20 players")
H.check("armed", RO.copyRow.button.text:GetText(), L.CONFIRM)
H.check("armed in red", RO.copyRow.button.text._color[1], ns.Style.COLORS.error[1])
H.check("nothing copied yet", RC.Get("r40", "cellHeight"), 38)
click(RO.copyRow.button)
H.check("copied", RC.Get("r40", "cellHeight"), 50)
H.check("disarmed", RO.copyRow.button.text:GetText(), "Copy from…")
H.check("no list opened by the confirming click", list:IsShown(), false)

-- Left armed, it disarms after a few seconds.
pick("10 players")
M.RunTimers()
H.check("disarmed by time", RO.copyRow.button.text:GetText(), "Copy from…")
H.check("not copied", RC.Get("r40", "cellHeight"), 50)
click(RO.copyRow.button)
H.checkTrue("a click opens the list again", list:IsShown())
ns.Widgets.CloseList()

-- Another character's size.
pick("Healer-Testrealm: 20 players")
click(RO.copyRow.button)
H.check("copied from the character", RC.Get("r40", "cellWidth"), 140)
H.check("the character untouched", ForeverUnitFramesDB.raid["Healer-Testrealm"].r40, nil)

-- Another edited size disarms.
pick("20 players")
RO.SelectSize(10)
H.check("size change disarms", RO.copyRow.button.text:GetText(), "Copy from…")
RO.SelectSize(40)

-- Reset this size: two clicks.
click(RO.resetButton)
H.check("reset armed", RC.Get("r40", "cellWidth"), 140)
click(RO.resetButton)
H.check("reset", RC.Get("r40", "cellWidth"), 80)
H.check("other sizes kept", RC.Get("r20", "cellHeight"), 50)

-- Export and import, in place of the tab's page.
RC.Set("r40", "cellWidth", 90)
click(RO.shareButton)
H.checkTrue("panel shown", RO.share:IsShown())
H.check("export of the edited size", RO.exportArea:GetText(), ns.RaidProfiles.Export(40))
H.check("export hint names it", RO.exportHint:GetText(), "Copy this text to share or back up the 40 players profile.")
RO.SelectSize(20)
H.check("export follows the size", RO.exportArea:GetText(), ns.RaidProfiles.Export(20))
H.check("import hint follows", RO.importHint:GetText(), "Paste a raid size here: it replaces the 20 players profile.")
RO.importArea:SetText("  " .. ns.RaidProfiles.Export(40) .. "  ")
click(RO.importButton)
H.check("imported onto 20", RC.Get("r20", "cellWidth"), 90)
H.check("as 40 shows it, its height included", RC.Get("r20", "cellHeight"), 38)
H.check("done", RO.importMessage:GetText(), L.IMPORT_DONE)
H.check("area cleared", RO.importArea:GetText(), "")
H.check("export shows the new state", RO.exportArea:GetText(), ns.RaidProfiles.Export(20))
RO.importArea:SetText("1;gSM2")
click(RO.importButton)
H.check("no size: refused", RO.importMessage:GetText(), L.IMPORT_RAID_NO_SIZE)
H.check("refusal in red", RO.importMessage._color[1], ns.Style.COLORS.error[1])
H.check("size kept", RC.Get("r20", "cellWidth"), 90)
RO.importArea:SetText("1;bCW100;junk")
click(RO.importButton)
H.check("skipped entries counted", RO.importMessage:GetText(),
    "Imported; 1 entries could not be read and were left out.")
H.check("readable part imported", RC.Get("r20", "cellWidth"), 100)
RO.importArea:SetText("")
click(RO.importButton)
H.check("empty", RO.importMessage:GetText(), L.IMPORT_CODEC_EMPTY)
click(RO.shareButton)
H.check("button hides it again", RO.share:IsShown(), false)
click(RO.shareButton)
RO.SelectTab("layout")
H.check("a tab hides it", RO.share:IsShown(), false)

-- Combat locks what changes the profile.
click(RO.shareButton)
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("copy locked", RO.copyRow.button:IsEnabled(), false)
H.check("reset locked", RO.resetButton:IsEnabled(), false)
H.check("import locked", RO.importButton:IsEnabled(), false)
H.check("import area locked", RO.importArea.edit:IsEnabled(), false)
H.check("export still readable", RO.shareButton:IsEnabled(), true)
M.SetCombat(false)
H.check("copy unlocked", RO.copyRow.button:IsEnabled(), true)
H.check("import unlocked", RO.importButton:IsEnabled(), true)

-- Closing disarms.
click(RO.resetButton)
RO.Close()
H.check("closing disarms reset", RO.resetButton.text:GetText(), "Reset this size")
H.check("nothing blocked", #M.blocked, 0)
