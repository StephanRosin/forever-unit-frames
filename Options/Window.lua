local _, ns = ...

-- The options window. A plain (non-secure) frame: every change goes through
-- ns.Config, whose CONFIG_CHANGED listeners restyle the secure unit frames
-- out of combat. In combat the window stays open but its controls lock.
local Options = {}
ns.Options = Options

local Style, Widgets, Schema, Config, Chrome, L = ns.Style, ns.Widgets, ns.Schema, ns.Config, ns.Chrome, ns.L

local WINDOW_NAME = "ForeverUnitFramesOptions"
local WIDTH, HEIGHT = 780, 560
local NAV_W, TAB_H = 160, 30
local NAV_ROW_H, NAV_TOP, NAV_BAR_W = 28, 8, 3
local TAB_PADDING, TAB_MIN_W, TAB_UNDERLINE_H = 28, 70, 2
local NOTICE_H = 26
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - NAV_W - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET = 4, 16, 8, 16
local TEXT_AREA_H, MESSAGE_H, NOTE_H = 70, 20, 34
-- A tab note's room for text (tests: two lines must hold it).
Options.NOTE_W = CONTENT_W - 2 * INSET
local BUTTON_H, BUTTON_W, WIDE_BUTTON_W, FOOTER_GAP, FOOTER_INSET = 24, 120, 160, 8, 12
local HIGHLIGHT_HOLD, HIGHLIGHT_STEPS, HIGHLIGHT_STEP_SECONDS, HIGHLIGHT_W = 0.9, 6, 0.1, 2
local DEFAULT_POSITION = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 60, y = -120 }

local frame
local pages = {}
local inCombat = false

-- Helpers ---------------------------------------------------------------------

local line, horizontalLine = Chrome.Line, Chrome.HorizontalLine

local function localized(key)
    if L[key] ~= key then return L[key] end
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

-- enumText (optional): the words of the choices; the unit frames' by
-- default (the raid window has its own).
local function enumItems(def, enumText)
    enumText = enumText or Schema.EnumText
    return function()
        local items = {}
        for _, v in ipairs(def.values) do items[#items + 1] = { value = v, text = enumText(def, v) } end
        return items
    end
end

-- `font` holds the font's name: the dropdown resolves it through ns.Media.
local function mediaItems(def)
    return function()
        local items = {}
        if def.emptyText then items[1] = { value = "", text = L[def.emptyText] } end
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
        opts.items = enumItems(def, opts.enumText)
        return Widgets.Dropdown(parent, opts)
    end,
    media = function(parent, def, opts)
        opts.items = mediaItems(def)
        return Widgets.Dropdown(parent, opts)
    end,
    color = function(parent, _, opts) return Widgets.Color(parent, opts) end,
    text = function(parent, def, opts)
        -- A hidden-auras list has an editor of its own.
        if def.blocklist then return ns.AuraBlockEditor.Row(parent, def, opts) end
        opts.maxLetters = def.maxLetters or ns.Settings.TEXT_MAX
        return Widgets.TextInput(parent, opts)
    end,
}

-- The control row for a setting definition of any registry (the raid
-- window builds its rows with it): opts as for the widgets, plus
-- opts.enumText for an enum's words.
function Options.Control(parent, def, opts)
    return ROW_BUILDERS[def.type](parent, def, opts)
end

local function inheritOpts(scope, key)
    return {
        isOverridden = function() return Config.IsOverridden(scope, key) end,
        clear = function() Config.ClearOverride(scope, key) end,
    }
end

-- Hints that only hold on some pages: only the player's own setting
-- conceals a Blizzard castbar, which comes back after a /reload.
local HINT_SCOPES = { hideBlizzardCastbar = { player = true } }

-- Hints that follow the settings: how range fading measures.
local DYNAMIC_HINTS = {
    rangeFriendlyMode = function() return ns.Range.MethodHint("friendly") end,
    rangeHostileMode = function() return ns.Range.MethodHint("hostile") end,
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
        scope = scope,
    }
    if isFrameScope(scope) and def.scope == "inherit" then opts.inherit = inheritOpts(scope, key) end
    local row = ROW_BUILDERS[def.type](parent, def, opts)
    row.key = key
    return row
