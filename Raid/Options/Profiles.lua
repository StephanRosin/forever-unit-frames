local _, ns = ...

-- The raid window's Profiles page (the size bar's fourth tab, Raid/
-- Options/Window.lua): everything that acts on raid sizes as a whole.
-- First the templates and the setup wizard (Raid/Options/Templates.lua),
-- then own profiles (own templates, Raid/Templates.lua: all three sizes or one
-- size under a name, applied with Undo, replaced or deleted after a
-- second click); copy between sizes (everything, or without layout and
-- sizes) and from another character; reset a size; export all sizes or
-- one, and import either (a text of several sizes after a second click).
-- Changes that are one change with Undo: applying a profile, copying
-- between sizes, importing several sizes. Its rows lock in combat with
-- the window's.
local Page = {}
ns.RaidProfilesPage = Page

local Style, Widgets, L = ns.Style, ns.Widgets, ns.L
local RaidOptions, Templates, Profiles, Raid = ns.RaidOptions, ns.RaidTemplates, ns.RaidProfiles, ns.Raid

local GAP, BUTTON_W, NAME_W, MESSAGE_H, TEXT_AREA_H = 8, 120, 200, 20, 70
-- A message takes up to two lines (wrapped, then cut inside the page);
-- the pickers that list names are wider than the others.
local MESSAGE_LINES_H, WIDE_W = 28, 400
local NONE = "NONE"

local state = {}
local enabled = true
local exportFor   -- the export choice the export box's text was made for; nil: to make

local function sizeText(size) return ns.RaidTemplatesPage.SizeText(size) end

local function sizesText(sizes)
    local texts = {}
    for i, size in ipairs(sizes) do texts[i] = sizeText(size) end
    return table.concat(texts, ", ")
end

