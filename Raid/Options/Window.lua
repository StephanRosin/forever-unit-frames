local _, ns = ...

-- The raid options window, in the style of the unit frames' (the same
-- widgets and colours): a header bar with the raid size whose profile is
-- edited (the one shown now is marked) and which size the panel shows,
-- the tabs of the raid menu (Raid/Options/Schema.lua) and their rows. A
-- plain (non-secure) frame: every change goes through ns.RaidConfig,
-- whose RAID_CONFIG_CHANGED listeners restyle the raid panel out of
-- combat. In combat the window stays open but its controls lock.
local RaidOptions = {}
ns.RaidOptions = RaidOptions

local Style, Widgets, Schema, L = ns.Style, ns.Widgets, ns.RaidSchema, ns.L
local RaidConfig, Raid = ns.RaidConfig, ns.Raid

local WINDOW_NAME = "ForeverUnitFramesRaidOptions"
local WIDTH, HEIGHT = 780, 560
local TITLE_H, SIZE_BAR_H, TAB_H, FOOTER_H, NOTICE_H = 32, 40, 30, 40, 26
local SIZE_TAB_PADDING, TAB_PADDING, TAB_MIN_W, UNDERLINE_H, ACCENT_W = 24, 28, 70, 2, 3
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET, NOTE_H = 4, 16, 8, 16, 34
local BUTTON_H, DROPDOWN_W, GAP = 24, 160, 8
local DEFAULT_POSITION = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 90, y = -150 }

local frame
local pages = {}
local inCombat = false

-- Helpers ---------------------------------------------------------------------

local function line(parent, colorKey)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(unpack(Style.COLORS[colorKey]))
    return t
end

local function horizontalLine(parent, anchor)
    local t = line(parent, "border")
    t:SetHeight(1)
    t:SetPoint(anchor .. "LEFT"); t:SetPoint(anchor .. "RIGHT")
    return t
end

local function forEachRow(fn)
    for _, row in ipairs(RaidOptions.rows or {}) do fn(row) end
end

-- The size whose profile the window edits.
function RaidOptions.Size()
    return RaidOptions.size or ns.RaidSize.Current() or Raid.SIZES[1]
end

-- Where a setting lives: the character's, or the edited size's.
local function scopeOf(def)
    if def.scope == "general" then return "general" end
    return Raid.Scope(RaidOptions.Size())
end

local function sizeText(size) return Schema.EnumText(ns.RaidSettings.Get("sizeMode"), tostring(size)) end

-- Position (SavedVariables only, like the unit frames' window) -------------------

local function savedPosition()
    local pos = ForeverUnitFramesDB and ForeverUnitFramesDB.raidWindow
    if type(pos) == "table" and type(pos.point) == "string"
        and type(pos.x) == "number" and type(pos.y) == "number" then
        return pos
    end
    return DEFAULT_POSITION
end

local function restorePosition()
    local pos = savedPosition()
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
end

local function savePosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if not point then return end
    ForeverUnitFramesDB = ForeverUnitFramesDB or {}
    ForeverUnitFramesDB.raidWindow = { point = point, relativePoint = relativePoint or point, x = x, y = y }
end

-- Setting rows ------------------------------------------------------------------

-- What a typed text becomes before it is stored: class names to tokens,
-- spell names to the IDs of their ranks. nil refuses it.
local function typedValue(key)
    if key == "classOrder" then return Raid.ParseClassOrder end
    if key:match("^indicator%a+Spells$") then return ns.RaidSpellbook.Resolve end
    return nil
end

local function settingRow(parent, key)
    local def = ns.RaidSettings.Get(key)
    local convert = typedValue(key)
    local row = ns.Options.Control(parent, def, {
        label = Schema.Label(key), hint = Schema.Hint(key), enumText = Schema.EnumText,
        get = function() return RaidConfig.Get(scopeOf(def), key) end,
        set = function(v)
            if convert then v = convert(v) end
            if v == nil then return false end
            return RaidConfig.Set(scopeOf(def), key, v)
        end,
    })
    row.key = key
    return row
end

-- Pages -------------------------------------------------------------------------

local function newStack(page)
    local stack = { y = PAGE_TOP, rows = {} }
    function stack.add(row, height)
        if row.isSection and #stack.rows > 0 then stack.y = stack.y + SECTION_GAP end
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -stack.y)
        row:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -stack.y)
        row:SetHeight(height or row:GetHeight())
        stack.rows[#stack.rows + 1] = row
        stack.y = stack.y + row:GetHeight()
    end
    function stack.finish()
        page.rows, page.height = stack.rows, stack.y + PAGE_BOTTOM
    end
    return stack
end

-- A muted line of text above the sections, as wide as the page.
local function noteBlock(page, text)
    local block = CreateFrame("Frame", nil, page)
    block.text = Style.Text(block, 11, "muted")
    block.text:SetPoint("TOPLEFT", block, "TOPLEFT", INSET, -6)
    block.text:SetPoint("TOPRIGHT", block, "TOPRIGHT", -INSET, -6)
    block.text:SetJustifyH("LEFT")
    block.text:SetWordWrap(true)
    block.text:SetText(text)
    function block:Refresh() end
    function block:SetEnabled() end
    page.note = block.text
    return block
end

local function buildPage(page, tab)
    local stack = newStack(page)
    if tab.note then stack.add(noteBlock(page, Schema.Note(tab.note)), NOTE_H) end
    for _, section in ipairs(tab.sections) do
        local header = Widgets.Header(page, Schema.SectionTitle(section.id))
        header.isSection = true
        stack.add(header)
        for _, key in ipairs(section.keys) do stack.add(settingRow(page, key)) end
    end
    stack.finish()
end

-- One page per tab: the rows read the edited size when they refresh.
local function pageFor(tab)
    if pages[tab.id] then return pages[tab.id] end
    local page = CreateFrame("Frame", nil, frame.scrollChild)
    page:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, 0)
    page:SetWidth(CONTENT_W)
    buildPage(page, tab)
    page:SetHeight(page.height)
    page:Hide()
    pages[tab.id] = page
    return page
