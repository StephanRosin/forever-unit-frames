local _, ns = ...

-- The raid options window, in the style of the unit frames' (the same
-- widgets and colours): a header bar with the raid size whose profile is
-- edited (the one shown now is marked) and which size the panel shows,
-- the tabs of the raid menu (Raid/Options/Schema.lua) and their rows, the
-- last one (Profile) the export and import of the edited size; a footer
-- laid out like the unit frames' window's: on the left the raid panel's
-- lock, test mode and the way to the unit frames' window, on the right
-- what acts on the edited size as a whole: copy from another size or
-- character, reset it. A plain
-- (non-secure) frame: every change goes through ns.RaidConfig, whose
-- RAID_CONFIG_CHANGED listeners restyle the raid panel out of combat. In
-- combat the window stays open but its controls lock.
local RaidOptions = {}
ns.RaidOptions = RaidOptions

local Style, Widgets, Schema, L = ns.Style, ns.Widgets, ns.RaidSchema, ns.L
local RaidConfig, Raid = ns.RaidConfig, ns.Raid

local WINDOW_NAME = "ForeverUnitFramesRaidOptions"
local WIDTH, HEIGHT = 1060, 560
local TITLE_H, SIZE_BAR_H, TAB_H, FOOTER_H, NOTICE_H, SIZE_NOTICE_H = 32, 40, 30, 40, 26, 36
local SIZE_TAB_PADDING, TAB_PADDING, TAB_MIN_W, UNDERLINE_H, ACCENT_W = 24, 28, 70, 2, 3
local TAB_ROW_INSET, TAB_MIN_PADDING = 8, 12
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET, NOTE_H = 4, 16, 8, 16, 34
local BUTTON_H, BUTTON_W, DROPDOWN_W, GAP, WIDE_BUTTON_W, FOOTER_INSET = 24, 120, 160, 8, 160, 12
local TEXT_AREA_H, MESSAGE_H, CONFIRM_SECONDS = 70, 20, 3
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
-- spell names to the IDs of their ranks, a name list to "Ann, Bob". nil
-- and why (for the chat) refuses it: an unknown class or one named twice,
-- a spell name the spell book does not know, more spell IDs than the
-- setting can hold, something that is no name, a name given twice, more
-- names than the list can hold.
local function classOrder(text)
    local tokens, problem, word = Raid.ParseClassOrder(text)
    if tokens then return tokens end
    return nil, (problem == "TWICE" and L.RAID_TYPED_CLASS_TWICE or L.RAID_TYPED_CLASS_UNKNOWN):format(word)
end

local function spellList(text)
    local ids, word = ns.RaidSpellbook.Resolve(text)
    if not ids then return nil, L.RAID_TYPED_SPELL_UNKNOWN:format(word) end
    if #ids > Raid.SPELL_LIST_LETTERS then return nil, L.RAID_TYPED_TOO_LONG:format(Raid.SPELL_LIST_LETTERS) end
    return ids
end

local function nameList(text)
    local names, problem, word = Raid.ParseNameList(text)
    if not names then
        return nil, (problem == "TWICE" and L.RAID_TYPED_NAME_TWICE or L.RAID_TYPED_NAME_INVALID):format(word)
    end
    local stored = table.concat(names, ", ")
    if #stored > Raid.NAME_LIST_LETTERS then return nil, L.RAID_TYPED_NAMES_TOO_LONG:format(Raid.NAME_LIST_LETTERS) end
    return stored
end

local function typedValue(key)
    if key == "classOrder" then return classOrder end
    if key:match("^indicator%a+Spells$") then return spellList end
    if ns.RaidSettings.Get(key).names then return nameList end
    return nil
end

-- A panel's position (the main panel's or a special panel's): a number
-- with - / + buttons (a slider across the whole range would move the
-- panel ~40 units per pixel); Shift steps by the movers' grid. A value
-- beyond the screen is stored as the edge that panel stops at
-- (Raid/Panel.lua: Reachable).
local function positionRow(parent, def, opts, panel, axis)
    opts.min, opts.max, opts.step, opts.bigStep = def.min, def.max, 1, ns.Movers.GRID
    local set = opts.set
    opts.set = function(v)
        local shown = RaidOptions.Size() == ns.RaidCell.Size()
        return set(panel.Reachable(axis, v, shown))
    end
    return Widgets.Stepper(parent, opts)
end

