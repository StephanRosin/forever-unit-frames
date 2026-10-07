local _, ns = ...

-- The raid frames' setup wizard: a small window that sets up the raid
-- frames in a few steps (role template, look, raid sizes, click-casting
-- suggestions, summary) and applies all of it as one change
-- (Raid/Templates.lua), which the General tab's Undo takes back. It opens
-- once by itself: the first time the raid window opens for a character
-- whose raid profile nobody has changed, after the login loading screen
-- (ForeverUnitFramesDB.raidWizardSeen[character] remembers it); at any
-- time from the General tab's button. Nothing is set before Apply, and
-- no click binding the user did not tick. Apply waits for the end of
-- combat (its button is off in combat).
local Wizard = {}
ns.RaidWizard = Wizard

local Style, Widgets, L = ns.Style, ns.Widgets, ns.L
local Templates, Page, RaidConfig, Raid = ns.RaidTemplates, ns.RaidTemplatesPage, ns.RaidConfig, ns.Raid

local WINDOW_NAME = "ForeverUnitFramesRaidWizard"
local WIDTH, HEIGHT, TITLE_H, FOOTER_H, INSET, GAP, BUTTON_W = 560, 400, 32, 40, 16, 8, 110
local TEXT_H, MAX_CLICKS = 48, 8
Wizard.STEPS = { "role", "look", "sizes", "clicks", "summary" }
local KEEP = "KEEP"

local frame
local loadingDone = false   -- the login loading screen is gone
local inCombat = false
-- The choices: role and look template ids (KEEP: none), the sizes ("SIZE"
-- or "ALL"), the size meant by "SIZE", the click suggestions and which
-- of them are ticked.
local choice = {}

-- Choices -----------------------------------------------------------------------------

local function resetChoices()
    choice = { role = Templates.SuggestRole(), look = KEEP, sizes = "SIZE",
        size = ns.RaidOptions.Size(), ticked = {} }
end

-- The click suggestions for the role picked, every one ticked at first.
local function suggestions()
    if choice.role == KEEP then return {} end
    return Templates.ClickSuggestions(choice.role, Templates.PlayerClass())
end

local function sizes()
    if choice.sizes == "ALL" then return Raid.SIZES end
    return { choice.size }
end

local function sizesText()
    if choice.sizes == "ALL" then return L.RAID_TEMPLATE_ALL end
    return Page.SizeText(choice.size)
end

