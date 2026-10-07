local _, ns = ...

-- The What's New window: one version's news (Core/News.lua) as a list,
-- in the style of the options windows (the same colours, title bar and
-- close cross). Its left button runs the entry's action (0.22.0: opens
-- the raid options window) and closes it; Close closes it. A plain
-- (non-secure) frame; ESC closes it too; /fuf news opens it again (its
-- footer says so). The list scrolls (mouse wheel) when it is taller than
-- the window allows. Above the footer, where to report a bug: the
-- project's address in a box that looks read-only and selects it all on
-- focus or click, so Ctrl+C copies it; typing puts it back. Every text is
-- set when it opens, and again when the language changes while it is
-- open.
local NewsWindow = {}
ns.NewsWindow = NewsWindow

local Style, Widgets, Chrome, L = ns.Style, ns.Widgets, ns.Chrome, ns.L

local WINDOW_NAME = "ForeverUnitFramesNews"
local WIDTH, MIN_HEIGHT, MAX_HEIGHT = 560, 440, 600
local TITLE_H, FOOTER_H = Chrome.TITLE_H, Chrome.FOOTER_H
local INSET, LINE_GAP, BULLET_W = 16, 8, 12
-- The bug report area: its hint on top, the address box below.
local REPORT_H, REPORT_TOP, ADDRESS_W, ADDRESS_H = 52, 8, 260, 20
local WHEEL_STEP, THUMB_W = 20, 2
NewsWindow.BUG_ADDRESS = "foreverwowui@gmail.com"
local FONT_SIZE = 13
local BUTTON_W, WIDE_BUTTON_W, GAP, FOOTER_INSET, BUTTON_PADDING = 120, 160, 8, 12, 16
-- The widest action button: what the footer leaves beside the Close
-- button, the footer hint's least width (HINT_MIN_W) and the gaps.
local HINT_MIN_W = 140
local MAX_ACTION_W = WIDTH - FOOTER_INSET - BUTTON_W - GAP - GAP - HINT_MIN_W - INSET

local frame
local shownVersion

local function runAction()
    local entry = ns.News.Entry(shownVersion)
    NewsWindow.Close()
    if entry and entry.action then entry.action.run() end
end

local function createFooter(parent)
    local footer = Chrome.Footer(parent)
    local close = Widgets.Button(footer, { text = "", width = BUTTON_W, onClick = function() NewsWindow.Close() end })
    close:SetPoint("RIGHT", footer, "RIGHT", -FOOTER_INSET, 0)
    local action = Widgets.Button(footer, { text = "", width = WIDE_BUTTON_W, onClick = runAction })
    action:SetPoint("RIGHT", close, "LEFT", -GAP, 0)
    -- The hint takes the room left of the (variable-width) action button
    -- and wraps there rather than run under it.
    local hint = Style.Text(footer, 11, "muted")
    hint:SetPoint("LEFT", footer, "LEFT", INSET, 0)
    hint:SetPoint("RIGHT", action, "LEFT", -GAP, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    NewsWindow.closeButton, NewsWindow.actionButton, NewsWindow.hint = close, action, hint
    return footer
end

-- The address: selected in full on focus and click, put back when typed
-- over; ESC and Enter let go of the focus.
local function selectAll(box) box:HighlightText() end
local function createAddressBox(parent)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(ADDRESS_W, ADDRESS_H)
    box:SetAutoFocus(false)
    box:SetFont(ns.Media.Font("Friz Quadrata"), 12, "")
    Style.Paint(box, "accent")
    box:SetText(NewsWindow.BUG_ADDRESS)
    box:SetCursorPosition(0)
    box:SetScript("OnEditFocusGained", selectAll)
    box:SetScript("OnMouseUp", selectAll)
    box:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
    box:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        self:SetText(NewsWindow.BUG_ADDRESS)
        self:HighlightText()
    end)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    return box
end

local function createReport(parent)
    local report = CreateFrame("Frame", nil, parent)
    report:SetHeight(REPORT_H)
    report:SetPoint("BOTTOMLEFT", parent.footer, "TOPLEFT")
    report:SetPoint("BOTTOMRIGHT", parent.footer, "TOPRIGHT")
    Chrome.HorizontalLine(report, "TOP")
    local hint = Style.Text(report, 11, "muted")
    hint:SetPoint("TOPLEFT", report, "TOPLEFT", INSET, -REPORT_TOP)
    hint:SetJustifyH("LEFT")
    local address = createAddressBox(report)
    address:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -4)
    NewsWindow.bugHint, NewsWindow.bugAddress = hint, address
    return report
end

-- The list: a scroll frame between the title bar and the report area; a
-- thin bar on its right shows where the view is while it scrolls.
local function updateThumb()
    local scroll, thumb = NewsWindow.scroll, NewsWindow.scrollThumb
    local view, range = scroll:GetHeight(), NewsWindow.scrollRange or 0
    if range <= 0 then thumb:Hide(); return end
    local thumbH = math.max(20, view * view / (view + range))
    thumb:SetHeight(thumbH)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -4, -(view - thumbH) * scroll:GetVerticalScroll() / range)
    thumb:Show()
end

local function onWheel(scroll, delta)
    local v = scroll:GetVerticalScroll() - delta * WHEEL_STEP
    scroll:SetVerticalScroll(math.max(0, math.min(NewsWindow.scrollRange or 0, v)))
    updateThumb()