end

-- Pages -------------------------------------------------------------------------

-- The page's rows laid out anew with their gaps, after a row changed its
-- height (the hidden-auras editor's list); the scroll range follows.
local function restack(page)
    local y = PAGE_TOP
    for _, row in ipairs(page.rows) do
        y = y + row.stackGap
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -y)
        y = y + row:GetHeight()
    end
    page.height = y + PAGE_BOTTOM
    Options.PageResized(page)
end

-- Stacks rows top to bottom; a section header after other rows gets a gap.
local function newStack(page)
    local stack = { y = PAGE_TOP, rows = {} }
    function stack.add(row, height)
        row.stackGap = (row.isSection and #stack.rows > 0) and SECTION_GAP or 0
        stack.y = stack.y + row.stackGap
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -stack.y)
        row:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -stack.y)
        row:SetHeight(height or row:GetHeight())
        stack.rows[#stack.rows + 1] = row
        stack.y = stack.y + row:GetHeight()
    end
    function stack.finish()
        page.rows, page.height = stack.rows, stack.y + PAGE_BOTTOM
        page.Restack = function() restack(page) end
    end
    return stack
end

local function sectionHeader(page, id)
    local header = Widgets.Header(page, L["SECTION_" .. id])
    header.isSection = true
    return header
end

-- Defined with the other blocks below; a section's action button, a
-- tab's note.
local actionBlock, noteBlock

-- General > Frames: after the master switch, one switch per frame, the
-- frame's own "enabled".
local function frameSwitches(page, stack)
    for _, def in ipairs(ns.Units.List) do
        if not def.available or def.available() then
            local row = Widgets.Checkbox(page, {
                label = L["FRAME_" .. def.key], hint = localized("HINT_frameEnabled"),
                get = function() return Config.Get(def.key, "enabled") end,
                set = function(v) return Config.Set(def.key, "enabled", v) end,
            })
            row.key = "enabled"
            stack.add(row)
        end
    end
end

-- A tab's sections onto the stack: those with a setting of the page.
local function addSections(page, stack, scope, tab)
    for _, section in ipairs(tab.sections or {}) do
        local keys = Schema.SectionKeys(section, scope)
        if #keys > 0 then
            stack.add(sectionHeader(page, section.id))
            for _, key in ipairs(keys) do stack.add(settingRow(page, scope, key)) end
            if section.frames then frameSwitches(page, stack) end
            if section.action then stack.add(actionBlock(page, section.action)) end
        end
    end
end

local function buildSettingsPage(page, scope, tab)
    local stack = newStack(page)
    if tab.note then stack.add(noteBlock(page, L["NOTE_" .. tab.note])) end
    addSections(page, stack, scope, tab)
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

local confirmButton = Chrome.ConfirmButton

-- The left group of both windows' footers, so that they match by
-- construction: [Unlock / Lock frames] [Test mode] [the other window…],
-- from the footer's left edge. spec: unlock() and test() for the first
-- two, testLeave() repaints the test button after a hover, other =
-- { text, onClick }. Returns the three buttons.
function Options.FooterLeft(footer, spec)
    local unlock = Widgets.Button(footer, { text = L.UNLOCK_FRAMES, width = BUTTON_W, onClick = spec.unlock })
    unlock:SetPoint("LEFT", footer, "LEFT", FOOTER_INSET, 0)
    local test = Widgets.Button(footer, { text = L.TEST_MODE_ON, width = BUTTON_W, onClick = spec.test })
    test:SetPoint("LEFT", unlock, "RIGHT", FOOTER_GAP, 0)
    test:HookScript("OnLeave", spec.testLeave)
    local other = Widgets.Button(footer, { text = spec.other.text, width = BUTTON_W, onClick = spec.other.onClick })
    other:SetPoint("LEFT", test, "RIGHT", FOOTER_GAP, 0)
    return unlock, test, other
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

-- A muted text above a tab's sections, as wide as the page (two lines at
-- most).
function noteBlock(page, text)
    local block = newBlock(page)
    block.text = Style.Text(block, 11, "muted")
    block.text:SetPoint("TOPLEFT", block, "TOPLEFT", INSET, -4)
    block.text:SetPoint("TOPRIGHT", block, "TOPRIGHT", -INSET, -4)
    block.text:SetJustifyH("LEFT")
    block.text:SetWordWrap(true)
    block.text:SetText(text)
    block.isNote = true
    block:SetHeight(NOTE_H)
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

