local _, ns = ...

-- The raid options window, in the style of the unit frames' (the same
-- widgets and colours): a top bar General | 10 | 20 | 40 | Profiles and
-- which size the panel shows (decision 71). General: the tabs whose
-- settings belong to the character (Schema.PerCharacter); a size: the
-- tabs of that size's profile (the size shown now is marked); Profiles:
-- its page alone (Raid/Options/Profiles.lua: own profiles, copy, reset,
-- export, import), no menu tabs. A footer laid out like the unit frames' window's left side:
-- the raid panel's lock, test mode and the way to the unit frames'
-- window. A plain
-- (non-secure) frame: every change goes through ns.RaidConfig, whose
-- RAID_CONFIG_CHANGED listeners restyle the raid panel out of combat. In
-- combat the window stays open but its controls lock.
local RaidOptions = {}
ns.RaidOptions = RaidOptions

local Style, Widgets, Schema, Chrome, L = ns.Style, ns.Widgets, ns.RaidSchema, ns.Chrome, ns.L
local RaidConfig, Raid = ns.RaidConfig, ns.Raid

local WINDOW_NAME = "ForeverUnitFramesRaidOptions"
-- At most 900 wide: a 960-wide screen (the smallest UIParent) keeps a
-- margin; tabs that do not fit one row wrap into two (fitTabs).
local WIDTH, HEIGHT = 880, 560
local SIZE_BAR_H, TAB_H, NOTICE_H, SIZE_NOTICE_H = 40, 30, 26, 36
local SIZE_TAB_PADDING, TAB_PADDING, TAB_MIN_W, UNDERLINE_H, ACCENT_W = 24, 28, 70, 2, 3
local TAB_ROW_INSET, TAB_MIN_PADDING = 8, 12
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET, NOTE_H = 4, 16, 8, 16, 34
local BUTTON_H, DROPDOWN_W, GAP = 24, 160, 8
local DEFAULT_POSITION = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 90, y = -150 }

local frame
local pages = {}
local inCombat = false
-- The last menu tab of General and of the sizes, for the session.
local lastTab = {}

-- Helpers ---------------------------------------------------------------------

local line, horizontalLine = Chrome.Line, Chrome.HorizontalLine

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

-- More conversions by key, from the files of other tabs (Raid/Options/Buffs.lua).
RaidOptions.TYPED_VALUES = {}

local function typedValue(key)
    if RaidOptions.TYPED_VALUES[key] then return RaidOptions.TYPED_VALUES[key] end
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
RaidOptions.NewStack = newStack
-- The page's measures, for a page built elsewhere (Raid/Options/Arrangement.lua).
RaidOptions.PAGE = { width = CONTENT_W, inset = INSET, top = PAGE_TOP, bottom = PAGE_BOTTOM,
    sectionGap = SECTION_GAP, noteHeight = NOTE_H, gap = GAP }

