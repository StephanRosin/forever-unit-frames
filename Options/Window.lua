local _, ns = ...

-- The options window. A plain (non-secure) frame: every change goes through
-- ns.Config, whose CONFIG_CHANGED listeners restyle the secure unit frames
-- out of combat. In combat the window stays open but its controls lock.
local Options = {}
ns.Options = Options

local Style, Widgets, Schema, Config, L = ns.Style, ns.Widgets, ns.Schema, ns.Config, ns.L

local WINDOW_NAME = "ForeverUnitFramesOptions"
local WIDTH, HEIGHT = 780, 560
local TITLE_H, NAV_W, TAB_H, FOOTER_H = 32, 160, 30, 40
local NAV_ROW_H, NAV_TOP, NAV_BAR_W = 28, 8, 3
local TAB_PADDING, TAB_MIN_W, TAB_UNDERLINE_H = 28, 70, 2
local NOTICE_H = 26
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - NAV_W - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET = 4, 16, 8, 16
local TEXT_AREA_H, MESSAGE_H = 70, 20
local BUTTON_H, BUTTON_W, WIDE_BUTTON_W, FOOTER_GAP = 24, 120, 160, 8
local CONFIRM_SECONDS = 3
local HIGHLIGHT_HOLD, HIGHLIGHT_STEPS, HIGHLIGHT_STEP_SECONDS, HIGHLIGHT_W = 0.9, 6, 0.1, 2
local DEFAULT_POSITION = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 60, y = -120 }

local frame
local pages = {}
local inCombat = false

-- Helpers ---------------------------------------------------------------------

local function localized(key)
    if L[key] ~= key then return L[key] end
end

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
    for _, row in ipairs(Options.rows or {}) do fn(row) end
end

local function isFrameScope(scope) return scope ~= "general" end

-- Position --------------------------------------------------------------------

local function savedPosition()
    local pos = ForeverUnitFramesDB and ForeverUnitFramesDB.window
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

-- Only in SavedVariables: the window position is not part of a profile.
local function savePosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if not point then return end
    ForeverUnitFramesDB = ForeverUnitFramesDB or {}
    ForeverUnitFramesDB.window = { point = point, relativePoint = relativePoint or point, x = x, y = y }
end

-- Unit frame highlight ----------------------------------------------------------

local function createOutline(unitFrame)
    local edges = {}
    for i = 1, 4 do
        edges[i] = unitFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        edges[i]:SetColorTexture(unpack(Style.COLORS.accent))
        edges[i]:SetAlpha(0)
    end
    unitFrame.optionsHighlight = edges
    return edges
end

-- Drawn just outside the unit's border (around a docked castbar too).
local function anchorOutline(unitFrame, edges)
    local o = ns.Border.Extent(unitFrame.key)
    local box = unitFrame.unitBox or unitFrame
    local hw = ns.Pixel.Snap(HIGHLIGHT_W, nil, 1)
    local w = o + hw
    for _, t in ipairs(edges) do t:ClearAllPoints() end
    edges[1]:SetPoint("BOTTOMLEFT", box, "TOPLEFT", -w, o); edges[1]:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", w, o); edges[1]:SetHeight(hw)
    edges[2]:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -w, -o); edges[2]:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", w, -o); edges[2]:SetHeight(hw)
    edges[3]:SetPoint("TOPRIGHT", box, "TOPLEFT", -o, o); edges[3]:SetPoint("BOTTOMRIGHT", box, "BOTTOMLEFT", -o, -o); edges[3]:SetWidth(hw)
    edges[4]:SetPoint("TOPLEFT", box, "TOPRIGHT", o, o); edges[4]:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", o, -o); edges[4]:SetWidth(hw)
end

local function setOutlineAlpha(edges, alpha)
    for _, t in ipairs(edges) do t:SetAlpha(alpha) end
end

