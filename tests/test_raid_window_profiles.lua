-- The Profiles page's own profiles and copy between sizes (Raid/Options/
-- Profiles.lua): save all three sizes (the default) or one size under a
-- name, a name in use replaced after a second click; apply (a one-size
-- profile to a size or all, one of all sizes each into its size) with
-- Undo; delete after a second click, disarmed by another pick. Copy one
-- size onto another, everything or without layout and sizes, with Undo.
-- Its words fit in every language.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = { raidTemplates = { { name = "Old one", values = { cellWidth = 130 } } } }
M.FireEvent("PLAYER_LOGIN")
M.FireEvent("LOADING_SCREEN_DISABLED")
M.RunTimers()
local RO, RC, L, T, P = ns.RaidOptions, ns.RaidConfig, ns.L, ns.RaidTemplates, ns.RaidProfilesPage
ForeverUnitFramesDB.raidWizardSeen = { [ns.RaidProfiles.CharKey()] = true }

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

RO.Open(20, "profiles")
list = ns.Widgets.list
H.check("opened on the profiles page", RO.view, "profiles")
-- An old one-size template is listed as one.
H.check("old template listed", items(P.picker), "Old one (one size)")
H.check("apply to: the edited size", P.target.button.text:GetText(), "20 players")
H.check("targets", items(P.target), "All three sizes,10 players,20 players,40 players")
pick(P.target, "40 players")
click(P.applyButton)
H.check("one size applied to 40", RC.Get("r40", "cellWidth"), 130)
H.check("not to 20", RC.Get("r20", "cellWidth"), 88)
H.check("applied message", P.ownMessage:GetText(), L.RAID_TEMPLATE_APPLIED:format("Old one", "40 players"))
H.check("undo offered", P.undoButton:IsEnabled(), true)
click(P.undoButton)
H.check("undone", RC.Get("r40", "cellWidth"), 80)
H.check("undo message", P.ownMessage:GetText(), L.RAID_TEMPLATE_UNDONE)

-- Save: all three sizes by default.
RC.Set("r10", "cellWidth", 121)
RC.Set("r40", "cellWidth", 141)
H.check("save: all sizes by default", P.saveWhat.button.text:GetText(), L.RAID_PROFILES_ALL_SIZES)
P.nameBox:SetText("Raid night")
click(P.saveButton)
local saved = T.Find("own:Raid night")
H.checkTrue("saved", saved)
H.check("holds every size", table.concat(T.Held(saved), ","), "10,20,40")
H.check("saved message", P.ownMessage:GetText(), L.RAID_TEMPLATE_SAVED:format("Raid night"))
H.check("listed and picked", P.picker.button.text:GetText(), "Raid night (all sizes)")
H.check("apply to: each size", P.target.button.text:GetText(), L.RAID_PROFILES_EACH_SIZE)
H.check("apply to: no choice", P.target.button:IsEnabled(), false)
-- Applied: each size into its size, one change.
RC.Set("r10", "cellWidth", 60)
RC.Set("r40", "cellWidth", 61)
click(P.applyButton)
H.check("all: 10", RC.Get("r10", "cellWidth"), 121)
H.check("all: 40", RC.Get("r40", "cellWidth"), 141)
H.check("all: message", P.ownMessage:GetText(),
    L.RAID_TEMPLATE_APPLIED:format("Raid night", "10 players, 20 players, 40 players"))
click(P.undoButton)
H.check("all: one undo", RC.Get("r10", "cellWidth"), 60)
H.check("all: one undo 40", RC.Get("r40", "cellWidth"), 61)

-- One size.
pick(P.saveWhat, "10 players")
P.nameBox:SetText("Ten")
click(P.saveButton)
H.check("one size saved", T.Find("own:Ten").values.cellWidth, 60)
H.check("listed as one size", P.picker.button.text:GetText(), "Ten (one size)")