local function tickedSuggestions()
    local list = {}
    for _, s in ipairs(suggestions()) do
        if choice.ticked[s.key] ~= false then list[#list + 1] = s end
    end
    return list
end

-- Everything Apply sets, as one change.
function Wizard.Changes()
    local parts = {}
    for _, id in ipairs({ choice.role, choice.look }) do
        if id ~= KEEP then parts[#parts + 1] = assert(Templates.Changes(Templates.Find(id), sizes())) end
    end
    parts[#parts + 1] = Templates.ClickChanges(tickedSuggestions())
    return Templates.Merge(parts)
end

-- The summary's lines.
function Wizard.SummaryLines()
    local lines = {}
    for _, id in ipairs({ choice.role, choice.look }) do
        if id ~= KEEP then
            lines[#lines + 1] = L.RAID_WIZARD_SUMMARY_TEMPLATE:format(Page.Title(Templates.Find(id)), sizesText())
        end
    end
    local clicks = #tickedSuggestions()
    if clicks > 0 then lines[#lines + 1] = L.RAID_WIZARD_SUMMARY_CLICKS:format(clicks) end
    if #lines == 0 then lines[1] = L.RAID_WIZARD_SUMMARY_NOTHING end
    return lines
end

-- Window -------------------------------------------------------------------------------

local function stepText(parent)
    local text = Style.Text(parent, 11, "muted")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", INSET, -6)
    text:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -INSET, -6)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    return text
end

local function placeRow(row, parent, index)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(TEXT_H + (index - 1) * Widgets.ROW_H))
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(TEXT_H + (index - 1) * Widgets.ROW_H))
    row:SetHeight(Widgets.ROW_H)
end

local function templateItems(list)
    local items = {}
    for _, t in ipairs(list) do items[#items + 1] = { value = t.id, text = Page.Title(t) } end
    items[#items + 1] = { value = KEEP, text = L.RAID_WIZARD_KEEP }
    return items
end

local function pickerPage(page, label, list, field)
    local row = Widgets.Dropdown(page, {
        label = label,
        items = function() return templateItems(list) end,
        get = function() return choice[field] end,
        set = function(v) choice[field] = v; if field == "role" then choice.ticked = {} end end,
    })
    placeRow(row, page, 1)
    return row
end

local function sizesPage(page)
    local row = Widgets.Dropdown(page, {
        label = L.RAID_TEMPLATE_TARGET,
        items = function()
            return { { value = "SIZE", text = L.RAID_TEMPLATE_THIS_SIZE:format(Page.SizeText(choice.size)) },
                { value = "ALL", text = L.RAID_TEMPLATE_ALL } }
        end,
        get = function() return choice.sizes end,
        set = function(v) choice.sizes = v end,
    })
    placeRow(row, page, 1)
    return row
end

-- A slot in words: its button's and its modifiers' ("Left button,
-- Shift-click").
local function slotText(key)
    local slot = Raid.CLICK_SLOT_BY_KEY[key]
    for _, b in ipairs(Raid.CLICK_BUTTONS) do
        if b.button == slot.button then
            return L.RAID_WIZARD_SLOT:format(ns.RaidSchema.SectionTitle("click" .. b.name), ns.RaidSchema.Label(key))
        end
    end
    return key
end

local function clickRows(page)
    local rows = {}
    for i = 1, MAX_CLICKS do
        local row
        row = Widgets.Checkbox(page, {
            label = "",
            get = function() return row.suggestion and choice.ticked[row.suggestion.key] ~= false end,
            set = function(on) choice.ticked[row.suggestion.key] = on end,
        })
        row.spell = Style.Text(row, 12, "text")
        row.spell:SetPoint("LEFT", row.box, "RIGHT", GAP, 0)
        placeRow(row, page, i)
        rows[i] = row
    end
    return rows
end

local function renderClicks()
    local list = suggestions()
    for i, row in ipairs(Wizard.clickRows) do
        local s = list[i]
        row.suggestion = s
        row:SetShown(s ~= nil)
        if s then
            row:SetLabel(slotText(s.key))
            row.spell:SetText(ns.RaidSchema.BindingText(s.binding, s.key))
            row:Refresh()
        end
    end
    Wizard.texts.clicks:SetText(#list > 0 and L.RAID_WIZARD_TEXT_clicks or L.RAID_WIZARD_TEXT_NO_CLICKS)
end

local function renderStep()
    local step = Wizard.STEPS[Wizard.step]
    for id, page in pairs(Wizard.pages) do page:SetShown(id == step) end
    frame.heading:SetText(L.RAID_WIZARD_STEP:format(Wizard.step, #Wizard.STEPS, L["RAID_WIZARD_STEP_" .. step]))
    if step == "role" then
        Wizard.texts.role:SetText(L.RAID_WIZARD_TEXT_role:format(Page.Title(Templates.Find(Templates.SuggestRole()))))
    elseif step == "clicks" then
        renderClicks()
    elseif step == "summary" then
        Wizard.summary:SetText(table.concat(Wizard.SummaryLines(), "\n"))
    end
    for _, row in ipairs({ Wizard.rolePicker, Wizard.lookPicker, Wizard.sizePicker }) do row:Refresh() end
    Wizard.backButton:SetEnabled(Wizard.step > 1)
    Wizard.nextButton:SetShown(step ~= "summary")
    Wizard.applyButton:SetShown(step == "summary")
    Wizard.applyButton:SetEnabled(not inCombat)
end

function Wizard.Next()
    if Wizard.step < #Wizard.STEPS then
        Widgets.CloseList()
        Wizard.step = Wizard.step + 1
        renderStep()
    end
end

function Wizard.Back()
    if Wizard.step > 1 then
        Widgets.CloseList()
        Wizard.step = Wizard.step - 1
        renderStep()
    end
end

-- Everything chosen, as one change; the window closes. False in combat.
function Wizard.Apply()
    if inCombat or not Templates.ApplyChanges(Wizard.Changes()) then return false end
    ns.Print(L.RAID_WIZARD_DONE)
    Wizard.Close()
    return true
end

local function button(parent, text, onClick)
    return Widgets.Button(parent, { text = text, width = BUTTON_W, onClick = onClick })
end

local function createFooter()
    local footer = CreateFrame("Frame", nil, frame)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    Wizard.cancelButton = button(footer, L.RAID_WIZARD_CANCEL, function() Wizard.Close() end)
    Wizard.cancelButton:SetPoint("LEFT", footer, "LEFT", INSET, 0)
    Wizard.nextButton = button(footer, L.RAID_WIZARD_NEXT, Wizard.Next)
    Wizard.nextButton:SetPoint("RIGHT", footer, "RIGHT", -INSET, 0)
    Wizard.applyButton = button(footer, L.RAID_TEMPLATE_APPLY, Wizard.Apply)
    Wizard.applyButton:SetPoint("RIGHT", footer, "RIGHT", -INSET, 0)
    Wizard.backButton = button(footer, L.RAID_WIZARD_BACK, Wizard.Back)
    Wizard.backButton:SetPoint("RIGHT", Wizard.nextButton, "LEFT", -GAP, 0)
    return footer
end

local function createPages(body)
    Wizard.pages, Wizard.texts = {}, {}
    for _, id in ipairs(Wizard.STEPS) do
        local page = CreateFrame("Frame", nil, body)
        page:SetAllPoints(body)
        Wizard.texts[id] = stepText(page)
        Wizard.pages[id] = page
    end
    Wizard.texts.look:SetText(L.RAID_WIZARD_TEXT_look)
    Wizard.texts.sizes:SetText(L.RAID_WIZARD_TEXT_sizes)
    Wizard.texts.summary:SetText(L.RAID_WIZARD_TEXT_summary)
    Wizard.rolePicker = pickerPage(Wizard.pages.role, L.RAID_WIZARD_ROLE, Templates.ROLES, "role")
    Wizard.lookPicker = pickerPage(Wizard.pages.look, L.RAID_WIZARD_LOOK, Templates.LOOKS, "look")
    Wizard.sizePicker = sizesPage(Wizard.pages.sizes)
    Wizard.clickRows = clickRows(Wizard.pages.clicks)
    local summary = Style.Text(Wizard.pages.summary, 12, "text")
    summary:SetPoint("TOPLEFT", Wizard.pages.summary, "TOPLEFT", INSET, -TEXT_H)
    summary:SetPoint("TOPRIGHT", Wizard.pages.summary, "TOPRIGHT", -INSET, -TEXT_H)
    summary:SetJustifyH("LEFT")
    summary:SetWordWrap(true)
    Wizard.summary = summary
end

local function createWindow()
    frame = CreateFrame("Frame", WINDOW_NAME, UIParent)
    Wizard.frame = frame
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetDontSavePosition(true)
    frame:EnableMouse(true)
    Style.Fill(frame, "bg")
    Style.Border(frame)
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    Style.Fill(bar, "panel")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local title = Style.Text(bar, 14, "text")
    title:SetPoint("LEFT", bar, "LEFT", INSET, 0)
    title:SetText(L.RAID_WIZARD_TITLE)
    frame.heading = Style.Text(frame, 12, "accent")
    frame.heading:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", INSET, -10)
    local footer = createFooter()
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -30)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
    createPages(body)
    frame:SetScript("OnHide", function() Widgets.CloseList() end)
    frame:Hide()
    for _, name in ipairs(UISpecialFrames) do
        if name == WINDOW_NAME then return end
    end
    table.insert(UISpecialFrames, WINDOW_NAME)
end

-- Public API -----------------------------------------------------------------------------

function Wizard.IsOpen()
    return frame ~= nil and frame:IsShown()
end

-- Opens at the first step with the suggested choices.
function Wizard.Open()
    if not RaidConfig.Profile() then return end
    if not frame then createWindow() end
    resetChoices()
    Wizard.step = 1
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:Show()
    renderStep()
end

function Wizard.Close()
    if frame then frame:Hide() end
end

-- Whether nobody has changed this character's raid profile.
function Wizard.Untouched()
    local profile = RaidConfig.Profile()
    if not profile then return false end
    for _, scope in ipairs(ns.RaidSettings.SCOPES) do
        if type(profile[scope]) == "table" and next(profile[scope]) ~= nil then return false end
    end
    return true
end

local function seenTable()
    local db = ForeverUnitFramesDB
    if type(db) ~= "table" then return nil end
    if type(db.raidWizardSeen) ~= "table" then db.raidWizardSeen = {} end
    return db.raidWizardSeen
end

-- The raid window opened: the wizard by itself, once per character, for
-- an untouched profile, after the login loading screen, out of combat.
function Wizard.MaybeOffer()
    if not loadingDone or inCombat or Wizard.IsOpen() or not Wizard.Untouched() then return end
    local seen = seenTable()
    if not seen then return end
    local key = ns.RaidProfiles.CharKey()
    if seen[key] then return end
    seen[key] = true
    Wizard.Open()
end

ns.Listen("RAID_WINDOW_OPENED", Wizard.MaybeOffer)
ns.On("LOADING_SCREEN_DISABLED", function() loadingDone = true end)
ns.On("PLAYER_REGEN_DISABLED", function()
    inCombat = true
    if Wizard.IsOpen() then renderStep() end
end)
ns.On("PLAYER_REGEN_ENABLED", function()
    inCombat = false
    if Wizard.IsOpen() then renderStep() end
end)
-- Every word is set when the window is built: a new language, a new one.
ns.Listen("LANGUAGE_CHANGED", function()
    if not frame then return end
    frame:Hide()
    frame, Wizard.frame = nil, nil
end)

-- The General tab's button (Raid/Options/Templates.lua).
Page.MORE_ROWS[#Page.MORE_ROWS + 1] = function(page)
    local row = Widgets.NewRow(page, { label = L.RAID_WIZARD_TITLE, hint = L.RAID_WIZARD_HINT })
    local b = Widgets.Button(row, { text = L.RAID_WIZARD_OPEN, width = BUTTON_W, onClick = Wizard.Open })
    b:SetPoint("LEFT", row, "LEFT", Widgets.CONTROL_X, 0)
    Page.wizardButton = b
    function row:Refresh() end
    function row:SetEnabled(on) b:SetEnabled(on) end
    return row
end