-- A row for a raid setting of the edited size (or the character's);
-- store (optional) stores a value in its place (returns whether it did).
local function settingRow(parent, key, store)
    local def = ns.RaidSettings.Get(key)
    local convert = typedValue(key)
    store = store or function(v) return RaidConfig.Set(scopeOf(def), key, v) end
    local opts = {
        label = Schema.Label(key), hint = Schema.Hint(key), enumText = Schema.EnumText,
        get = function() return RaidConfig.Get(scopeOf(def), key) end,
        set = function(v)
            if convert then
                local converted, why = convert(v)
                if converted == nil then
                    ns.Print(why)
                    return false
                end
                v = converted
            end
            return store(v)
        end,
    }
    local row
    local panel, axis = ns.RaidPanel.ByPositionKey(key)
    if panel then row = positionRow(parent, def, opts, panel, axis) else row = ns.Options.Control(parent, def, opts) end
    row.key = key
    return row
end
RaidOptions.SettingRow = settingRow

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
RaidOptions.NoteBlock = noteBlock
-- The page's measures, for a page built elsewhere (Raid/Options/Arrangement.lua).
RaidOptions.PAGE = { width = CONTENT_W, inset = INSET, top = PAGE_TOP, bottom = PAGE_BOTTOM,
    sectionGap = SECTION_GAP, noteHeight = NOTE_H, gap = GAP }

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

-- The builders of the window's own pages by tab.custom: (page, tab),
-- setting page.rows and page.height. The Arrangement tab's is
-- Raid/Options/Arrangement.lua's.
RaidOptions.CUSTOM_PAGES = {}

-- One page per tab: the rows read the edited size when they refresh.
local function pageFor(tab)
    if pages[tab.id] then return pages[tab.id] end
    local page = CreateFrame("Frame", nil, frame.scrollChild)
    page:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, 0)
    page:SetWidth(CONTENT_W)
    local build = RaidOptions.CUSTOM_PAGES[tab.custom] or buildPage
    build(page, tab)
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

-- A page that changed its height (one whose rows come and go): the
-- scroll range follows while it is shown, and a scroll beyond the new
-- range moves back to its end.
function RaidOptions.PageResized(page)
    page:SetHeight(page.height)
    if not frame or RaidOptions.page ~= page then return end
    frame.scrollChild:SetHeight(page.height)
    local scroll = frame.scroll
    scroll:UpdateScrollChildRect()
    local range = math.max(0, scroll:GetVerticalScrollRange())
    if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
    updateScrollbar()
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

local anchorScroll

-- Edited values of a size the panel does not show change nothing on
-- screen: the note says so (test mode would show the edited size).
local function renderSizeNotice()
    local edited, shown = RaidOptions.Size(), ns.RaidCell.Size()
    local notice = RaidOptions.sizeNotice
    local on = edited ~= shown
    if on then notice.text:SetText(L.RAID_EDITING_NOT_SHOWN:format(edited, shown)) end
    if on == notice:IsShown() then return end
    notice:SetShown(on)
    anchorScroll()
end