end

-- Scrolling ---------------------------------------------------------------------

local function updateScrollbar()
    local scroll, thumb = frame.scroll, frame.scrollThumb
    local range, view = scroll:GetVerticalScrollRange(), scroll:GetHeight()
    if range <= 0 or view <= 0 then thumb:Hide(); return end
    local thumbH = view * view / (view + range)
    thumb:SetHeight(thumbH)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", SCROLLBAR_W - 3, -(view - thumbH) * scroll:GetVerticalScroll() / range)
    thumb:Show()
end

local function onWheel(scroll, delta)
    local v = scroll:GetVerticalScroll() - delta * WHEEL_STEP
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange(), v)))
    updateScrollbar()
end

local function createScroll(body)
    local scroll = CreateFrame("ScrollFrame", nil, body)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", onWheel)
    scroll:SetScript("OnScrollRangeChanged", updateScrollbar)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(CONTENT_W, 1)
    scroll:SetScrollChild(child)
    local thumb = body:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(unpack(Style.COLORS.accent))
    thumb:SetWidth(2)
    thumb:Hide()
    frame.scroll, frame.scrollChild, frame.scrollThumb = scroll, child, thumb
end

-- Tabs: the raid sizes and the menu ------------------------------------------------

local function paintSelection(entry, selected, idleColor)
    Style.Paint(entry.text, selected and "accent" or idleColor)
    entry.selected = selected
end

local function hoverable(button, idleColor)
    button:SetScript("OnEnter", function(self)
        if not self.selected then Style.Paint(self.text, "text") end
    end)
    button:SetScript("OnLeave", function(self)
        if not self.selected then Style.Paint(self.text, idleColor) end
    end)
end

local function tabButton(parent, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(height)
    b.text = Style.Text(b, 12, "muted")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.underline = line(b, "accent")
    b.underline:SetHeight(UNDERLINE_H)
    b.underline:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 8, 0)
    b.underline:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 0)
    hoverable(b, "muted")
    return b
end

-- The sizes: the edited one underlined, the one shown now says so.
local function renderSizeTabs()
    local shown = ns.RaidSize.Current()
    for _, size in ipairs(Raid.SIZES) do
        local b = RaidOptions.sizeTabs[size]
        local text = sizeText(size)
        if size == shown then text = L.RAID_SIZE_SHOWN:format(text) end
        b.text:SetText(text)
        b:SetWidth((b.text:GetStringWidth() or 0) + SIZE_TAB_PADDING)
        paintSelection(b, size == RaidOptions.Size(), "muted")
        b.underline:SetShown(size == RaidOptions.Size())
    end
end

local function menuTabs()
    for i, tab in ipairs(Schema.TABS) do
        local b = tabButton(frame.tabRow, TAB_H)
        b.tabId = tab.id
        b.text:SetText(Schema.TabTitle(tab.id))
        b:SetWidth(math.max(TAB_MIN_W, (b.text:GetStringWidth() or 0) + TAB_PADDING))
        b:SetScript("OnClick", function(self) RaidOptions.SelectTab(self.tabId) end)
        local previous = RaidOptions.tabButtons[i - 1]
        if previous then
            b:SetPoint("LEFT", previous, "RIGHT", 0, 0)
        else
            b:SetPoint("LEFT", frame.tabRow, "LEFT", 8, 0)
        end
        RaidOptions.tabButtons[i] = b
    end
end