-- Sections of the window's own, by name: (page, stack) adds their rows
-- (Raid/Options/Templates.lua's, which the Profiles page places).
RaidOptions.EXTRA_SECTIONS = {}

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

local paintSelection, hoverable = Chrome.PaintSelection, Chrome.Hoverable

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

-- Which part of the menu a tab is in: General (every setting of it the
-- character's) or the sizes.
local function groupOf(tab) return Schema.PerCharacter(tab) and "general" or "size" end

local function tabById(id)
    for _, tab in ipairs(Schema.TABS) do
        if tab.id == id then return tab end
    end
end

-- The tab a part opens on: the last one picked this session, else its first.
local function openingTab(group)
    if lastTab[group] then return lastTab[group] end
    for _, tab in ipairs(Schema.TABS) do
        if groupOf(tab) == group then return tab.id end
    end
end

-- Edited values of a size the panel does not show change nothing on
-- screen: the note says so (test mode would show the edited size); only
-- while a size is picked.
local function renderSizeNotice()
    local edited, shown = RaidOptions.Size(), ns.RaidCell.Size()
    local notice = RaidOptions.sizeNotice
    local on = edited ~= shown and RaidOptions.view == "size"
    if on then notice.text:SetText(L.RAID_EDITING_NOT_SHOWN:format(edited, shown)) end
    if on == notice:IsShown() then return end
    notice:SetShown(on)
    anchorScroll()
end

local function paintTopTab(b, selected)
    b:SetWidth((b.text:GetStringWidth() or 0) + SIZE_TAB_PADDING)
    paintSelection(b, selected, "muted")
    b.underline:SetShown(selected)
end

-- The top bar: the part picked underlined (a size: the edited one), the
-- size the panel shows now (test mode's preview included) says so; the
-- note on a size not shown.
local function renderSizeTabs()
    local shown, view = ns.RaidCell.Size(), RaidOptions.view
    paintTopTab(RaidOptions.generalTab, view == "general")
    for _, size in ipairs(Raid.SIZES) do
        local b = RaidOptions.sizeTabs[size]
        local text = sizeText(size)
        if size == shown then text = L.RAID_SIZE_SHOWN:format(text) end
        b.text:SetText(text)
        paintTopTab(b, view == "size" and size == RaidOptions.Size())
    end
    paintTopTab(RaidOptions.profilesTab, view == "profiles")
    renderSizeNotice()
end

-- A tab's width as it likes it: its word and the padding, at least
-- TAB_MIN_W.
local function naturalWidth(b)
    return math.max(TAB_MIN_W, (b.text:GetStringWidth() or 0) + TAB_PADDING)
end

local function naturalSum(buttons, first, last)
    local total = 0
    for i = first, last do total = total + naturalWidth(buttons[i]) end
    return total
end

-- One row of tabs, buttons first..last, from the top of the tab row: each
-- as wide as it likes; when that does not fit, every tab gets its word
-- and an equal share of what is left, at least TAB_MIN_PADDING.
local function layRow(buttons, first, last, row)
    local room = WIDTH - 2 * TAB_ROW_INSET
    local padding
    if naturalSum(buttons, first, last) > room then
        local letters = 0
        for i = first, last do letters = letters + (buttons[i].text:GetStringWidth() or 0) end
        padding = math.max(TAB_MIN_PADDING, math.floor((room - letters) / (last - first + 1)))
    end
    for i = first, last do
        local b = buttons[i]
        b:SetWidth(padding and ((b.text:GetStringWidth() or 0) + padding) or naturalWidth(b))
        b:ClearAllPoints()
        if i == first then
            b:SetPoint("TOPLEFT", frame.tabRow, "TOPLEFT", TAB_ROW_INSET, -(row - 1) * TAB_H)
        else
            b:SetPoint("LEFT", buttons[i - 1], "RIGHT", 0, 0)
        end
    end
end

-- The tabs in one row when they fit as they like; else in two, split as
-- evenly as the first row allows (each row then fitted on its own). The
-- tab row is as tall as its rows; the page hangs below it.
local function fitTabs(buttons)
    local n, room = #buttons, WIDTH - 2 * TAB_ROW_INSET
    local split = n
    if naturalSum(buttons, 1, n) > room then
        split = math.ceil(n / 2)
        while split > 1 and naturalSum(buttons, 1, split) > room do split = split - 1 end
    end
    layRow(buttons, 1, split, 1)
    if split < n then layRow(buttons, split + 1, n, 2) end
    frame.tabRow:SetHeight((split < n and 2 or 1) * TAB_H)
end

-- Every menu tab's button; only those of the part picked show.
local function menuTabs()
    for i, tab in ipairs(Schema.TABS) do
        local b = tabButton(frame.tabRow, TAB_H)
        b.tabId, b.group = tab.id, groupOf(tab)
        b.text:SetText(Schema.TabTitle(tab.id))
        b:SetScript("OnClick", function(self) RaidOptions.SelectTab(self.tabId) end)
        b:Hide()
        RaidOptions.tabButtons[i] = b
    end
end

-- General or a size: its tabs show, laid out anew; Profiles: no tabs.
local function setView(view)
    if RaidOptions.view == view then return end
    RaidOptions.view = view
    frame.tabRow:SetShown(view ~= "profiles")
    local shown = {}
    for _, b in ipairs(RaidOptions.tabButtons) do
        b:SetShown(b.group == view)
        if b.group == view then shown[#shown + 1] = b end
    end
    if #shown > 0 then fitTabs(shown) end
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
-- The size bar's margins: the tabs from the left, the size mode's
-- dropdown from the right, the gap before its label.
RaidOptions.SIZE_BAR_LEFT, RaidOptions.SIZE_BAR_RIGHT, RaidOptions.SIZE_BAR_GAP = 8, 12, GAP

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
    row:SetPoint("RIGHT", bar, "RIGHT", -RaidOptions.SIZE_BAR_RIGHT, 0)
    local label = Style.Text(bar, 12, "muted")
    label:SetPoint("RIGHT", row, "LEFT", -RaidOptions.SIZE_BAR_GAP, 0)
    label:SetText(Schema.Label("sizeMode"))
    RaidOptions.sizeModeLabel = label
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
    local general = tabButton(bar, SIZE_BAR_H)
    general.text:SetText(L.RAID_GENERAL_TAB)
    general:SetScript("OnClick", function() RaidOptions.ShowGeneral() end)
    general:SetPoint("LEFT", bar, "LEFT", RaidOptions.SIZE_BAR_LEFT, 0)
    RaidOptions.generalTab = general
    RaidOptions.sizeTabs = {}
    local previous = general
    for _, size in ipairs(Raid.SIZES) do
        local b = tabButton(bar, SIZE_BAR_H)
        b:SetScript("OnClick", function() RaidOptions.SelectSize(size) end)
        b:SetPoint("LEFT", previous, "RIGHT", 0, 0)
        RaidOptions.sizeTabs[size] = b
        previous = b
    end
    local profiles = tabButton(bar, SIZE_BAR_H)
    profiles.text:SetText(L.RAID_PROFILES_TAB)
    profiles:SetScript("OnClick", function() RaidOptions.ShowProfiles() end)
    profiles:SetPoint("LEFT", previous, "RIGHT", 0, 0)
    RaidOptions.profilesTab = profiles
    RaidOptions.sizeModeRow = sizeModeRow(bar)
    frame.sizeBar = bar
end

-- Combat lock -------------------------------------------------------------------

-- Under the tabs (on the Profiles page, which has none: at the top): the
-- combat notice while in combat, then the note on the size edited, while
-- it is not the one shown; then the page.
function anchorScroll()
    local top, edge = frame.tabRow, "BOTTOM"
    if not frame.tabRow:IsShown() then top, edge = frame.body, "TOP" end
    for _, notice in ipairs({ RaidOptions.combatNotice, RaidOptions.sizeNotice }) do
        if notice:IsShown() then
            notice:ClearAllPoints()
            notice:SetPoint("TOPLEFT", top, edge .. "LEFT", 0, 0)
            notice:SetPoint("TOPRIGHT", top, edge .. "RIGHT", 0, 0)
            top, edge = notice, "BOTTOM"
        end
    end
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", top, edge .. "LEFT", 0, 0)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", -SCROLLBAR_W, 0)
end

local paintFooter

-- Rows that only mean something while another setting allows it: the
-- class order, while the edited size groups by class; the raid tools
-- bar's fold while it is docked, its position while it is free.
local function toolsDocked() return RaidConfig.Get("general", "toolsMode") == "DOCKED" end
local function toolsFree() return not toolsDocked() end
-- Other tabs' files add theirs (Raid/Options/Buffs.lua).
local ROW_ACTIVE = {
    classOrder = function() return RaidConfig.Get(Raid.Scope(RaidOptions.Size()), "groupBy") == "CLASS" end,
    toolsOpen = toolsDocked, toolsX = toolsFree, toolsY = toolsFree,
}
RaidOptions.ROW_ACTIVE = ROW_ACTIVE

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
    -- A custom page that keeps its own state of the lock refreshes once.
    if RaidOptions.page and RaidOptions.page.afterLock then RaidOptions.page.afterLock() end
    anchorScroll()
    paintFooter()
end

-- Title bar, footer, body ---------------------------------------------------------

local function createTitleBar(parent)
    return Chrome.TitleBar(parent, {
        title = L.RAID_WINDOW_TITLE,
        sub = L.ADDON_NAME,
        onDragStop = savePosition,
        onClose = function() RaidOptions.Close() end,
    })
end

-- What disarms the armed buttons of the window's pages (a second click
-- confirms) when the window hides or another size is edited: functions
-- (Raid/Options/Profiles.lua adds its own).
RaidOptions.DISARM = {}

local function disarmAll()
    for _, fn in ipairs(RaidOptions.DISARM) do fn() end
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
    local footer = Chrome.Footer(parent)
    createFooterLeft(footer)
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
    frame.lockedControls = { RaidOptions.sizeModeRow, RaidOptions.unlockButton, RaidOptions.testButton }
    -- Hiding the window (ESC, close button, /fuf raid) takes an open
    -- dropdown list and armed confirmations with it, and ends its test
    -- mode: the panel shows the active size again.
    frame:SetScript("OnHide", function()
        Widgets.CloseList()
        disarmAll()
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

-- Shows a page in the scroll area: its rows refresh and lock with the
-- window; page.onShow (optional) runs first.
local function showPage(page)
    Widgets.CloseList()
    if RaidOptions.page then RaidOptions.page:Hide() end
    if page.onShow then page.onShow() end
    RaidOptions.page, RaidOptions.rows = page, page.rows
    frame.scrollChild:SetHeight(page.height)
    frame.scroll:SetVerticalScroll(0)
    page:Show()
    forEachRow(function(row) row:Refresh() end)
    applyLock()
    updateScrollbar()
end

-- Profiles in the top bar: its page alone, no menu tabs.
local PROFILES_TAB = { id = "profiles", custom = "profiles" }

function RaidOptions.ShowProfiles()
    ensureWindow()
    setView("profiles")
    showPage(pageFor(PROFILES_TAB))
    renderSizeTabs()
end

-- A menu tab: General's or the edited size's part of the menu, whichever
-- holds it.
function RaidOptions.SelectTab(id)
    ensureWindow()
    if id == PROFILES_TAB.id then return RaidOptions.ShowProfiles() end
    local tab = tabById(id)
    if not tab then return end
    local group = groupOf(tab)
    setView(group)
    RaidOptions.currentTab, lastTab[group] = id, id
    showPage(pageFor(tab))
    paintTabs()
    renderSizeTabs()
end

-- General in the top bar: the character's tabs, on the last one picked.
function RaidOptions.ShowGeneral()
    RaidOptions.SelectTab(openingTab("general"))
end

-- Edits another size's profile: the rows read it from now on; what was
-- armed for the size before is not.
local function setSize(size)
    Raid.Scope(size)
    Widgets.CloseList()
    disarmAll()
    RaidOptions.size = size
    refreshAll()
    if frame:IsShown() then ns.RaidTestMode.Preview(size) end
end

-- A size in the top bar: that size's settings (from General or Profiles:
-- the size's tab picked last).
function RaidOptions.SelectSize(size)
    ensureWindow()
    setSize(size)
    if RaidOptions.view ~= "size" then RaidOptions.SelectTab(openingTab("size")) end
end

-- Without a size: the size edited while open, else the one the panel
-- shows now (not the one edited last time). Without a tab: the part of
-- the top bar picked last this session (a size given: the sizes), on its
-- last tab; the first time the size's first tab.
function RaidOptions.Open(size, tabId)
    if not RaidConfig.Profile() then return end
    ensureWindow()
    if InCombatLockdown() then inCombat = true end
    local given = size ~= nil
    if not frame:IsShown() then
        restorePosition()
        frame:Show()
        size = size or ns.RaidSize.Current()
    end
    setSize(size or RaidOptions.Size())
    if not tabId then
        local view = (not given and RaidOptions.view) or "size"
        tabId = view == "profiles" and PROFILES_TAB.id or openingTab(view)
    end
    RaidOptions.SelectTab(tabId)
    -- The setup wizard may offer itself (Raid/Wizard.lua).
    ns.Fire("RAID_WINDOW_OPENED")
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
-- The raid panel's mover locked or unlocked from anywhere: this window,
-- /fuf lock, the start of combat.
ns.Listen("MOVERS_UNLOCKED", function(_, group)
    if frame and group == "raid" then paintFooter() end
end)

-- Every label is set once, when its widget is built: a new language gets a
-- new window (as the unit frames' window does), on the same size and tab.
function RaidOptions.Rebuild()
    if not frame then return end
    local wasOpen, wasProfiles = frame:IsShown(), RaidOptions.view == "profiles"
    frame:Hide()
    frame, RaidOptions.frame = nil, nil
    pages = {}
    RaidOptions.page, RaidOptions.rows, RaidOptions.view = nil, nil, nil
    if wasOpen then RaidOptions.Open(RaidOptions.size, wasProfiles and PROFILES_TAB.id or RaidOptions.currentTab) end
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
