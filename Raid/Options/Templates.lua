local _, ns = ...

-- The raid window's Profiles page, section Templates at its top (Raid/
-- Templates.lua; Raid/Options/Profiles.lua builds the page): pick a role
-- template or a look, apply it to the edited size or to all sizes, undo
-- the last change; open the setup wizard. Own templates (own profiles)
-- follow on the same page. Its rows lock in combat with the others
-- (Raid/Options/Window.lua).
local Page = {}
ns.RaidTemplatesPage = Page

local Style, Widgets, L = ns.Style, ns.Widgets, ns.L
local RaidOptions, Templates, Raid = ns.RaidOptions, ns.RaidTemplates, ns.Raid

local GAP, BUTTON_W = 8, 120

-- A template's name in the lists: its kind and its name.
function Page.Title(t)
    if t.kind == "role" then return L.RAID_TEMPLATE_ROLE:format(L["RAID_TEMPLATE_" .. t.id]) end
    if t.kind == "look" then return L.RAID_TEMPLATE_LOOK:format(L["RAID_TEMPLATE_" .. t.id]) end
    return L.RAID_TEMPLATE_OWN:format(t.name)
end

-- The shipped templates, as a dropdown's items: roles, looks.
function Page.Items()
    local items = {}
    for _, list in ipairs({ Templates.ROLES, Templates.LOOKS }) do
        for _, t in ipairs(list) do items[#items + 1] = { value = t.id, text = Page.Title(t) } end
    end
    return items
end

function Page.SizeText(size)
    return ns.RaidSchema.EnumText(ns.RaidSettings.Get("sizeMode"), tostring(size))
end

local picked          -- the picked template's id (nil: the suggested role)
local target = "SIZE" -- or "ALL"
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

-- The buttons as the state allows them: undo while there is something
-- to undo.
function Page.Refresh()
    if not Page.applyButton then return end
    local t = Templates.Find(pickedId())
    Page.picker:Refresh()
    Page.target:Refresh()
    Page.applyButton:SetEnabled(enabled and t ~= nil)
    Page.undoButton:SetEnabled(enabled and Templates.CanUndo())
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
        items = Page.Items,
        get = pickedId,
        set = function(v)
            picked = v
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

-- The rows other files add after the buttons (Raid/Wizard.lua: the
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
    for _, fn in ipairs(Page.MORE_ROWS) do stack.add(fn(page)) end
    stack.add(messageRow(page))
    say("")
    Page.Refresh()
end

ns.Listen("RAID_TEMPLATE_UNDO", function() Page.Refresh() end)