-- Export, import, reset, then the tab's sections (the minimap button).
local function buildProfilePage(page, scope, tab)
    local stack = newStack(page)
    for _, entry in ipairs(CUSTOM_BLOCKS) do
        local header = Widgets.Header(page, L[entry.header])
        header.isSection = true
        stack.add(header)
        stack.add(entry.build(page))
    end
    addSections(page, stack, scope, tab)
    stack.finish()
end

-- General > Click-casting: the raid window's editor (Raid/Options/
-- ClickCast.lua) in this window's measures: the binding's controls start
-- left of the usual column to fit the narrower page.
local CLICK_CAST_LAYOUT = { top = PAGE_TOP, bottom = PAGE_BOTTOM, sectionGap = SECTION_GAP, noteHeight = NOTE_H,
    controlX = 170, kindW = 130, valueW = 290, keyW = 80, rankW = 80, clearGap = FOOTER_GAP }

local function pageFor(scope, tab)
    local id = scope .. ":" .. tab.id
    if pages[id] then return pages[id] end
    local page = CreateFrame("Frame", nil, frame.scrollChild)
    page:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, 0)
    page:SetWidth(CONTENT_W)
    if tab.custom == "profile" then
        buildProfilePage(page, scope, tab)
    elseif tab.custom == "clickCast" then
        ns.RaidClickCastPage.Build(page, tab, CLICK_CAST_LAYOUT, "unit")
        page.clickCast = true
    else
        buildSettingsPage(page, scope, tab)
    end
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

-- A page that changed its height (a row grew or shrank, Restack): the
-- scroll range follows while it is shown, and a scroll beyond the new
-- range moves back to its end.
function Options.PageResized(page)
    page:SetHeight(page.height)
    if not frame or Options.page ~= page then return end
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

-- Combat lock -------------------------------------------------------------------

local function anchorScroll()
    local top = inCombat and Options.combatNotice or frame.tabRow
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -SCROLLBAR_W, 0)
end

local function refreshFooter()
    local unlocked = ns.Movers.IsUnlocked("units")
    Options.unlockButton.text:SetText(unlocked and L.LOCK_FRAMES or L.UNLOCK_FRAMES)
    local testOn = ns.TestMode.IsOn()
    Style.SetBorderColor(Options.testButton, testOn and "accent" or "border")
    local idle = Options.testButton:IsEnabled() and "text" or "muted"
    Style.Paint(Options.testButton.text, testOn and "accent" or idle)
end

-- Rows that only mean something while another setting allows it, by key:
-- (scope) -> whether it does on that page. The range spell and yards of a
-- reaction whose fading is off; each frame's own switch while "Use unit
-- frames" is off (its value is kept); Options/Dependencies.lua adds the
-- switches and modes of the pages.
local ROW_ACTIVE = {
    enabled = function() return ns.Config.Get("general", "unitFrames") end,
    -- Only while the raid window's click-casting is on (off, or automatic
    -- with Clique loaded, it binds nothing anywhere).
    clickCast = function() return ns.ClickCast.On() end,
    rangeFriendlySpell = function() return ns.Range.ReactionOn("friendly") end,
    rangeFriendlyYards = function() return ns.Range.ReactionOn("friendly") end,
    rangeHostileSpell = function() return ns.Range.ReactionOn("hostile") end,
    rangeHostileYards = function() return ns.Range.ReactionOn("hostile") end,
}
Options.ROW_ACTIVE = ROW_ACTIVE