-- The same name again: a second click replaces it, and says so.
pick(P.saveWhat, "All three sizes")
P.nameBox:SetText("raid NIGHT")
click(P.saveButton)
H.check("existing name: armed", P.saveButton.text:GetText(), L.CONFIRM)
H.check("existing name: not replaced yet", T.Find("own:Raid night").sizes.r10.cellWidth, 121)
click(P.saveButton)
H.check("replaced", T.Find("own:Raid night").sizes.r10.cellWidth, 60)
H.check("replaced message", P.ownMessage:GetText(), L.RAID_TEMPLATE_REPLACED:format("raid NIGHT"))
H.check("still three", #T.Own(), 3)
P.nameBox:SetText("   ")
click(P.saveButton)
H.check("empty name refused", P.ownMessage:GetText(), L.RAID_TEMPLATE_NAME_EMPTY)

-- Delete: two clicks; another pick disarms it.
click(P.deleteButton)
H.check("delete armed", P.deleteButton.text:GetText(), L.CONFIRM)
pick(P.picker, "Old one (one size)")
H.check("a pick disarms delete", P.deleteButton.text:GetText(), L.RAID_TEMPLATE_DELETE)
click(P.deleteButton)
H.checkTrue("armed, not deleted", T.Find("own:Old one"))
click(P.deleteButton)
H.check("deleted", T.Find("own:Old one"), nil)
H.check("deleted message", P.ownMessage:GetText(), L.RAID_TEMPLATE_DELETED:format("Old one"))
T.DeleteOwn("own:Ten")
T.DeleteOwn("own:raid NIGHT")
H.check("none left", items(P.picker), L.RAID_PROFILES_NONE)
H.check("nothing to apply", P.applyButton:IsEnabled(), false)
H.check("nothing to delete", P.deleteButton:IsEnabled(), false)

-- Copy between sizes.
RC.Set("r10", "cellWidth", 150)
RC.Set("r10", "sortBy", "NAME")
RC.Set("r40", "x", 33)
H.check("copy onto: the edited size", P.copyTo.button.text:GetText(), "20 players")
H.check("copy from: another size", P.copyFrom.button.text:GetText(), "10 players")
pick(P.copyTo, "40 players")
H.check("modes", items(P.copyMode), "Everything,Without layout and sizes")
pick(P.copyMode, "Without layout and sizes")
click(P.copyButton)
H.check("behaviour copied", RC.Get("r40", "sortBy"), "NAME")
H.check("layout kept", RC.Get("r40", "cellWidth"), 61)
H.check("position kept", RC.Get("r40", "x"), 33)
H.check("copied message", P.copyMessage:GetText(), L.RAID_PROFILES_COPIED:format("10 players", "40 players"))
click(P.copyUndoButton)
H.check("copy undone", RC.Get("r40", "sortBy"), "INDEX")
pick(P.copyMode, "Everything")
click(P.copyButton)
H.check("everything copied", RC.Get("r40", "cellWidth"), 150)
H.check("position too", RC.Get("r40", "x"), -600)
pick(P.copyFrom, "40 players")
click(P.copyButton)
H.check("same size refused", P.copyMessage:GetText(), L.RAID_PROFILES_SAME_SIZE)
-- A change elsewhere ends the undo: the buttons follow.
RC.Set("r20", "cellSpacing", 5)
H.check("undo gone after another change", P.copyUndoButton:IsEnabled(), false)
RO.Close()

-- The words fit: labels in the label column, button words in their
-- buttons, the tab word in its tab; in every language.
for _, code in ipairs({ "enUS", "deDE", "esES", "frFR" }) do
    ns.Config.Set("general", "language", code)
    RO.Open(10, "profiles")
    P = ns.RaidProfilesPage
    for _, row in ipairs(RO.rows) do
        if row.label and row.label.GetStringWidth and not row.isSection then
            H.checkTrue(code .. " label fits: " .. tostring(row.label:GetText()),
                row.label:GetStringWidth() <= ns.Widgets.LABEL_MAX_W)
        end
        if row.hintText then
            H.checkTrue(code .. " hint fits: " .. tostring(row.hintText:GetText()),
                row.hintText:GetStringWidth() <= ns.Widgets.LABEL_MAX_W)
        end
    end
    for _, b in ipairs({ P.applyButton, P.undoButton, P.deleteButton, P.saveButton, P.copyButton, P.copyUndoButton,
        P.characterButton, P.resetButton, P.importButton }) do
        H.checkTrue(code .. " word fits: " .. b.text:GetText(), b.text:GetStringWidth() <= b:GetWidth() - 8)
    end
    for _, field in ipairs({ "saveWhat", "copyMode", "exportWhat", "copyFrom" }) do
        for _, item in ipairs((function()
            click(P[field].button)
            local l = list.items
            ns.Widgets.CloseList()
            return l
        end)()) do
            local fs = M.newWidget("FontString")
            fs:SetFont("x", 12, "")
            fs:SetText(item.text)
            H.checkTrue(code .. " choice fits: " .. item.text, fs:GetStringWidth() <= ns.Widgets.CONTROL_W - 32)
        end
    end
    -- Own profiles' names: the longest name and the longest "what it
    -- holds" in the picker's button.
    local longest = string.rep("W", T.OWN_NAME_LETTERS)
    for _, key in ipairs({ "RAID_PROFILES_OWN_ALL", "RAID_PROFILES_OWN_ONE" }) do
        local fs = M.newWidget("FontString")
        fs:SetFont("x", 12, "")
        fs:SetText(L[key]:format(longest))
        H.checkTrue(code .. " own name fits: " .. key, fs:GetStringWidth() <= P.picker.button:GetWidth() - 32)
    end
    -- A character's name and realm and a size in its picker.
    local fs = M.newWidget("FontString")
    fs:SetFont("x", 12, "")
    fs:SetText(L.RAID_COPY_CHARACTER:format(string.rep("W", 12) .. "-" .. string.rep("W", 20), "40 " .. L.RAID_PROFILES_TAB))
    H.checkTrue(code .. " character fits", fs:GetStringWidth() <= P.character.button:GetWidth() - 32)
    -- The page's messages stay inside the page: both edges anchored, two
    -- lines at most for the longest of them.
    local available = RO.PAGE.width - ns.Widgets.CONTROL_X - RO.PAGE.inset
    for _, message in ipairs({ P.ownMessage, P.copyMessage, P.characterMessage, P.resetMessage, P.importMessage }) do
        H.check(code .. " message: both edges", message:GetNumPoints(), 2)
        H.checkTrue(code .. " message: wraps", message:GetWordWrap())
    end
    for _, text in ipairs({
        L.RAID_PROFILES_COPIED:format(L.RAID_COPY_CHARACTER:format(string.rep("W", 12) .. "-" .. string.rep("W", 20),
            "40"), "40"),
        L.RAID_IMPORT_ALL_SKIPPED:format("10, 20, 40", 99), L.RAID_TEMPLATE_APPLIED:format(longest, "10, 20, 40"),
        L.RAID_TEMPLATE_NAME_TOO_LONG:format(32), L.RAID_TEMPLATE_REFUSED, L.RAID_PROFILES_COPY_REFUSED,
    }) do
        local f = M.newWidget("FontString")
        f:SetFont("x", 11, "")
        f:SetText(text)
        H.checkTrue(code .. " message in two lines: " .. text, f:GetStringWidth() <= 2 * available)
    end
    -- The size bar: the size tabs (one of them "shown") and Profiles left
    -- of the size mode's label and dropdown, against the bar's width.
    local sizeOf = ns.RaidCell.Size
    for _, shown in ipairs({ 10, 20, 40 }) do
        ns.RaidCell.Size = function() return shown end
        ns.Fire("RAID_SIZE_CHANGED")
        local used = RO.SIZE_BAR_LEFT
        for _, size in ipairs(ns.Raid.SIZES) do used = used + RO.sizeTabs[size]:GetWidth() end
        used = used + RO.profilesTab:GetWidth()
        local right = RO.SIZE_BAR_RIGHT + RO.sizeModeRow:GetWidth() + RO.SIZE_BAR_GAP
            + RO.sizeModeLabel:GetStringWidth() + RO.SIZE_BAR_GAP
        H.checkTrue(code .. " size bar fits, " .. shown .. " shown", used + right <= RO.frame:GetWidth())
    end
    ns.RaidCell.Size = sizeOf
    RO.Close()
end
-- The copy mode's hint names what it means (decision 53's "without layout").
H.check("mode hint", ns.Locales.enUS.RAID_PROFILES_MODE_HINT, "Without layout: positions and sizes stay")
ns.Config.Set("general", "language", "AUTO")
H.check("nothing blocked", #M.blocked, 0)
H.check("no error", #M.errors, 0)