end

local function createList(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetPoint("TOPLEFT", parent.titleBar, "BOTTOMLEFT", 0, -INSET)
    scroll:SetSize(WIDTH, 1)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", onWheel)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(WIDTH, 1)
    scroll:SetScrollChild(child)
    local thumb = parent:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(unpack(Style.COLORS.accent))
    thumb:SetWidth(THUMB_W)
    thumb:Hide()
    NewsWindow.scroll, NewsWindow.listChild, NewsWindow.scrollThumb = scroll, child, thumb
end

local function createWindow()
    frame = CreateFrame("Frame", WINDOW_NAME, UIParent)
    NewsWindow.frame = frame
    frame:SetSize(WIDTH, MIN_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetDontSavePosition(true)
    frame:EnableMouse(true)
    Style.Fill(frame, "bg")
    Style.Border(frame)
    frame.titleBar = Chrome.TitleBar(frame, { sub = true, onClose = function() NewsWindow.Close() end })
    frame.footer = createFooter(frame)
    frame.report = createReport(frame)
    createList(frame)
    NewsWindow.lines = {}
    frame:Hide()
    table.insert(UISpecialFrames, WINDOW_NAME)
end

-- The i-th line of the list: a bullet and a text that wraps.
local function listLine(i)
    local entry = NewsWindow.lines[i]
    if entry then return entry end
    local child = NewsWindow.listChild
    local bullet = Style.Text(child, FONT_SIZE, "accent")
    bullet:SetText("•")
    local text = Style.Text(child, FONT_SIZE, "text")
    text:SetWidth(WIDTH - 2 * INSET - BULLET_W)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    if i == 1 then
        text:SetPoint("TOPLEFT", child, "TOPLEFT", INSET + BULLET_W, 0)
    else
        text:SetPoint("TOPLEFT", NewsWindow.lines[i - 1].text, "BOTTOMLEFT", 0, -LINE_GAP)
    end
    bullet:SetPoint("TOPRIGHT", text, "TOPLEFT", -4, 0)
    entry = { bullet = bullet, text = text }
    NewsWindow.lines[i] = entry
    return entry
end

-- The action button as wide as its label (at least the wide button, at
-- most up to the Close button).
local function fitActionButton()
    local button = NewsWindow.actionButton
    local textWidth = button.text:GetStringWidth() or 0
    local width = WIDE_BUTTON_W
    if textWidth > 0 then
        width = math.min(MAX_ACTION_W, math.max(WIDE_BUTTON_W, textWidth + 2 * BUTTON_PADDING))
    end
    button:SetWidth(width)
end

-- The window as tall as its list (between MIN_HEIGHT and MAX_HEIGHT); a
-- longer list scrolls, from its top. A line the client has not measured
-- counts as one line of text.
local FIXED_H = TITLE_H + INSET + INSET + REPORT_H + FOOTER_H
local function fitHeight(count)
    local listHeight = 0
    for i = 1, count do
        local h = NewsWindow.lines[i].text:GetStringHeight()
        if not h or h <= 0 then h = FONT_SIZE end
        listHeight = listHeight + h
    end
    listHeight = listHeight + math.max(0, count - 1) * LINE_GAP
    local height = math.min(MAX_HEIGHT, math.max(MIN_HEIGHT, FIXED_H + listHeight))
    frame:SetHeight(height)
    local view = height - FIXED_H
    NewsWindow.listChild:SetHeight(math.max(1, listHeight))
    NewsWindow.scroll:SetHeight(view)
    NewsWindow.scrollRange = math.max(0, listHeight - view)
    NewsWindow.scroll:UpdateScrollChildRect()
    NewsWindow.scroll:SetVerticalScroll(0)
    updateThumb()
end

local function render()
    local entry = ns.News.Entry(shownVersion)
    if not entry then return end
    frame.titleBar.title:SetText(L.NEWS_TITLE:format(shownVersion))
    frame.titleBar.sub:SetText(L.ADDON_NAME)
    for i, key in ipairs(entry.lines) do
        local item = listLine(i)
        item.text:SetText(L[key])
        item.bullet:Show(); item.text:Show()
    end
    for i = #entry.lines + 1, #NewsWindow.lines do
        NewsWindow.lines[i].bullet:Hide(); NewsWindow.lines[i].text:Hide()
    end
    NewsWindow.closeButton.text:SetText(L.NEWS_CLOSE)
    NewsWindow.hint:SetText(L.NEWS_AGAIN)
    NewsWindow.bugHint:SetText(L.NEWS_BUG)
    local action = entry.action
    NewsWindow.actionButton:SetShown(action ~= nil)
    if action then
        NewsWindow.actionButton.text:SetText(L[action.text])
        fitActionButton()
    end
    fitHeight(#entry.lines)
end

-- Public API ----------------------------------------------------------------------

function NewsWindow.IsOpen()
    return frame ~= nil and frame:IsShown()
end

-- Shows the news of a version; false (and nothing shown) when it has none.
function NewsWindow.Open(version)
    if not ns.News.Entry(version) then return false end
    if not frame then createWindow() end
    shownVersion = version
    render()
    frame:Show()
    return true
end

function NewsWindow.Close()
    if frame then frame:Hide() end
end

ns.Listen("LANGUAGE_CHANGED", function()
    if NewsWindow.IsOpen() then render() end
end)