local function sizeItems(withAll)
    local items = {}
    if withAll then items[1] = { value = "ALL", text = L.RAID_PROFILES_ALL_SIZES } end
    for _, size in ipairs(Raid.SIZES) do items[#items + 1] = { value = size, text = sizeText(size) } end
    return items
end

-- A size picked on the page, the edited size until one is.
local function picked(field)
    return state[field] or RaidOptions.Size()
end

local function say(message, text, colorKey)
    message:SetText(text)
    Style.Paint(message, colorKey or "accent")
end

-- Rows ----------------------------------------------------------------------------

-- A row of the page's own. The lock only notes the state: the window
-- then refreshes the page once (page.afterLock).
local function ownRow(row)
    function row:Refresh() end
    function row:SetEnabled(on) enabled = on end
    return row
end

local function dropdown(page, opts)
    local row = Widgets.Dropdown(page, opts)
    local setEnabled = row.SetEnabled
    function row:SetEnabled(on) setEnabled(self, on); enabled = on end
    return row
end

local function messageRow(page)
    local row = CreateFrame("Frame", nil, page)
    row:SetHeight(MESSAGE_LINES_H)
    local message = Style.Text(row, 11, "accent")
    message:SetPoint("TOPLEFT", row, "TOPLEFT", Widgets.CONTROL_X, -2)
    message:SetPoint("TOPRIGHT", row, "TOPRIGHT", -RaidOptions.PAGE.inset, -2)
    message:SetHeight(MESSAGE_LINES_H - 2)
    message:SetJustifyH("LEFT")
    message:SetJustifyV("TOP")
    message:SetWordWrap(true)
    function row:Refresh() end
    function row:SetEnabled() end
    return row, message
end

local function button(row, text, onClick, anchor)
    local b = Widgets.Button(row, { text = text, width = BUTTON_W, onClick = onClick })
    if anchor then b:SetPoint("LEFT", anchor, "RIGHT", GAP, 0) else b:SetPoint("LEFT", row, "LEFT", Widgets.CONTROL_X, 0) end
    return b
end

local function confirmButton(row, text, action, anchor, needed)
    local b = ns.Options.ConfirmButton(row, text, action, nil, needed)
    if anchor then b:SetPoint("LEFT", anchor, "RIGHT", GAP, 0) else b:SetPoint("LEFT", row, "LEFT", Widgets.CONTROL_X, 0) end
    return b
end

local function header(page, stack, text)
    local h = Widgets.Header(page, text)
    h.isSection = true
    stack.add(h)
end

-- Own profiles ----------------------------------------------------------------------

-- An own profile's name in the list: its name and what it holds.
function Page.Title(t)
    return (Templates.Held(t) and L.RAID_PROFILES_OWN_ALL or L.RAID_PROFILES_OWN_ONE):format(t.name)
end

local function pickedId()
    if state.own and Templates.Find(state.own) then return state.own end
    state.own = nil
    local first = Templates.Own()[1]
    return first and first.id or NONE
end

local function pickedTemplate()
    local id = pickedId()
    return id ~= NONE and Templates.Find(id) or nil
end

local function ownItems()
    local items = {}
    for _, t in ipairs(Templates.Own()) do items[#items + 1] = { value = t.id, text = Page.Title(t) } end
    if #items == 0 then items[1] = { value = NONE, text = L.RAID_PROFILES_NONE } end
    return items
end

local function applyOwn()
    local t = pickedTemplate()
    if not t then return end
    local held, where = Templates.Held(t)
    local sizes
    if held then
        sizes, where = held, sizesText(held)
    elseif picked("target") == "ALL" then
        sizes, where = Raid.SIZES, L.RAID_TEMPLATE_ALL
    else
        sizes, where = { picked("target") }, sizeText(picked("target"))
    end
    if not Templates.Apply(t, sizes) then return say(Page.ownMessage, L.RAID_TEMPLATE_REFUSED, "error") end
    say(Page.ownMessage, L.RAID_TEMPLATE_APPLIED:format(t.name, where))
end

local function undo(message)
    return function()
        if Templates.Undo() then say(message, L.RAID_TEMPLATE_UNDONE) end
    end
end

local function deleteOwn()
    local t = pickedTemplate()
    if t and Templates.DeleteOwn(t.id) then
        state.own = nil
        say(Page.ownMessage, L.RAID_TEMPLATE_DELETED:format(t.name))
        Page.Refresh()
    end
end

local SAVE_WHY = {
    EMPTY = function() return L.RAID_TEMPLATE_NAME_EMPTY end,
    TOO_LONG = function() return L.RAID_TEMPLATE_NAME_TOO_LONG:format(Templates.OWN_NAME_LETTERS) end,
    FULL = function() return L.RAID_TEMPLATE_FULL:format(Templates.OWN_MAX) end,
}

local function typedName()
    return (Page.nameBox:GetText() or ""):match("^%s*(.-)%s*$")
end

local function saveOwn()
    Page.nameBox:ClearFocus()
    local name = typedName()
    local replacing = Templates.OwnExists(name)
    local ok, why = Templates.SaveOwn(name, state.saveWhat or "ALL")
    if not ok then return say(Page.ownMessage, SAVE_WHY[why](), "error") end
    state.typed = ""
    Page.nameBox:SetText("")
    state.own = "own:" .. name
    say(Page.ownMessage, (replacing and L.RAID_TEMPLATE_REPLACED or L.RAID_TEMPLATE_SAVED):format(name))
    Page.Refresh()
end

local function ownSection(page, stack)
    header(page, stack, L.RAID_PROFILES_SECTION_OWN)
    Page.picker = dropdown(page, {
        label = L.RAID_PROFILES_PICK, items = ownItems, get = pickedId, width = WIDE_W,
        set = function(v)
            if v ~= NONE then state.own = v end
            Page.deleteButton.Disarm()
            say(Page.ownMessage, "")
            Page.Refresh()
        end,
    })
    stack.add(Page.picker)
    Page.target = dropdown(page, {
        label = L.RAID_TEMPLATE_TARGET,
        items = function()
            local t = pickedTemplate()
            if t and Templates.Held(t) then return { { value = "HELD", text = L.RAID_PROFILES_EACH_SIZE } } end
            return sizeItems(true)
        end,
        get = function()
            local t = pickedTemplate()
            if t and Templates.Held(t) then return "HELD" end
            return picked("target")
        end,
        set = function(v) state.target = v end,
    })
    stack.add(Page.target)
    local row = ownRow(Widgets.NewRow(page, { label = "" }))
    Page.applyButton = button(row, L.RAID_TEMPLATE_APPLY, applyOwn)
    Page.undoButton = button(row, L.RAID_TEMPLATE_UNDO, function() undo(Page.ownMessage)() end, Page.applyButton)
    Page.deleteButton = confirmButton(row, L.RAID_TEMPLATE_DELETE, deleteOwn, Page.undoButton)
    stack.add(row)
    Page.saveWhat = dropdown(page, {
        label = L.RAID_PROFILES_SAVE_WHAT, items = function() return sizeItems(true) end,
        get = function() return state.saveWhat or "ALL" end,
        set = function(v) state.saveWhat = v end,
    })
    stack.add(Page.saveWhat)
    local save = ownRow(Widgets.NewRow(page, { label = L.RAID_PROFILES_SAVE_AS }))
    Page.nameBox = Widgets.TextBox(save, { width = NAME_W, maxLetters = Templates.OWN_NAME_LETTERS,
        get = function() return state.typed or "" end, set = function(text) state.typed = text; return true end })
    -- A name in use asks first: a second click replaces that profile.
    Page.saveButton = confirmButton(save, L.RAID_TEMPLATE_SAVE, saveOwn, Page.nameBox,
        function() return Templates.OwnExists(typedName()) end)
    stack.add(save)
    local messageRow_, message = messageRow(page)
    Page.ownMessage = message
    stack.add(messageRow_)
end

-- Copy between sizes, from a character, reset ----------------------------------------

-- Why a copy did not happen, as the page says it.
local COPY_WHY = {
    GONE = function() return L.RAID_PROFILES_COPY_GONE end,
    COMBAT = function() return L.IMPORT_RAID_COMBAT end,
    REFUSED = function() return L.RAID_PROFILES_COPY_REFUSED end,
}

local function copySizes()
    local from, to = state.copyFrom, picked("copyTo")
    if not from then
        for _, size in ipairs(Raid.SIZES) do
            if size ~= to then from = size; break end
        end
    end
    return from, to
end

local function copyBetween()
    local from, to = copySizes()
    if from == to then return say(Page.copyMessage, L.RAID_PROFILES_SAME_SIZE, "error") end
    if not Profiles.CopySizeMode(from, to, state.copyMode or "ALL") then
        return say(Page.copyMessage, COPY_WHY[InCombatLockdown() and "COMBAT" or "REFUSED"](), "error")
    end
    say(Page.copyMessage, L.RAID_PROFILES_COPIED:format(sizeText(from), sizeText(to)))
end

local function copySection(page, stack)
    header(page, stack, L.RAID_PROFILES_SECTION_COPY)
    Page.copyFrom = dropdown(page, {
        label = L.RAID_PROFILES_FROM, items = function() return sizeItems(false) end,
        get = function() return (copySizes()) end, set = function(v) state.copyFrom = v end,
    })
    stack.add(Page.copyFrom)
    Page.copyTo = dropdown(page, {
        label = L.RAID_PROFILES_TO, items = function() return sizeItems(false) end,
        get = function() return picked("copyTo") end, set = function(v) state.copyTo = v end,
    })
    stack.add(Page.copyTo)
    Page.copyMode = dropdown(page, {
        label = L.RAID_PROFILES_MODE, hint = L.RAID_PROFILES_MODE_HINT,
        items = function()
            return { { value = "ALL", text = L.RAID_PROFILES_MODE_ALL },
                { value = "BEHAVIOUR", text = L.RAID_PROFILES_MODE_BEHAVIOUR } }
        end,
        get = function() return state.copyMode or "ALL" end, set = function(v) state.copyMode = v end,
    })
    stack.add(Page.copyMode)
    local row = ownRow(Widgets.NewRow(page, { label = "" }))
    Page.copyButton = button(row, L.RAID_PROFILES_COPY, copyBetween)
    Page.copyUndoButton = button(row, L.RAID_TEMPLATE_UNDO, function() undo(Page.copyMessage)() end, Page.copyButton)
    stack.add(row)
    local messageRow_, message = messageRow(page)
    Page.copyMessage = message
    stack.add(messageRow_)
end

local function characterItems()
    local items = {}
    for _, key in ipairs(Profiles.Characters()) do
        for _, size in ipairs(Raid.SIZES) do
            items[#items + 1] = { value = key .. ":" .. size, text = L.RAID_COPY_CHARACTER:format(key, sizeText(size)) }
        end
    end
    if #items == 0 then items[1] = { value = NONE, text = L.RAID_PROFILES_NO_CHARACTERS } end
    return items
end

local function characterSource()
    local items = characterItems()
    for _, item in ipairs(items) do
        if item.value == state.character then return state.character end
    end
    return items[1].value
end

local function copyCharacter()
    local key, from = characterSource():match("^(.+):(%d+)$")
    if not key then return say(Page.characterMessage, COPY_WHY.GONE(), "error") end
    local to = picked("characterTo")
    local ok, why = Profiles.CopyFromCharacter(key, tonumber(from), to)
    if not ok then return say(Page.characterMessage, COPY_WHY[why](), "error") end
    say(Page.characterMessage, L.RAID_PROFILES_COPIED:format(L.RAID_COPY_CHARACTER:format(key,
        sizeText(tonumber(from))), sizeText(to)))
end

local function characterSection(page, stack)
    header(page, stack, L.RAID_PROFILES_SECTION_CHARACTER)
    Page.character = dropdown(page, {
        label = L.RAID_PROFILES_CHARACTER, items = characterItems, get = characterSource, width = WIDE_W,
        set = function(v) if v ~= NONE then state.character = v end; Page.characterButton.Disarm() end,
    })
    stack.add(Page.character)
    Page.characterTo = dropdown(page, {
        label = L.RAID_PROFILES_TO, items = function() return sizeItems(false) end,
        get = function() return picked("characterTo") end,
        set = function(v) state.characterTo = v; Page.characterButton.Disarm() end,
    })
    stack.add(Page.characterTo)
    local row = ownRow(Widgets.NewRow(page, { label = "" }))
    Page.characterButton = confirmButton(row, L.RAID_PROFILES_COPY, copyCharacter)
    Page.characterUndoButton = button(row, L.RAID_TEMPLATE_UNDO, function() undo(Page.characterMessage)() end,
        Page.characterButton)
    stack.add(row)
    local messageRow_, message = messageRow(page)
    Page.characterMessage = message
    stack.add(messageRow_)
end

local function resetSection(page, stack)
    header(page, stack, L.RAID_PROFILES_SECTION_RESET)
    Page.resetSize = dropdown(page, {
        label = L.RAID_PROFILES_RESET_SIZE, items = function() return sizeItems(false) end,
        get = function() return picked("reset") end,
        set = function(v) state.reset = v; Page.resetButton.Disarm() end,
    })
    Page.resetButton = confirmButton(Page.resetSize, L.RAID_PROFILES_RESET, function()
        local size = picked("reset")
        Profiles.ResetSize(size)
        say(Page.resetMessage, L.RAID_PROFILES_RESET_DONE:format(sizeText(size)))
    end, Page.resetSize.button)
    stack.add(Page.resetSize)
    local messageRow_, message = messageRow(page)
    Page.resetMessage = message
    stack.add(messageRow_)
end

-- Export and import ---------------------------------------------------------------

local function newBlock(page)
    local block = CreateFrame("Frame", nil, page)
    function block:Refresh() end
    function block:SetEnabled() end
    return block
end

local function hintAndArea(block, readOnly)
    local inset = RaidOptions.PAGE.inset
    local hint = Style.Text(block, 11, "muted")
    hint:SetPoint("TOPLEFT", block, "TOPLEFT", inset, -4)
    hint:SetPoint("TOPRIGHT", block, "TOPRIGHT", -inset, -4)
    hint:SetJustifyH("LEFT")
    local area = Widgets.TextArea(block, { width = RaidOptions.PAGE.width - 2 * inset, height = TEXT_AREA_H,
        readOnly = readOnly })
    area:SetPoint("TOPLEFT", block, "TOPLEFT", inset, -(MESSAGE_H + 2))
    return hint, area
end

local function exportWhat() return state.export or "ALL" end

local function exportSection(page, stack)
    header(page, stack, L.EXPORT)
    Page.exportWhat = dropdown(page, {
        label = L.RAID_PROFILES_EXPORT_WHAT, items = function() return sizeItems(true) end,
        get = exportWhat, set = function(v) state.export = v; Page.Refresh() end,
    })
    stack.add(Page.exportWhat)
    local block = newBlock(page)
    local hint, area = hintAndArea(block, true)
    -- The text is made only while the box shows, and again only for
    -- another choice or a changed profile (exportFor: what it was made for).
    function block:Refresh()
        local what = exportWhat()
        hint:SetText(what == "ALL" and L.RAID_EXPORT_ALL_HINT or L.RAID_EXPORT_HINT:format(sizeText(what)))
        if exportFor == what or not block:IsVisible() then return end
        exportFor = what
        area:SetText(what == "ALL" and Profiles.ExportAll() or Profiles.Export(what))
    end
    Page.exportHint, Page.exportArea, Page.exportBlock = hint, area, block
    stack.add(block, MESSAGE_H + TEXT_AREA_H + 10)
end

local function importText()
    return (Page.importArea:GetText() or ""):match("^%s*(.-)%s*$")
end

-- A text of several sizes asks first (the message names them).
local function importNeedsConfirm()
    local sizes = Profiles.ImportSizes(importText())
    if not sizes or #sizes < 2 then return false end
    say(Page.importMessage, L.RAID_IMPORT_ALL_ASK:format(sizesText(sizes)), "error")
    return true
end

local function runImport()
    local text = importText()
    local sizes = Profiles.ImportSizes(text)
    local ok, result, done
    if sizes and #sizes > 1 then
        ok, result, done = Profiles.ImportAll(text)
    else
        ok, result = Profiles.Import(text, picked("importTo"))
    end
    if not ok then return say(Page.importMessage, L["IMPORT_" .. result], "error") end
    Page.importArea:SetText("")
    local text_
    if done then
        text_ = L.RAID_IMPORT_ALL_DONE:format(sizesText(done))
    else
        text_ = L.IMPORT_DONE
    end
    if result > 0 then
        text_ = done and L.RAID_IMPORT_ALL_SKIPPED:format(sizesText(done), result) or L.IMPORT_SKIPPED:format(result)
    end
    say(Page.importMessage, text_)
end

local function importSection(page, stack)
    header(page, stack, L.IMPORT)
    Page.importTo = dropdown(page, {
        label = L.RAID_PROFILES_IMPORT_TO, items = function() return sizeItems(false) end,
        get = function() return picked("importTo") end,
        set = function(v) state.importTo = v; Page.Refresh() end,
    })
    stack.add(Page.importTo)
    local block = newBlock(page)
    local hint, area = hintAndArea(block, false)
    -- Its question goes when it disarms; another text disarms it (the
    -- question was about the text before).
    local b = ns.Options.ConfirmButton(block, L.IMPORT, runImport, nil, importNeedsConfirm,
        function() say(Page.importMessage, "") end)
    area.edit:HookScript("OnTextChanged", function(_, userInput) if userInput then b.Disarm() end end)
    b:SetPoint("TOPLEFT", area, "BOTTOMLEFT", 0, -GAP)
    local message = Style.Text(block, 11, "muted")
    message:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -6)
    message:SetPoint("TOPRIGHT", area, "BOTTOMRIGHT", 0, -(GAP + b:GetHeight() + 6))
    message:SetHeight(MESSAGE_LINES_H - 2)
    message:SetJustifyH("LEFT")
    message:SetJustifyV("TOP")
    message:SetWordWrap(true)
    function block:Refresh() hint:SetText(L.RAID_IMPORT_ANY_HINT:format(sizeText(picked("importTo")))) end
    function block:SetEnabled(on) b:SetEnabled(on); area.edit:SetEnabled(on) end
    Page.importHint, Page.importArea, Page.importButton, Page.importMessage = hint, area, b, message
    Page.importBlock = block
    stack.add(block, MESSAGE_H + 2 + TEXT_AREA_H + GAP + b:GetHeight() + 6 + MESSAGE_LINES_H)
end

-- Page --------------------------------------------------------------------------------

-- The buttons as the state allows them; the dropdowns read the state.
function Page.Refresh()
    if not Page.applyButton then return end
    local t = pickedTemplate()
    for _, row in ipairs({ Page.picker, Page.target, Page.saveWhat, Page.copyFrom, Page.copyTo, Page.copyMode,
        Page.character, Page.characterTo, Page.resetSize, Page.exportWhat, Page.importTo, Page.exportBlock,
        Page.importBlock }) do
        row:Refresh()
    end
    Page.target.button:SetEnabled(enabled and t ~= nil and not Templates.Held(t))
    Page.applyButton:SetEnabled(enabled and t ~= nil)
    Page.deleteButton:SetEnabled(enabled and t ~= nil)
    Page.undoButton:SetEnabled(enabled and Templates.CanUndo())
    Page.copyUndoButton:SetEnabled(enabled and Templates.CanUndo())
    Page.characterUndoButton:SetEnabled(enabled and Templates.CanUndo())
    Page.saveButton:SetEnabled(enabled)
    Page.nameBox:SetEnabled(enabled)
    Page.copyButton:SetEnabled(enabled)
    Page.characterButton:SetEnabled(enabled and #Profiles.Characters() > 0)
    Page.resetButton:SetEnabled(enabled)
end

local function disarm()
    if not Page.applyButton then return end
    for _, b in ipairs({ Page.deleteButton, Page.saveButton, Page.characterButton, Page.resetButton,
        Page.importButton }) do
        b.Disarm()
    end
end
RaidOptions.DISARM[#RaidOptions.DISARM + 1] = disarm

RaidOptions.CUSTOM_PAGES.profiles = function(page)
    local stack = RaidOptions.NewStack(page)
    -- The role templates, the looks and the setup wizard first
    -- (Raid/Options/Templates.lua).
    RaidOptions.EXTRA_SECTIONS.templates(page, stack)
    ownSection(page, stack)
    copySection(page, stack)
    characterSection(page, stack)
    resetSection(page, stack)
    exportSection(page, stack)
    importSection(page, stack)
    stack.finish()
    exportFor = nil
    page.afterLock = function() Page.Refresh() end
    -- Shown again: what it said before is gone.
    page.onShow = function()
        for _, message in ipairs({ Page.ownMessage, Page.copyMessage, Page.characterMessage, Page.resetMessage,
            Page.importMessage }) do
            say(message, "")
        end
    end
    Page.Refresh()
end

ns.Listen("RAID_TEMPLATE_UNDO", function() Page.Refresh() end)
ns.Listen("RAID_TEMPLATES_CHANGED", function() Page.Refresh() end)
-- The profile changed: the export text is made again (now if it shows).
ns.Listen("RAID_CONFIG_CHANGED", function()
    exportFor = nil
    if Page.exportBlock then Page.exportBlock:Refresh() end
end)