-- Each highlight gets a token so the fade of an earlier one cannot cut a
-- newer one short. Only the alpha changes after creation, never visibility
-- or anchors, so a fade that runs into combat is harmless.
local function fadeOutline(unitFrame, edges)
    local token = {}
    unitFrame.optionsHighlightToken = token
    local function step(n)
        if unitFrame.optionsHighlightToken ~= token then return end
        setOutlineAlpha(edges, 1 - n / HIGHLIGHT_STEPS)
        if n < HIGHLIGHT_STEPS then
            C_Timer.After(HIGHLIGHT_STEP_SECONDS, function() step(n + 1) end)
        end
    end
    C_Timer.After(HIGHLIGHT_HOLD, function() step(1) end)
end

-- Textures on a secure frame are created and anchored out of combat only.
local function highlightFrame(scope)
    local unitFrame = ns.Frames[scope]
    if scope == ns.Party.KEY then unitFrame = ns.Party.HighlightTarget() end
    if not unitFrame or InCombatLockdown() then return end
    local edges = unitFrame.optionsHighlight or createOutline(unitFrame)
    anchorOutline(unitFrame, edges)
    setOutlineAlpha(edges, 1)
    fadeOutline(unitFrame, edges)
end

-- Setting rows ------------------------------------------------------------------

