local _, ns = ...

-- The raid window's General tab, section Templates (Raid/Templates.lua):
-- pick a role template, a look or an own template, apply it to the edited
-- size or to all sizes, undo the last change; save the edited size as an
-- own template, delete an own one; open the setup wizard. Its rows lock
-- in combat with the others (Raid/Options/Window.lua).
local Page = {}
ns.RaidTemplatesPage = Page

local Style, Widgets, L = ns.Style, ns.Widgets, ns.L
local RaidOptions, Templates, Raid = ns.RaidOptions, ns.RaidTemplates, ns.Raid

local GAP, BUTTON_W, NAME_W = 8, 120, 200

-- A template's name in the lists: its kind and its name.
function Page.Title(t)
    if t.kind == "role" then return L.RAID_TEMPLATE_ROLE:format(L["RAID_TEMPLATE_" .. t.id]) end
    if t.kind == "look" then return L.RAID_TEMPLATE_LOOK:format(L["RAID_TEMPLATE_" .. t.id]) end
    return L.RAID_TEMPLATE_OWN:format(t.name)
end

-- Every template, as a dropdown's items: roles, looks, own ones.
function Page.Items(withOwn)
    local items = {}
    for _, list in ipairs({ Templates.ROLES, Templates.LOOKS, withOwn and Templates.Own() or {} }) do
        for _, t in ipairs(list) do items[#items + 1] = { value = t.id, text = Page.Title(t) } end
    end
    return items
end

function Page.SizeText(size)
    return ns.RaidSchema.EnumText(ns.RaidSettings.Get("sizeMode"), tostring(size))
end

local picked          -- the picked template's id (nil: the suggested role)
local target = "SIZE" -- or "ALL"
local typedName = ""
local enabled = true

local function pickedId()
    if picked and Templates.Find(picked) then return picked end
    picked = nil
    return Templates.SuggestRole()
end

local function say(text, colorKey)
    Page.message:SetText(text)
    Style.Paint(Page.message, colorKey or "accent")
end

local function sizes()
    if target == "ALL" then return Raid.SIZES end
    return { RaidOptions.Size() }
end

local function apply()
    local t = Templates.Find(pickedId())
    if not t then return end
    if not Templates.Apply(t, sizes()) then return say(L.RAID_TEMPLATE_REFUSED, "error") end
    local where = target == "ALL" and L.RAID_TEMPLATE_ALL or Page.SizeText(RaidOptions.Size())
    say(L.RAID_TEMPLATE_APPLIED:format(Page.Title(t), where))
end

local function undo()
    if Templates.Undo() then say(L.RAID_TEMPLATE_UNDONE) end
end

local SAVE_WHY = {
    EMPTY = function() return L.RAID_TEMPLATE_NAME_EMPTY end,
    TOO_LONG = function() return L.RAID_TEMPLATE_NAME_TOO_LONG:format(Templates.OWN_NAME_LETTERS) end,
    FULL = function() return L.RAID_TEMPLATE_FULL:format(Templates.OWN_MAX) end,
}

local function save()
    Page.nameBox:ClearFocus()
    local name = (Page.nameBox:GetText() or ""):match("^%s*(.-)%s*$")
    local replacing = name ~= "" and Templates.Find("own:" .. name) ~= nil
    local ok, why = Templates.SaveOwn(name, RaidOptions.Size())
    if not ok then return say(SAVE_WHY[why](), "error") end
    typedName = ""
    Page.nameBox:SetText("")
    picked = "own:" .. name
    say((replacing and L.RAID_TEMPLATE_REPLACED or L.RAID_TEMPLATE_SAVED):format(name))
    Page.Refresh()
end

local function delete()
    local t = Templates.Find(pickedId())
    if t and Templates.DeleteOwn(t.id) then
        picked = nil
        say(L.RAID_TEMPLATE_DELETED:format(t.name))
        Page.Refresh()
    end
end

-- The buttons as the state allows them: undo while there is something
-- to undo, delete for an own template.
function Page.Refresh()
    if not Page.applyButton then return end
    local t = Templates.Find(pickedId())
    Page.picker:Refresh()
    Page.target:Refresh()
    Page.applyButton:SetEnabled(enabled and t ~= nil)
    Page.undoButton:SetEnabled(enabled and Templates.CanUndo())
    Page.deleteButton:SetEnabled(enabled and t ~= nil and t.kind == nil)
    Page.saveButton:SetEnabled(enabled)
    Page.nameBox:SetEnabled(enabled)
end

local function stateRow(row)
    function row:Refresh() Page.Refresh() end
    function row:SetEnabled(on)
        enabled = on
        Page.Refresh()
    end
    return row
end

local function pickerRow(page)
    local row = Widgets.Dropdown(page, {
        label = L.RAID_TEMPLATE_PICK, hint = L.RAID_TEMPLATE_PICK_HINT,
        items = function() return Page.Items(true) end,
        get = pickedId,
        set = function(v)
            picked = v
            Page.deleteButton.Disarm()
            say("")
            Page.Refresh()
        end,
    })
    local setEnabled = row.SetEnabled
    function row:SetEnabled(on) setEnabled(self, on); enabled = on; Page.Refresh() end
    return row
end

local function targetRow(page)
    return Widgets.Dropdown(page, {
        label = L.RAID_TEMPLATE_TARGET,
        items = function()
            return { { value = "SIZE", text = L.RAID_TEMPLATE_THIS_SIZE:format(Page.SizeText(RaidOptions.Size())) },
                { value = "ALL", text = L.RAID_TEMPLATE_ALL } }
        end,
        get = function() return target end,
        set = function(v) target = v end,
    })
end

local function buttonsRow(page)
    local row = stateRow(Widgets.NewRow(page, { label = "" }))
    Page.applyButton = Widgets.Button(row, { text = L.RAID_TEMPLATE_APPLY, width = BUTTON_W, onClick = apply })
    Page.applyButton:SetPoint("LEFT", row, "LEFT", Widgets.CONTROL_X, 0)
    Page.undoButton = Widgets.Button(row, { text = L.RAID_TEMPLATE_UNDO, width = BUTTON_W, onClick = undo })
    Page.undoButton:SetPoint("LEFT", Page.applyButton, "RIGHT", GAP, 0)
    Page.deleteButton = ns.Options.ConfirmButton(row, L.RAID_TEMPLATE_DELETE, delete)
    Page.deleteButton:SetPoint("LEFT", Page.undoButton, "RIGHT", GAP, 0)
    return row
end

local function saveRow(page)
    local row = stateRow(Widgets.NewRow(page, { label = L.RAID_TEMPLATE_SAVE_AS }))
    Page.nameBox = Widgets.TextBox(row, { width = NAME_W, maxLetters = Templates.OWN_NAME_LETTERS,
        get = function() return typedName end, set = function(text) typedName = text; return true end })
    -- A name in use asks first: a second click replaces that template.
    Page.saveButton = ns.Options.ConfirmButton(row, L.RAID_TEMPLATE_SAVE, save, nil, function()
        local name = (Page.nameBox:GetText() or ""):match("^%s*(.-)%s*$")
        return name ~= "" and Templates.Find("own:" .. name) ~= nil
    end)
    Page.saveButton:SetPoint("LEFT", Page.nameBox, "RIGHT", GAP, 0)
    return row
end

local function messageRow(page)
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(20)
    Page.message = Style.Text(row, 11, "accent")
    Page.message:SetPoint("LEFT", row, "LEFT", Widgets.CONTROL_X, 0)
    Page.message:SetJustifyH("LEFT")
    function row:Refresh() end
    function row:SetEnabled() end
    return row
end

-- The rows other files add after the save row (Raid/Wizard.lua: the
-- wizard's button): fn(page) returns a row.
Page.MORE_ROWS = {}

RaidOptions.EXTRA_SECTIONS.templates = function(page, stack)
    local header = Widgets.Header(page, ns.RaidSchema.SectionTitle("templates"))
    header.isSection = true
    stack.add(header)
    Page.picker = pickerRow(page)
    stack.add(Page.picker)
    Page.target = targetRow(page)
    stack.add(Page.target)
    stack.add(buttonsRow(page))
    stack.add(saveRow(page))
    for _, fn in ipairs(Page.MORE_ROWS) do stack.add(fn(page)) end
    stack.add(messageRow(page))
    say("")
    Page.Refresh()
end

ns.Listen("RAID_TEMPLATE_UNDO", function() Page.Refresh() end)
ns.Listen("RAID_TEMPLATES_CHANGED", function() Page.Refresh() end)