local function paintTabs()
    for _, b in ipairs(RaidOptions.tabButtons) do
        local selected = b.tabId == RaidOptions.currentTab
        paintSelection(b, selected, "muted")
        b.underline:SetShown(selected)
    end
end

-- Header bar ----------------------------------------------------------------------

-- A dropdown that is only its button: the size the panel shows.
local function sizeModeRow(bar)
    local def = ns.RaidSettings.Get("sizeMode")
    local row = ns.Options.Control(bar, def, {
        enumText = Schema.EnumText,
        get = function() return RaidConfig.Get("general", "sizeMode") end,
        set = function(v) return RaidConfig.Set("general", "sizeMode", v) end,
    })
    row:SetSize(DROPDOWN_W, BUTTON_H)
    row:EnableMouse(false)
    row.hover:SetAlpha(0)
    row.button:ClearAllPoints()
    row.button:SetAllPoints(row)
    row:SetPoint("RIGHT", bar, "RIGHT", -12, 0)
    local label = Style.Text(bar, 12, "muted")
    label:SetPoint("RIGHT", row, "LEFT", -GAP, 0)
    label:SetText(Schema.Label("sizeMode"))
    row:Refresh()
    return row
end

local function createSizeBar(parent, titleBar)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(SIZE_BAR_H)
    bar:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    Style.Fill(bar, "panel")
    horizontalLine(bar, "BOTTOM")
    RaidOptions.sizeTabs = {}
    local previous
    for _, size in ipairs(Raid.SIZES) do
        local b = tabButton(bar, SIZE_BAR_H)
        b:SetScript("OnClick", function() RaidOptions.SelectSize(size) end)
        if previous then b:SetPoint("LEFT", previous, "RIGHT", 0, 0) else b:SetPoint("LEFT", bar, "LEFT", 8, 0) end
        RaidOptions.sizeTabs[size] = b
        previous = b
    end
    RaidOptions.sizeModeRow = sizeModeRow(bar)
    frame.sizeBar = bar
end

-- Combat lock -------------------------------------------------------------------

local function anchorScroll()
    local top = inCombat and RaidOptions.combatNotice or frame.tabRow
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -SCROLLBAR_W, 0)
end

local function applyLock()
    local on = not inCombat
    forEachRow(function(row) row:SetEnabled(on) end)
    for _, control in ipairs(frame.lockedControls) do control:SetEnabled(on) end
    RaidOptions.combatNotice:SetShown(inCombat)
    anchorScroll()
end

-- Title bar, footer, body ---------------------------------------------------------

local CROSS_SIZE, CROSS_ANGLE = 14, math.pi / 4

local function closeButton(titleBar)
    local b = CreateFrame("Button", nil, titleBar)
    b:SetSize(TITLE_H, TITLE_H)
    b:SetPoint("RIGHT", titleBar, "RIGHT", 0, 0)
    b.lines = {}
    for i, angle in ipairs({ CROSS_ANGLE, -CROSS_ANGLE }) do
        local t = line(b, "muted")
        t:SetSize(CROSS_SIZE, 2)
        t:SetPoint("CENTER")
        t:SetRotation(angle)
        b.lines[i] = t
    end
    local function paint(colorKey)
        for _, t in ipairs(b.lines) do t:SetColorTexture(unpack(Style.COLORS[colorKey])) end
    end
    b:SetScript("OnEnter", function() paint("accent") end)
    b:SetScript("OnLeave", function() paint("muted") end)
    b:SetScript("OnClick", function() RaidOptions.Close() end)
    return b
end

local function createTitleBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    Style.Fill(bar, "panel")
    horizontalLine(bar, "BOTTOM")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePosition()
    end)
    local title = Style.Text(bar, 16, "text")
    title:SetPoint("LEFT", bar, "LEFT", INSET, 0)
    title:SetText(L.RAID_WINDOW_TITLE)
    local addon = Style.Text(bar, 11, "muted")
    addon:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
    addon:SetText(L.ADDON_NAME)
    bar.title, bar.close = title, closeButton(bar)
    return bar
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    frame.footer = footer
    return footer
end

local function createNotice(body)
    local notice = CreateFrame("Frame", nil, body)
    notice:SetHeight(NOTICE_H)
    notice:SetPoint("TOPLEFT", frame.tabRow, "BOTTOMLEFT", 0, 0)
    notice:SetPoint("TOPRIGHT", frame.tabRow, "BOTTOMRIGHT", 0, 0)
    local tint = notice:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints(notice)
    local a = Style.COLORS.accent
    tint:SetColorTexture(a[1], a[2], a[3], 0.12)
    local bar = line(notice, "accent")
    bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(ACCENT_W)
    local text = Style.Text(notice, 12, "accent")
    text:SetPoint("LEFT", notice, "LEFT", INSET, 0)
    text:SetText(L.COMBAT_LOCKED)
    notice:Hide()
    RaidOptions.combatNotice = notice