local function enumItems(def)
    return function()
        local items = {}
        for _, v in ipairs(def.values) do items[#items + 1] = { value = v, text = Schema.EnumText(def, v) } end
        return items
    end
end

-- `font` holds the font's name: the dropdown resolves it through ns.Media.
local function mediaItems(def)
    return function()
        local items = {}
        for _, name in ipairs(ns.Media.List(def.mediaKind)) do
            items[#items + 1] = { value = name, text = name, font = def.mediaKind == "font" and name or nil }
        end
        return items
    end
end

local ROW_BUILDERS = {
    int = function(parent, def, opts)
        opts.min, opts.max, opts.step = def.min, def.max, 1
        opts.zeroText = def.zeroText and L[def.zeroText]
        return Widgets.Slider(parent, opts)
    end,
    bool = function(parent, _, opts) return Widgets.Checkbox(parent, opts) end,
    enum = function(parent, def, opts)
        opts.items = enumItems(def)
        return Widgets.Dropdown(parent, opts)
    end,
    media = function(parent, def, opts)
        opts.items = mediaItems(def)
        return Widgets.Dropdown(parent, opts)
    end,
    color = function(parent, _, opts) return Widgets.Color(parent, opts) end,
    text = function(parent, def, opts)
        opts.maxLetters = def.maxLetters or ns.Settings.TEXT_MAX
        return Widgets.TextInput(parent, opts)
    end,
}

local function inheritOpts(scope, key)
    return {
        isOverridden = function() return Config.IsOverridden(scope, key) end,
        clear = function() Config.ClearOverride(scope, key) end,
    }
end

-- Hints that only hold on some pages: only the player's own setting
-- conceals a Blizzard castbar, which comes back after a /reload.
local HINT_SCOPES = { hideBlizzardCastbar = { player = true } }

-- Hints that follow the settings: the spell range fading uses.
local DYNAMIC_HINTS = {
    rangeFriendlySpell = function() return ns.Range.SpellHint("friendly") end,
    rangeHostileSpell = function() return ns.Range.SpellHint("hostile") end,
}

local function hintFor(scope, key)
    if DYNAMIC_HINTS[key] then return DYNAMIC_HINTS[key] end
    if HINT_SCOPES[key] and not HINT_SCOPES[key][scope] then return nil end
    return localized("HINT_" .. key)
end

local function settingRow(parent, scope, key)
    local def = ns.Settings.Get(key)
    local opts = {
        label = L["SETTING_" .. key], hint = hintFor(scope, key),
        get = function() return Config.Get(scope, key) end,
        set = function(v) return Config.Set(scope, key, v) end,
    }
    if isFrameScope(scope) and def.scope == "inherit" then opts.inherit = inheritOpts(scope, key) end
    local row = ROW_BUILDERS[def.type](parent, def, opts)
    row.key = key
    return row
end

-- Pages -------------------------------------------------------------------------

-- Stacks rows top to bottom; a section header after other rows gets a gap.
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

local function sectionHeader(page, id)
    local header = Widgets.Header(page, L["SECTION_" .. id])
    header.isSection = true
    return header
end

-- Defined with the other blocks below; a section's action button.
local actionBlock

local function buildSettingsPage(page, scope, tab)
    local stack = newStack(page)
    for _, section in ipairs(tab.sections) do
        local keys = {}
        for _, key in ipairs(section.keys) do
            if ns.Settings.AppliesTo(ns.Settings.Get(key), scope) then keys[#keys + 1] = key end
        end
        if #keys > 0 then
            stack.add(sectionHeader(page, section.id))
            for _, key in ipairs(keys) do stack.add(settingRow(page, scope, key)) end
            if section.action then stack.add(actionBlock(page, section.action)) end
        end
    end
    stack.finish()
end

-- A plain block on a custom page. Blocks answer Refresh/SetEnabled like rows.
local function newBlock(page)
    local block = CreateFrame("Frame", nil, page)
    function block:Refresh() end
    function block:SetEnabled() end
    return block
end

local function textArea(block, readOnly, y)
    local area = Widgets.TextArea(block, { width = CONTENT_W - 2 * INSET, height = TEXT_AREA_H, readOnly = readOnly })
    area:SetPoint("TOPLEFT", block, "TOPLEFT", INSET, -y)
    return area
end

-- Two-click action: the first click arms the button for a few seconds, the
-- second runs it.
local function confirmButton(parent, text, action)
    local button, armed
    local function paintArmed() if armed then Style.Paint(button.text, "error") end end
    local function disarm()
        armed = nil
        button.text:SetText(text)
        button:GetScript("OnLeave")(button)
    end
    button = Widgets.Button(parent, { text = text, width = WIDE_BUTTON_W, onClick = function()
        if armed then disarm(); action(); return end
        local token = {}
        armed = token
        button.text:SetText(L.CONFIRM)
        paintArmed()
        C_Timer.After(CONFIRM_SECONDS, function() if armed == token then disarm() end end)
    end })
    button:HookScript("OnEnter", paintArmed)
    button:HookScript("OnLeave", paintArmed)
    button.Disarm = disarm
    return button
end

-- Section actions: what the button does. Two clicks, like Reset.
local ACTIONS = {
    applyFontToFrames = function() Config.ClearFrameOverrides(ns.Settings.TEXT_STYLE_KEYS) end,
}
-- The buttons by action id, for the tests and for disarming on close.
Options.actionButtons = {}

function actionBlock(page, id)
    local block = newBlock(page)
    local button = confirmButton(block, L["ACTION_" .. id], ACTIONS[id])
    button:SetPoint("TOPLEFT", block, "TOPLEFT", INSET, -6)
    local hint = Style.Text(block, 10, "muted")
    hint:SetPoint("LEFT", button, "RIGHT", FOOTER_GAP, 0)
    hint:SetText(L["ACTION_HINT_" .. id])
    Options.actionButtons[id] = button
    function block:SetEnabled(on) button:SetEnabled(on) end
    block:SetHeight(BUTTON_H + 12)
    return block
end

local function exportBlock(page)
    local block = newBlock(page)
    local hint = Style.Text(block, 11, "muted")
    hint:SetPoint("TOPLEFT", block, "TOPLEFT", INSET, -4)
    hint:SetText(L.EXPORT_HINT)
    local area = textArea(block, true, MESSAGE_H + 2)
    Options.exportArea = area
    function block:Refresh() area:SetText(ns.Codec.Encode(Config.Profile())) end
    return block, MESSAGE_H + TEXT_AREA_H + 10
end

local function showImportMessage(text, colorKey)
    Options.importMessage:SetText(text)
    Style.Paint(Options.importMessage, colorKey)
end

local function runImport()
    local text = Options.importArea:GetText() or ""
    local profile, err = ns.Codec.Decode(text:match("^%s*(.-)%s*$"))
    if not profile then
        showImportMessage(L["IMPORT_" .. err], "error")
        return
    end
    Config.Import(profile)
    Options.importArea:SetText("")
    showImportMessage(L.IMPORT_DONE, "accent")
end

local function importBlock(page)
    local block = newBlock(page)
    local area = textArea(block, false, 0)
    local button = Widgets.Button(block, { text = L.IMPORT, width = BUTTON_W, onClick = runImport })
    button:SetPoint("TOPLEFT", area, "BOTTOMLEFT", 0, -8)
    local message = Style.Text(block, 11, "muted")
    message:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -6)
    message:SetJustifyH("LEFT")
    Options.importArea, Options.importButton, Options.importMessage = area, button, message
    function block:SetEnabled(on) button:SetEnabled(on); area.edit:SetEnabled(on) end
    return block, TEXT_AREA_H + 8 + BUTTON_H + 6 + MESSAGE_H
end

local function resetBlock(page)
    local block = newBlock(page)
    local button = confirmButton(block, L.RESET_ALL, function() Config.ResetAll() end)
    button:SetPoint("TOPLEFT", block, "TOPLEFT", INSET, -6)
    Options.resetAllButton = button
    function block:SetEnabled(on) button:SetEnabled(on) end
    return block, BUTTON_H + 12
end

local CUSTOM_BLOCKS = {
    { header = "EXPORT", build = exportBlock },
    { header = "IMPORT", build = importBlock },
    { header = "RESET", build = resetBlock },
}

local function buildProfilePage(page)
    local stack = newStack(page)
    for _, entry in ipairs(CUSTOM_BLOCKS) do
        local header = Widgets.Header(page, L[entry.header])
        header.isSection = true
        stack.add(header)
        stack.add(entry.build(page))
    end
    stack.finish()
end

local function pageFor(scope, tab)
    local id = scope .. ":" .. tab.id
    if pages[id] then return pages[id] end
    local page = CreateFrame("Frame", nil, frame.scrollChild)
    page:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, 0)
    page:SetWidth(CONTENT_W)
    if tab.custom == "profile" then buildProfilePage(page) else buildSettingsPage(page, scope, tab) end
    page:SetHeight(page.height)
    page:Hide()
    pages[id] = page
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

-- Combat lock -------------------------------------------------------------------

local function anchorScroll()
    local top = inCombat and Options.combatNotice or frame.tabRow
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -SCROLLBAR_W, 0)
end

