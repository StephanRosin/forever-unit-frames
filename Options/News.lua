local _, ns = ...

-- The What's New window: one version's news (Core/News.lua) as a list,
-- in the style of the options windows (the same colours, title bar and
-- close cross). Its left button runs the entry's action (0.22.0: opens
-- the raid options window) and closes it; Close closes it. A plain
-- (non-secure) frame; ESC closes it too. Every text is set when it
-- opens, and again when the language changes while it is open.
local NewsWindow = {}
ns.NewsWindow = NewsWindow

local Style, Widgets, L = ns.Style, ns.Widgets, ns.L

local WINDOW_NAME = "ForeverUnitFramesNews"
local WIDTH, MIN_HEIGHT, MAX_HEIGHT = 560, 440, 600
local TITLE_H, FOOTER_H, INSET, LINE_GAP, BULLET_W = 32, 40, 16, 8, 12
local FONT_SIZE = 13
local BUTTON_W, WIDE_BUTTON_W, GAP, FOOTER_INSET, BUTTON_PADDING = 120, 160, 8, 12, 16
-- The action button may take the footer up to the Close button.
local MAX_ACTION_W = WIDTH - 2 * FOOTER_INSET - BUTTON_W - GAP
local CROSS_SIZE, CROSS_ANGLE = 14, math.pi / 4

local frame
local shownVersion

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

-- The × glyph is not in every game font, so it is drawn from two lines
-- (as in the options windows).
local function closeCross(titleBar)
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
    b:SetScript("OnClick", function() NewsWindow.Close() end)
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
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    bar.title = Style.Text(bar, 16, "text")
    bar.title:SetPoint("LEFT", bar, "LEFT", INSET, 0)
    bar.addon = Style.Text(bar, 11, "muted")
    bar.addon:SetPoint("BOTTOMLEFT", bar.title, "BOTTOMRIGHT", 8, 1)
    bar.close = closeCross(bar)
    return bar
end

local function runAction()
    local entry = ns.News.Entry(shownVersion)
    NewsWindow.Close()
    if entry and entry.action then entry.action.run() end
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    local close = Widgets.Button(footer, { text = "", width = BUTTON_W, onClick = function() NewsWindow.Close() end })
    close:SetPoint("RIGHT", footer, "RIGHT", -FOOTER_INSET, 0)
    local action = Widgets.Button(footer, { text = "", width = WIDE_BUTTON_W, onClick = runAction })
    action:SetPoint("RIGHT", close, "LEFT", -GAP, 0)
    NewsWindow.closeButton, NewsWindow.actionButton = close, action
    return footer
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
    frame.titleBar = createTitleBar(frame)
    frame.footer = createFooter(frame)
    NewsWindow.lines = {}
    frame:Hide()
    table.insert(UISpecialFrames, WINDOW_NAME)
end

-- The i-th line of the list: a bullet and a text that wraps.
local function listLine(i)
    local entry = NewsWindow.lines[i]
    if entry then return entry end
    local bullet = Style.Text(frame, FONT_SIZE, "accent")
    bullet:SetText("•")
    local text = Style.Text(frame, FONT_SIZE, "text")
    text:SetWidth(WIDTH - 2 * INSET - BULLET_W)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    if i == 1 then
        text:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", INSET + BULLET_W, -INSET)
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

-- The window as tall as its list (between MIN_HEIGHT and MAX_HEIGHT). A
-- line the client has not measured counts as one line of text.
local function fitHeight(count)
    local listHeight = 0
    for i = 1, count do
        local h = NewsWindow.lines[i].text:GetStringHeight()
        if not h or h <= 0 then h = FONT_SIZE end
        listHeight = listHeight + h
    end
    listHeight = listHeight + math.max(0, count - 1) * LINE_GAP
    local height = TITLE_H + INSET + listHeight + INSET + FOOTER_H
    frame:SetHeight(math.min(MAX_HEIGHT, math.max(MIN_HEIGHT, height)))
end

local function render()
    local entry = ns.News.Entry(shownVersion)
    if not entry then return end
    frame.titleBar.title:SetText(L.NEWS_TITLE:format(shownVersion))
    frame.titleBar.addon:SetText(L.ADDON_NAME)
    for i, key in ipairs(entry.lines) do
        local item = listLine(i)
        item.text:SetText(L[key])
        item.bullet:Show(); item.text:Show()
    end
    for i = #entry.lines + 1, #NewsWindow.lines do
        NewsWindow.lines[i].bullet:Hide(); NewsWindow.lines[i].text:Hide()
    end
    NewsWindow.closeButton.text:SetText(L.NEWS_CLOSE)
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