-- The sizes: the edited one underlined, the one the panel shows now
-- (test mode's preview included) says so; the note on a size not shown.
local function renderSizeTabs()
    local shown = ns.RaidCell.Size()
    for _, size in ipairs(Raid.SIZES) do
        local b = RaidOptions.sizeTabs[size]
        local text = sizeText(size)
        if size == shown then text = L.RAID_SIZE_SHOWN:format(text) end
        b.text:SetText(text)
        b:SetWidth((b.text:GetStringWidth() or 0) + SIZE_TAB_PADDING)
        paintSelection(b, size == RaidOptions.Size(), "muted")
        b.underline:SetShown(size == RaidOptions.Size())
    end
    renderSizeNotice()
end

-- The tabs share the row: each as wide as its word and the padding, at
-- least TAB_MIN_W; when that does not fit (more tabs, longer words), every
-- tab gets its word and an equal share of what is left, at least
-- TAB_MIN_PADDING.
local function fitTabs()
    local buttons, words, total, letters = RaidOptions.tabButtons, {}, 0, 0
    for i, b in ipairs(buttons) do
        words[i] = b.text:GetStringWidth() or 0
        total = total + math.max(TAB_MIN_W, words[i] + TAB_PADDING)
        letters = letters + words[i]
    end
    local room = WIDTH - 2 * TAB_ROW_INSET
    local padding
    if total > room then padding = math.max(TAB_MIN_PADDING, math.floor((room - letters) / #buttons)) end
    for i, b in ipairs(buttons) do
        b:SetWidth(padding and (words[i] + padding) or math.max(TAB_MIN_W, words[i] + TAB_PADDING))
    end
end

local function menuTabs()
    for i, tab in ipairs(Schema.TABS) do
        local b = tabButton(frame.tabRow, TAB_H)
        b.tabId = tab.id
        b.text:SetText(Schema.TabTitle(tab.id))
        b:SetScript("OnClick", function(self) RaidOptions.SelectTab(self.tabId) end)
        local previous = RaidOptions.tabButtons[i - 1]
        if previous then
            b:SetPoint("LEFT", previous, "RIGHT", 0, 0)
        else
            b:SetPoint("LEFT", frame.tabRow, "LEFT", TAB_ROW_INSET, 0)
        end
        RaidOptions.tabButtons[i] = b
    end
    fitTabs()
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

-- Under the tabs: the combat notice while in combat, then the note on
-- the size edited, while it is not the one shown; then the page.
function anchorScroll()
    local top = frame.tabRow
    for _, notice in ipairs({ RaidOptions.combatNotice, RaidOptions.sizeNotice }) do
        if notice:IsShown() then
            notice:ClearAllPoints()
            notice:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
            notice:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0, 0)
            top = notice
        end
    end
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -SCROLLBAR_W, 0)
end

local paintFooter

-- Rows that only mean something while another setting allows it: the
-- class order, while the edited size groups by class; the raid tools
-- bar's fold while it is docked, its position while it is free.
local function toolsDocked() return RaidConfig.Get("general", "toolsMode") == "DOCKED" end
local function toolsFree() return not toolsDocked() end
local ROW_ACTIVE = {
    classOrder = function() return RaidConfig.Get(Raid.Scope(RaidOptions.Size()), "groupBy") == "CLASS" end,
    toolsOpen = toolsDocked, toolsX = toolsFree, toolsY = toolsFree,
}

-- Only a row whose state changes: SetEnabled repaints its buttons as
-- not hovered, which every change (a click on + / -) would otherwise do.
local function setRowStates()
    forEachRow(function(row)
        local active = ROW_ACTIVE[row.key]
        local on = not inCombat and (not active or active())
        if row.enabledState ~= on then
            row.enabledState = on
            row:SetEnabled(on)
        end
    end)
end

local function applyLock()
    local on = not inCombat
    setRowStates()
    for _, control in ipairs(frame.lockedControls) do control:SetEnabled(on) end
    RaidOptions.combatNotice:SetShown(inCombat)
    anchorScroll()
    paintFooter()
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

-- Copy from: the other sizes, and every size of the other characters
-- that have a raid profile. Picking one arms the button; a second click
-- within a few seconds copies onto the edited size.
local function copyItems()
    local items = {}
    for _, size in ipairs(Raid.SIZES) do
        if size ~= RaidOptions.Size() then items[#items + 1] = { value = "size:" .. size, text = sizeText(size) } end
    end
    for _, key in ipairs(ns.RaidProfiles.Characters()) do
        for _, size in ipairs(Raid.SIZES) do
            local text = L.RAID_COPY_CHARACTER:format(key, sizeText(size))
            items[#items + 1] = { value = "char:" .. key .. ":" .. size, text = text }
        end
    end
    return items
end

local function runCopy(value)
    local to = RaidOptions.Size()
    local size = tonumber(value:match("^size:(%d+)$"))
    if size then
        ns.RaidProfiles.CopySize(size, to)
        return
    end
    local key, from = value:match("^char:(.+):(%d+)$")
    if key then ns.RaidProfiles.CopyFromCharacter(key, tonumber(from), to) end
end

local function copyFromRow(footer)
    local row
    local function disarm()
        row.pending = nil
        row.button.text:SetText(L.COPY_FROM)
        Style.Paint(row.button.text, "text")
    end
    row = Widgets.Dropdown(footer, {
        items = copyItems,
        get = function() return nil end,
        set = function(value)
            local token = {}
            row.pending, row.token = value, token
            C_Timer.After(CONFIRM_SECONDS, function() if row.token == token and row.pending then disarm() end end)
        end,
    })
    row:SetSize(WIDE_BUTTON_W, BUTTON_H)
    row:EnableMouse(false)
    row.hover:SetAlpha(0)
    row.button:ClearAllPoints()
    row.button:SetAllPoints(row)
    local open = row.button:GetScript("OnClick")
    row.button:SetScript("OnClick", function(self)
        local value = row.pending
        if not value then return open(self) end
        disarm()
        runCopy(value)
    end)
    local refresh = row.Refresh
    function row:Refresh()
        refresh(self)
        if self.pending then
            self.button.text:SetText(L.CONFIRM)
            Style.Paint(self.button.text, "error")
        else
            self.button.text:SetText(L.COPY_FROM)
        end
    end
    row.Disarm = disarm
    row:Refresh()
    return row
end

-- The Profile tab: export and import of the edited size. Its blocks are
-- rows of the page: they refresh with the edited size and lock in combat
-- like the setting rows.
local function showImportMessage(text, colorKey)
    RaidOptions.importMessage:SetText(text)
    Style.Paint(RaidOptions.importMessage, colorKey)
end

local function runImport()
    local text = (RaidOptions.importArea:GetText() or ""):match("^%s*(.-)%s*$")
    local ok, result = ns.RaidProfiles.Import(text, RaidOptions.Size())
    if not ok then
        showImportMessage(L["IMPORT_" .. result], "error")
        return
    end
    RaidOptions.importArea:SetText("")
    showImportMessage(result > 0 and L.IMPORT_SKIPPED:format(result) or L.IMPORT_DONE, "accent")
end

local function newBlock(page)
    local block = CreateFrame("Frame", nil, page)
    function block:Refresh() end
    function block:SetEnabled() end
    return block
end

local function hintAndArea(block, readOnly)
    local hint = Style.Text(block, 11, "muted")
    hint:SetPoint("TOPLEFT", block, "TOPLEFT", INSET, -4)
    local area = Widgets.TextArea(block, { width = CONTENT_W - 2 * INSET, height = TEXT_AREA_H, readOnly = readOnly })
    area:SetPoint("TOPLEFT", block, "TOPLEFT", INSET, -(MESSAGE_H + 2))
    return hint, area
end

local function exportBlock(page)
    local block = newBlock(page)
    local hint, area = hintAndArea(block, true)
    function block:Refresh()
        hint:SetText(L.RAID_EXPORT_HINT:format(sizeText(RaidOptions.Size())))
        area:SetText(ns.RaidProfiles.Export(RaidOptions.Size()))
    end
    RaidOptions.exportHint, RaidOptions.exportArea = hint, area
    return block, MESSAGE_H + TEXT_AREA_H + 10
end

local function importBlock(page)
    local block = newBlock(page)
    local hint, area = hintAndArea(block, false)
    local button = Widgets.Button(block, { text = L.IMPORT, width = BUTTON_W, onClick = runImport })
    button:SetPoint("TOPLEFT", area, "BOTTOMLEFT", 0, -GAP)
    local message = Style.Text(block, 11, "muted")
    message:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -6)
    message:SetJustifyH("LEFT")
    function block:Refresh() hint:SetText(L.RAID_IMPORT_HINT:format(sizeText(RaidOptions.Size()))) end
    function block:SetEnabled(on) button:SetEnabled(on); area.edit:SetEnabled(on) end
    RaidOptions.importHint, RaidOptions.importArea = hint, area
    RaidOptions.importButton, RaidOptions.importMessage = button, message
    return block, MESSAGE_H + 2 + TEXT_AREA_H + GAP + BUTTON_H + 6 + MESSAGE_H
end

RaidOptions.CUSTOM_PAGES.profile = function(page)
    local stack = newStack(page)
    for _, entry in ipairs({ { L.EXPORT, exportBlock }, { L.IMPORT, importBlock } }) do
        local header = Widgets.Header(page, entry[1])
        header.isSection = true
        stack.add(header)
        stack.add(entry[2](page))
    end
    stack.finish()
end

-- The raid panel's movers only (Core/Movers.lua, group "raid"); the unit
-- frames' window has its own button.
local function toggleMovers()
    if ns.Movers.IsUnlocked("raid") then ns.Movers.Lock("raid") else ns.Movers.Unlock("raid") end
end

-- The lock button names what a click does; test mode's is outlined while
-- the window's test mode is on.
function paintFooter()
    RaidOptions.unlockButton.text:SetText(ns.Movers.IsUnlocked("raid") and L.LOCK_FRAMES or L.UNLOCK_FRAMES)
    local button = RaidOptions.testButton
    local testOn = ns.RaidTestMode.IsOwnOn()
    Style.SetBorderColor(button, testOn and "accent" or "border")
    local idle = button:IsEnabled() and "text" or "muted"
    Style.Paint(button.text, testOn and "accent" or idle)
end

-- The unit frames' window's builder (Options/Window.lua): lock, test
-- mode, the other window. The way across stays usable in combat.
local function createFooterLeft(footer)
    RaidOptions.unlockButton, RaidOptions.testButton, RaidOptions.unitButton = ns.Options.FooterLeft(footer, {
        unlock = toggleMovers,
        test = function() ns.RaidTestMode.Set(not ns.RaidTestMode.IsOwnOn()) end,
        testLeave = paintFooter,
        other = { text = L.UNIT_FRAMES_BUTTON, onClick = function()
            RaidOptions.Close()
            ns.Options.Open()
        end },
    })
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    createFooterLeft(footer)
    local reset = ns.Options.ConfirmButton(footer, L.RAID_RESET_SIZE,
        function() ns.RaidProfiles.ResetSize(RaidOptions.Size()) end)
    reset:SetPoint("RIGHT", footer, "RIGHT", -FOOTER_INSET, 0)
    local copy = copyFromRow(footer)
    copy:SetPoint("RIGHT", reset, "LEFT", -GAP, 0)
    RaidOptions.resetButton, RaidOptions.copyRow = reset, copy
    frame.footer = footer
    return footer
end

-- A tinted strip under the tabs (anchorScroll places it); its text
-- wraps to a second line where the strip is tall enough.
local function createNotice(body, text, height)
    local notice = CreateFrame("Frame", nil, body)
    notice:SetHeight(height)
    local tint = notice:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints(notice)
    local a = Style.COLORS.accent
    tint:SetColorTexture(a[1], a[2], a[3], 0.12)
    local bar = line(notice, "accent")
    bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(ACCENT_W)
    notice.text = Style.Text(notice, 12, "accent")
    notice.text:SetPoint("LEFT", notice, "LEFT", INSET, 0)
    notice.text:SetWidth(CONTENT_W - 2 * INSET)
    notice.text:SetJustifyH("LEFT")
    notice.text:SetWordWrap(true)
    notice.text:SetText(text)
    notice:Hide()
    return notice
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
    RaidOptions.combatNotice = createNotice(body, L.COMBAT_LOCKED, NOTICE_H)
    RaidOptions.sizeNotice = createNotice(body, "", SIZE_NOTICE_H)
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
    frame.lockedControls = { RaidOptions.sizeModeRow, RaidOptions.copyRow, RaidOptions.resetButton,
        RaidOptions.unlockButton, RaidOptions.testButton }
    -- Hiding the window (ESC, close button, /fuf raid) takes an open
    -- dropdown list and armed confirmations with it, and ends its test
    -- mode: the panel shows the active size again.
    frame:SetScript("OnHide", function()
        Widgets.CloseList()
        RaidOptions.resetButton.Disarm()
        RaidOptions.copyRow.Disarm()
        ns.RaidTestMode.Set(false)
        ns.RaidTestMode.Preview(nil)
    end)
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
    setRowStates()
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
            if tab.custom == "profile" then showImportMessage("", "muted") end
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

-- Edits another size's profile: the rows (and the export) read it from
-- now on; a copy or reset armed for the size before is not.
function RaidOptions.SelectSize(size)
    ensureWindow()
    Raid.Scope(size)
    Widgets.CloseList()
    RaidOptions.resetButton.Disarm()
    RaidOptions.copyRow.Disarm()
    RaidOptions.size = size
    refreshAll()
    if frame:IsShown() then ns.RaidTestMode.Preview(size) end
end

-- Without a size: the size edited while open, else the one the panel
-- shows now (not the one edited last time).
function RaidOptions.Open(size, tabId)
    if not RaidConfig.Profile() then return end
    ensureWindow()
    if InCombatLockdown() then inCombat = true end
    if not frame:IsShown() then
        restorePosition()
        frame:Show()
        size = size or ns.RaidSize.Current()
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
ns.Listen("RAID_TEST_MODE", function()
    if frame then
        paintFooter()
        renderSizeTabs()
    end
end)
-- The unit frames' test mode shows the edited size as well.
ns.Listen("TEST_MODE", function()
    if RaidOptions.IsOpen() then renderSizeTabs() end
end)
-- The raid panel's mover locked or unlocked from anywhere: this window,
-- /fuf lock, the start of combat.
ns.Listen("MOVERS_UNLOCKED", function(_, group)
    if frame and group == "raid" then paintFooter() end
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