local function refreshFooter()
    local unlocked = ns.Movers.IsUnlocked()
    Options.unlockButton.text:SetText(unlocked and L.LOCK_FRAMES or L.UNLOCK_FRAMES)
    local testOn = ns.TestMode.IsOn()
    Style.SetBorderColor(Options.testButton, testOn and "accent" or "border")
    local idle = Options.testButton:IsEnabled() and "text" or "muted"
    Style.Paint(Options.testButton.text, testOn and "accent" or idle)
end

local function applyLock()
    local on = not inCombat
    forEachRow(function(row) row:SetEnabled(on) end)
    for _, control in ipairs(frame.footerControls) do control:SetEnabled(on) end
    Options.combatNotice:SetShown(inCombat)
    anchorScroll()
    refreshFooter()
end

-- Navigation --------------------------------------------------------------------

local function paintSelection(entry, selected, idleColor)
    Style.Paint(entry.text, selected and "accent" or idleColor)
    entry.selected = selected
end

local function hoverable(button, idleColor)
    button:SetScript("OnEnter", function(self)
        if not self.selected then Style.Paint(self.text, "text") end
        if self.hover then self.hover:Show() end
    end)
    button:SetScript("OnLeave", function(self)
        if not self.selected then Style.Paint(self.text, idleColor) end
        if self.hover then self.hover:Hide() end
    end)
end

