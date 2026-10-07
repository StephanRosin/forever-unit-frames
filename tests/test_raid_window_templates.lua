-- The raid window's General tab, section Templates
-- (Raid/Options/Templates.lua): pick a role template, a look or an own
-- template, apply it to the edited size or to all sizes, undo, save the
-- edited size as an own template, delete an own one; locked in combat.
local M = H.M
local ns = H.LoadAddon()
M.units.player = { name = "Me", class = "PRIEST", health = 1, healthMax = 1 }
_G.ForeverUnitFramesDB = {}
M.FireEvent("PLAYER_LOGIN")
M.FireEvent("LOADING_SCREEN_DISABLED")
M.RunTimers()
local RO, RC, L, T = ns.RaidOptions, ns.RaidConfig, ns.L, ns.RaidTemplates
local P = ns.RaidTemplatesPage

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

-- Someone who changed something: no wizard on opening.
RC.Set("r10", "cellSpacing", 3)
RO.Open(20, "general")
list = ns.Widgets.list
H.check("section title", ns.RaidSchema.SectionTitle("templates"), "Templates")
H.checkTrue("its rows on the General page", P.picker:IsShown() and P.picker:GetParent() == RO.page)
H.check("picker label", P.picker.label:GetText(), "Template")
H.check("the suggested role first picked", P.picker.button.text:GetText(), "Role: Healer")
H.check("templates offered", items(P.picker), "Role: Healer,Role: Tank,Role: DPS,Role: Dispel only,"
    .. "Look: Forever,Look: Flat,Look: Classic")
H.check("target offered", items(P.target), "This size (20 players),All sizes")
H.check("undo: nothing yet", P.undoButton:IsEnabled(), false)
H.check("delete: not for a shipped one", P.deleteButton:IsEnabled(), false)

-- Apply to the edited size.
pick(P.picker, "Role: DPS")
click(P.applyButton)
H.check("applied to 20", RC.Get("r20", "secondLine"), "NONE")
H.check("not to 10", RC.Get("r10", "secondLine"), "DEFICIT")
H.check("message", P.message:GetText(), L.RAID_TEMPLATE_APPLIED:format("Role: DPS", "20 players"))
H.check("undo offered", P.undoButton:IsEnabled(), true)
click(P.undoButton)
H.check("undone", RC.Get("r20", "secondLine"), "DEFICIT")
H.check("undo message", P.message:GetText(), L.RAID_TEMPLATE_UNDONE)
H.check("undo spent", P.undoButton:IsEnabled(), false)

-- All sizes.
pick(P.picker, "Look: Flat")
pick(P.target, "All sizes")
click(P.applyButton)
H.check("all sizes: 10", RC.Get("r10", "cellCornerRadius"), 0)
H.check("all sizes: 40", RC.Get("r40", "cellCornerRadius"), 0)
H.check("all sizes message", P.message:GetText(), L.RAID_TEMPLATE_APPLIED:format("Look: Flat", L.RAID_TEMPLATE_ALL))

-- Save the edited size as an own template: listed, picked, deletable.
P.nameBox:SetText("Raid night")
click(P.saveButton)
H.check("saved", T.Find("own:Raid night") ~= nil, true)
H.check("saved message", P.message:GetText(), L.RAID_TEMPLATE_SAVED:format("Raid night"))
H.check("own listed and picked", P.picker.button.text:GetText(), "Own: Raid night")
H.check("delete offered", P.deleteButton:IsEnabled(), true)
H.check("box emptied", P.nameBox:GetText(), "")
P.nameBox:SetText("   ")
click(P.saveButton)
H.check("empty name refused", P.message:GetText(), L.RAID_TEMPLATE_NAME_EMPTY)
-- Delete takes two clicks.
click(P.deleteButton)
H.checkTrue("armed, not deleted", T.Find("own:Raid night"))
click(P.deleteButton)
H.check("deleted", T.Find("own:Raid night"), nil)
H.check("the suggestion picked again", P.picker.button.text:GetText(), "Role: Healer")

-- Combat locks the section.
M.combat = true
M.FireEvent("PLAYER_REGEN_DISABLED")
H.check("apply locked", P.applyButton:IsEnabled(), false)
H.check("save locked", P.saveButton:IsEnabled(), false)
H.check("picker locked", P.picker.button:IsEnabled(), false)
M.combat = false
M.FireEvent("PLAYER_REGEN_ENABLED")
H.check("apply again", P.applyButton:IsEnabled(), true)
H.check("undo still", P.undoButton:IsEnabled(), true)
RO.Close()