-- row.enabledState: what the row was last set to (the tests read it).
local function setRowStates()
    local scope = Options.currentScope
    forEachRow(function(row)
        -- The click-casting editor's rows share keys with settings here
        -- (its mode row is "clickCast"), not their rules.
        local active = not row.clickCastRow and ROW_ACTIVE[row.key]
        local on = not inCombat and (not active or active(scope))
        row.enabledState = on
        row:SetEnabled(on)
    end)
end

local function applyLock()
    local on = not inCombat
    setRowStates()
    for _, control in ipairs(frame.footerControls) do control:SetEnabled(on) end
    Options.combatNotice:SetShown(inCombat)
    anchorScroll()
    refreshFooter()
end

-- Navigation --------------------------------------------------------------------

local paintSelection, hoverable = Chrome.PaintSelection, Chrome.Hoverable

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

-- The unit frames' movers only; the raid window has its own button. The
-- MOVERS_UNLOCKED listener repaints the footer.
local function toggleMovers()
    if ns.Movers.IsUnlocked("units") then ns.Movers.Lock("units") else ns.Movers.Unlock("units") end
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

-- The same three places as in the raid window's footer
-- (Raid/Options/Window.lua): lock, test mode, the other window. The way
-- across stays usable in combat.
local function createFooterLeft(footer)
    Options.unlockButton, Options.testButton, Options.raidButton = Options.FooterLeft(footer, {
        unlock = toggleMovers,
        test = function() ns.TestMode.Set(not ns.TestMode.IsOn()) end,
        testLeave = refreshFooter,
        other = { text = L.RAID_FRAMES_BUTTON, onClick = function()
            Options.Close()
            ns.RaidOptions.Open()
        end },
    })
end

local function createFooterRight(footer)
    local reset = confirmButton(footer, L.RESET_FRAME, function() Config.ResetScope(Options.currentScope) end)
    reset:SetPoint("RIGHT", footer, "RIGHT", -FOOTER_INSET, 0)
    local copy = copyFromRow(footer)
    copy:SetPoint("RIGHT", reset, "LEFT", -FOOTER_GAP, 0)
    Options.resetFrameButton, Options.copyRow = reset, copy
end

local function createFooter(parent)
    local footer = Chrome.Footer(parent)
    createFooterLeft(footer)
    createFooterRight(footer)
    frame.footerControls = { Options.unlockButton, Options.testButton, Options.copyRow, Options.resetFrameButton }
    return footer
end

-- Title bar ---------------------------------------------------------------------

local function createTitleBar(parent)
    return Chrome.TitleBar(parent, {
        title = L.ADDON_NAME,
        sub = "v" .. (C_AddOns.GetAddOnMetadata(ns.name, "Version") or ""),
        onDragStop = savePosition,
        onClose = function() Options.Close() end,
    })
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
        local clickPage = pages["general:clickCast"]
        if clickPage then clickPage.clickClearButton.Disarm() end
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
            if Options.page then
                -- Leaving the click-casting tab disarms its Clear all.
                if Options.page.clickClearButton then Options.page.clickClearButton.Disarm() end
                Options.page:Hide()
            end
            local page = pageFor(scope, tab)
            if page.onShow then page.onShow() end
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
    setRowStates()
    Options.languageRow:Refresh()
end)

-- The raid window's click-casting mode greys the switch here (Clique is
-- loaded or not before the window can open).
-- The click-casting tab shows the raid profile's bindings: a change from
-- either window (or Copy, Clear all) shows here.
ns.Listen("RAID_CONFIG_CHANGED", function(scope, key)
    if not Options.IsOpen() or (scope ~= nil and scope ~= "general") then return end
    if Options.page and Options.page.clickCast then forEachRow(function(row) row:Refresh() end) end
    if key == nil or key == "clickCast" then setRowStates() end
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

-- The unit frames' movers locked or unlocked from anywhere: this window,
-- /fuf, the minimap button, the start of combat.
ns.Listen("MOVERS_UNLOCKED", function(_, group)
    if frame and group == "units" then refreshFooter() end
end)

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