local function navButton(nav, key, text, y)
    local b = CreateFrame("Button", nil, nav)
    b:SetHeight(NAV_ROW_H)
    b:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -y)
    b:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -1, -y)
    b.hover = Style.Fill(b, "hover", "ARTWORK")
    b.hover:Hide()
    b.bar = line(b, "accent")
    b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(NAV_BAR_W)
    b.text = Style.Text(b, 12, "text")
    b.text:SetPoint("LEFT", b, "LEFT", INSET, 0)
    b.text:SetText(text)
    hoverable(b, "text")
    b:SetScript("OnClick", function() Options.Select(key) end)
    Options.navButtons[key] = b
    return b
end

-- The language, at the bottom of the navigation: visible on every page.
-- A label above a dropdown as wide as the column; the list opens upwards.
local LANGUAGE_BUTTON_H, LANGUAGE_LABEL_H, LANGUAGE_BOTTOM = 22, 18, 10

local function languageRow(nav)
    local row = Widgets.Dropdown(nav, {
        label = L.SETTING_language,
        items = enumItems(ns.Settings.Get("language")),
        get = function() return Config.Get("general", "language") end,
        set = function(v) Config.Set("general", "language", v) end,
        listAbove = true,
    })
    row:SetHeight(LANGUAGE_LABEL_H + LANGUAGE_BUTTON_H)
    row:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", INSET, LANGUAGE_BOTTOM)
    row:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -INSET, LANGUAGE_BOTTOM)
    row:EnableMouse(false)
    row.hover:SetAlpha(0)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    Style.Paint(row.label, "muted")
    row.button:ClearAllPoints()
    row.button:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.button:SetHeight(LANGUAGE_BUTTON_H)
    row:Refresh()
    Options.languageRow = row
    return row
end

local function createNav(parent)
    local nav = CreateFrame("Frame", nil, parent)
    nav:SetWidth(NAV_W)
    Style.Fill(nav, "panel")
    local edge = line(nav, "border")
    edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
    Options.navButtons = {}
    local y = NAV_TOP
    navButton(nav, "general", L.GENERAL, y)
    y = y + NAV_ROW_H + 6
    local separator = line(nav, "border")
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", nav, "TOPLEFT", INSET, -y)
    separator:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -INSET, -y)
    y = y + 7
    for _, def in ipairs(ns.Units.List) do
        navButton(nav, def.key, L["FRAME_" .. def.key], y)
        y = y + NAV_ROW_H
    end
    languageRow(nav)
    return nav
end

local function renderNav()
    for key, b in pairs(Options.navButtons) do
        local selected = key == Options.currentScope
        paintSelection(b, selected, "text")
        b.bar:SetShown(selected)
    end
end

-- Tabs --------------------------------------------------------------------------

local function tabButton(i)
    local b = CreateFrame("Button", nil, frame.tabRow)
    b:SetHeight(TAB_H)
    b.text = Style.Text(b, 12, "muted")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.underline = line(b, "accent")
    b.underline:SetHeight(TAB_UNDERLINE_H)
    b.underline:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 8, 0)
    b.underline:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 0)
    hoverable(b, "muted")
    b:SetScript("OnClick", function(self) Options.SelectTab(self.tabId) end)
    local previous = Options.tabButtons[i - 1]
    if previous then b:SetPoint("LEFT", previous, "RIGHT", 0, 0) else b:SetPoint("LEFT", frame.tabRow, "LEFT", 8, 0) end
    Options.tabButtons[i] = b
    return b
end

local function renderTabs(tabs)
    for i, tab in ipairs(tabs) do
        local b = Options.tabButtons[i] or tabButton(i)
        b.tabId = tab.id
        b.text:SetText(L["TAB_" .. tab.id])
        b:SetWidth(math.max(TAB_MIN_W, (b.text:GetStringWidth() or 0) + TAB_PADDING))
        b:Show()
    end
    for i = #tabs + 1, #Options.tabButtons do Options.tabButtons[i]:Hide() end
end