end

local function createBody(parent, top, footer)
    local body = CreateFrame("Frame", nil, parent)
    body:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
    frame.body = body
    local tabRow = CreateFrame("Frame", nil, body)
    tabRow:SetHeight(TAB_H)
    tabRow:SetPoint("TOPLEFT"); tabRow:SetPoint("TOPRIGHT")
    horizontalLine(tabRow, "BOTTOM")
    frame.tabRow = tabRow
    RaidOptions.tabButtons = {}
    menuTabs()
    createNotice(body)
    createScroll(body)
    anchorScroll()
end

-- Window ------------------------------------------------------------------------

local function createWindow()
    frame = CreateFrame("Frame", WINDOW_NAME, UIParent)
    RaidOptions.frame = frame
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetDontSavePosition(true)
    frame:EnableMouse(true)
    Style.Fill(frame, "bg")
    Style.Border(frame)
    frame.titleBar = createTitleBar(frame)
    createSizeBar(frame, frame.titleBar)
    local footer = createFooter(frame)
    createBody(frame, frame.sizeBar, footer)
    -- Locked in combat with the rows.
    frame.lockedControls = { RaidOptions.sizeModeRow }
    -- Hiding the window (ESC, close button, /fuf raid) takes an open
    -- dropdown list with it.
    frame:SetScript("OnHide", function() Widgets.CloseList() end)
    frame:Hide()
    for _, name in ipairs(UISpecialFrames) do
        if name == WINDOW_NAME then return end
    end
    table.insert(UISpecialFrames, WINDOW_NAME)
end

local function ensureWindow()
    if not frame then createWindow() end
end

local function refreshAll()
    forEachRow(function(row) row:Refresh() end)
    RaidOptions.sizeModeRow:Refresh()
    renderSizeTabs()
end

-- Public API ----------------------------------------------------------------------

function RaidOptions.IsOpen()
    return frame ~= nil and frame:IsShown()
end

function RaidOptions.SelectTab(id)
    ensureWindow()
    for _, tab in ipairs(Schema.TABS) do
        if tab.id == id then
            Widgets.CloseList()
            if RaidOptions.page then RaidOptions.page:Hide() end
            local page = pageFor(tab)
            RaidOptions.page, RaidOptions.currentTab, RaidOptions.rows = page, id, page.rows
            frame.scrollChild:SetHeight(page.height)
            frame.scroll:SetVerticalScroll(0)
            page:Show()
            forEachRow(function(row) row:Refresh() end)
            paintTabs()
            applyLock()
            updateScrollbar()
            return
        end
    end
end

-- Edits another size's profile: the rows read it from now on.
function RaidOptions.SelectSize(size)
    ensureWindow()
    Raid.Scope(size)
    Widgets.CloseList()
    RaidOptions.size = size
    refreshAll()
end

function RaidOptions.Open(size, tabId)
    if not RaidConfig.Profile() then return end
    ensureWindow()
    if InCombatLockdown() then inCombat = true end
    if not frame:IsShown() then
        restorePosition()
        frame:Show()
    end
    RaidOptions.SelectSize(size or RaidOptions.Size())
    RaidOptions.SelectTab(tabId or RaidOptions.currentTab or Schema.TABS[1].id)
end

function RaidOptions.Close()
    if frame then frame:Hide() end
end

function RaidOptions.Toggle()
    if RaidOptions.IsOpen() then RaidOptions.Close() else RaidOptions.Open() end
end

-- Live updates ----------------------------------------------------------------------

-- Values also change from outside the window: mover drags, Copy, Import,
-- another size becoming the one shown.
ns.Listen("RAID_CONFIG_CHANGED", function()
    if RaidOptions.IsOpen() then refreshAll() end
end)
ns.Listen("RAID_SIZE_CHANGED", function()
    if RaidOptions.IsOpen() then renderSizeTabs() end
end)

-- Every label is set once, when its widget is built: a new language gets a
-- new window (as the unit frames' window does), on the same size and tab.
function RaidOptions.Rebuild()
    if not frame then return end
    local wasOpen = frame:IsShown()
    frame:Hide()
    frame, RaidOptions.frame = nil, nil
    pages = {}
    RaidOptions.page, RaidOptions.rows = nil, nil
    if wasOpen then RaidOptions.Open(RaidOptions.size, RaidOptions.currentTab) end
end

ns.Listen("LANGUAGE_CHANGED", function() RaidOptions.Rebuild() end)

-- Tracked from the events rather than InCombatLockdown(): lockdown only
-- starts after PLAYER_REGEN_DISABLED has fired.
ns.On("PLAYER_REGEN_DISABLED", function()
    inCombat = true
    if frame then applyLock() end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    inCombat = false
    if frame then applyLock() end
end)