local function paintTabs()
    for _, b in ipairs(Options.tabButtons) do
        local selected = b.tabId == Options.currentTab
        paintSelection(b, selected, "muted")
        b.underline:SetShown(selected)
    end
end

-- Footer ------------------------------------------------------------------------

local function toggleMovers()
    if ns.Movers.IsUnlocked() then ns.Movers.Lock() else ns.Movers.Unlock() end
    refreshFooter()
end

local function otherFrames()
    local items = {}
    for _, def in ipairs(ns.Units.List) do
        if def.key ~= Options.currentScope then items[#items + 1] = { value = def.key, text = L["FRAME_" .. def.key] } end
    end
    return items
end

-- The shared dropdown list, driven by a row whose button always reads
-- "Copy from…" (it has no current value to show).
local function copyFromRow(footer)
    local row = Widgets.Dropdown(footer, {
        items = otherFrames,
        get = function() return nil end,
        set = function(from) Config.CopyScope(from, Options.currentScope) end,
    })
    row:SetSize(WIDE_BUTTON_W, BUTTON_H)
    row:EnableMouse(false)
    row.hover:SetAlpha(0)
    row.button:ClearAllPoints()
    row.button:SetAllPoints(row)
    local refresh = row.Refresh
    function row:Refresh() refresh(self); self.button.text:SetText(L.COPY_FROM) end
    row:Refresh()
    return row
end

local function createFooterLeft(footer)
    local unlock = Widgets.Button(footer, { text = L.UNLOCK_FRAMES, width = BUTTON_W, onClick = toggleMovers })
    unlock:SetPoint("LEFT", footer, "LEFT", 12, 0)
    local test = Widgets.Button(footer, { text = L.TEST_MODE_ON, width = BUTTON_W,
        onClick = function() ns.TestMode.Set(not ns.TestMode.IsOn()) end })
    test:SetPoint("LEFT", unlock, "RIGHT", FOOTER_GAP, 0)
    test:HookScript("OnLeave", refreshFooter)
    Options.unlockButton, Options.testButton = unlock, test
end

local function createFooterRight(footer)
    local reset = confirmButton(footer, L.RESET_FRAME, function() Config.ResetScope(Options.currentScope) end)
    reset:SetPoint("RIGHT", footer, "RIGHT", -12, 0)
    local copy = copyFromRow(footer)
    copy:SetPoint("RIGHT", reset, "LEFT", -FOOTER_GAP, 0)
    Options.resetFrameButton, Options.copyRow = reset, copy
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    createFooterLeft(footer)
    createFooterRight(footer)
    frame.footerControls = { Options.unlockButton, Options.testButton, Options.copyRow, Options.resetFrameButton }
    return footer
end

-- Title bar ---------------------------------------------------------------------

local CROSS_SIZE, CROSS_ANGLE = 14, math.pi / 4

-- The × glyph is not in every game font, so it is drawn from two lines.
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
    b:SetScript("OnClick", function() Options.Close() end)
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
    title:SetText(L.ADDON_NAME)
    local version = Style.Text(bar, 11, "muted")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
    version:SetText("v" .. (C_AddOns.GetAddOnMetadata(ns.name, "Version") or ""))
    bar.close = closeButton(bar)
    return bar
end

-- Body: tab row, combat notice, scroll area ---------------------------------------

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
    bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(NAV_BAR_W)
    local text = Style.Text(notice, 12, "accent")
    text:SetPoint("LEFT", notice, "LEFT", INSET, 0)
    text:SetText(L.COMBAT_LOCKED)
    notice:Hide()
    Options.combatNotice = notice
end

local function createBody(parent, titleBar, footer)
    local body = CreateFrame("Frame", nil, parent)
    body:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", NAV_W, 0)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
    frame.body = body
    local tabRow = CreateFrame("Frame", nil, body)
    tabRow:SetHeight(TAB_H)
    tabRow:SetPoint("TOPLEFT"); tabRow:SetPoint("TOPRIGHT")
    horizontalLine(tabRow, "BOTTOM")
    frame.tabRow = tabRow
    Options.tabButtons = {}
    createNotice(body)
    createScroll(body)
    anchorScroll()
end

-- Window ------------------------------------------------------------------------

local function createWindow()
    frame = CreateFrame("Frame", WINDOW_NAME, UIParent)
    Options.frame = frame
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
    local footer = createFooter(frame)
    local nav = createNav(frame)
    -- Locked in combat like the footer.
    table.insert(frame.footerControls, Options.languageRow)
    nav:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", 0, 0)
    nav:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 0)
    createBody(frame, frame.titleBar, footer)
    -- Hiding the window (ESC, close button, /fuf) takes an open dropdown
    -- list and armed confirmations with it.
    frame:SetScript("OnHide", function()
        Widgets.CloseList()
        Options.resetFrameButton.Disarm()
        if Options.resetAllButton then Options.resetAllButton.Disarm() end
        for _, button in pairs(Options.actionButtons) do button.Disarm() end
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

-- Public API ----------------------------------------------------------------------

function Options.IsOpen()
    return frame ~= nil and frame:IsShown()
end

function Options.SelectTab(id)
    ensureWindow()
    local scope = Options.currentScope
    for _, tab in ipairs(Schema.Tabs(scope)) do
        if tab.id == id then
            Widgets.CloseList()
            if Options.page then Options.page:Hide() end
            local page = pageFor(scope, tab)
            Options.page, Options.currentTab, Options.rows = page, id, page.rows
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

function Options.Select(scope)
    ensureWindow()
    local tabs = Schema.Tabs(scope)
    local tabId = tabs[1].id
    for _, tab in ipairs(tabs) do
        if tab.id == Options.currentTab then tabId = tab.id end
    end
    Options.currentScope = scope
    Options.resetFrameButton.Disarm()
    local frameScope = isFrameScope(scope)
    Options.copyRow:SetShown(frameScope)
    Options.resetFrameButton:SetShown(frameScope)
    renderNav()
    renderTabs(tabs)
    Options.SelectTab(tabId)
    highlightFrame(scope)
end

function Options.Open(scope, tabId)
    if not Config.Profile() then return end
    ensureWindow()
    if InCombatLockdown() then inCombat = true end
    if not frame:IsShown() then
        restorePosition()
        frame:Show()
    end
    Options.Select(scope or Options.currentScope or "general")
    if tabId then Options.SelectTab(tabId) end
end

function Options.Close()
    if frame then frame:Hide() end
end

function Options.Toggle()
    if Options.IsOpen() then Options.Close() else Options.Open() end
end

-- Live updates ----------------------------------------------------------------------

-- Values also change from outside the window: mover drags, Copy, Import,
-- /fuf set.
ns.Listen("CONFIG_CHANGED", function()
    if not Options.IsOpen() then return end
    forEachRow(function(row) row:Refresh() end)
    Options.languageRow:Refresh()
end)

-- Every label is set once, when its widget is built: a new language gets a
-- new window. Frames cannot be destroyed, so the old one stays hidden and
-- unreferenced; the new one takes over its global name, position, page and
-- tab.
function Options.Rebuild()
    if not frame then return end
    local wasOpen = frame:IsShown()
    frame:Hide()
    frame, Options.frame = nil, nil
    pages = {}
    Options.actionButtons = {}
    Options.page, Options.rows, Options.resetAllButton = nil, nil, nil
    if wasOpen then Options.Open(Options.currentScope, Options.currentTab) end
end

ns.Listen("LANGUAGE_CHANGED", function() Options.Rebuild() end)

ns.Listen("TEST_MODE", function()
    if frame then refreshFooter() end
end)

-- Movers have no event of their own; /fuf lock and the combat lock call
-- these directly (post-hooks on a plain addon table).
local function onMoversChanged()
    if frame then refreshFooter() end
end
hooksecurefunc(ns.Movers, "Lock", onMoversChanged)
hooksecurefunc(ns.Movers, "Unlock", onMoversChanged)

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
