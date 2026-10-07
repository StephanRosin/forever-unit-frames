local _, ns = ...

-- The parts the addon's windows share (the unit frames' window, the raid
-- window, What's New, the raid setup wizard): the title bar with its close
-- cross, the footer strip, the hover paint of menu entries and the
-- two-click confirm button. Plain (non-secure) frames, in Options/Style.lua's
-- colours.
local Chrome = {}
ns.Chrome = Chrome

local Style, Widgets, L = ns.Style, ns.Widgets, ns.L

local TITLE_H, TITLE_SIZE, SUB_SIZE, FOOTER_H, INSET = 32, 16, 11, 40, 16
-- The bars' heights, for the windows that lay out around them.
Chrome.TITLE_H, Chrome.FOOTER_H = TITLE_H, FOOTER_H
-- The sub-title sits right of the title, on its baseline.
local SUB_GAP, SUB_RAISE = 8, 1
local CROSS_SIZE, CROSS_W, CROSS_ANGLE = 14, 2, math.pi / 4
local CONFIRM_W, CONFIRM_SECONDS = 160, 3

-- A texture of one of Style.COLORS (thin lines, accent bars).
function Chrome.Line(parent, colorKey)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(unpack(Style.COLORS[colorKey]))
    return t
end

-- A 1 px border-coloured line along parent's TOP or BOTTOM edge.
function Chrome.HorizontalLine(parent, anchor)
    local t = Chrome.Line(parent, "border")
    t:SetHeight(1)
    t:SetPoint(anchor .. "LEFT"); t:SetPoint(anchor .. "RIGHT")
    return t
end

-- The × glyph is not in every game font, so it is drawn from two lines:
-- muted, accent under the mouse. At the title bar's right end, as tall
-- and wide as the bar.
function Chrome.CloseCross(bar, onClick)
    local b = CreateFrame("Button", nil, bar)
    b:SetSize(TITLE_H, TITLE_H)
    b:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    b.lines = {}
    for i, angle in ipairs({ CROSS_ANGLE, -CROSS_ANGLE }) do
        local t = Chrome.Line(b, "muted")
        t:SetSize(CROSS_SIZE, CROSS_W)
        t:SetPoint("CENTER")
        t:SetRotation(angle)
        b.lines[i] = t
    end
    local function paint(colorKey)
        for _, t in ipairs(b.lines) do t:SetColorTexture(unpack(Style.COLORS[colorKey])) end
    end
    b:SetScript("OnEnter", function() paint("accent") end)
    b:SetScript("OnLeave", function() paint("muted") end)
    b:SetScript("OnClick", onClick)
    return b
end

-- The bar across the top of frame that drags it. opts (all optional):
-- title and sub (texts; the sub-title muted and smaller, right of the
-- title; sub = true: one whose text is set later), titleSize, line = false (no line under it), onDragStop (after
-- the move, e.g. to save the position), onClose (a close cross that calls
-- it). Keeps bar.title, bar.sub and bar.close.
function Chrome.TitleBar(frame, opts)
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    Style.Fill(bar, "panel")
    if opts.line ~= false then Chrome.HorizontalLine(bar, "BOTTOM") end
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if opts.onDragStop then opts.onDragStop() end
    end)
    bar.title = Style.Text(bar, opts.titleSize or TITLE_SIZE, "text")
    bar.title:SetPoint("LEFT", bar, "LEFT", INSET, 0)
    if opts.title then bar.title:SetText(opts.title) end
    if opts.sub ~= nil then
        bar.sub = Style.Text(bar, SUB_SIZE, "muted")
        bar.sub:SetPoint("BOTTOMLEFT", bar.title, "BOTTOMRIGHT", SUB_GAP, SUB_RAISE)
        if opts.sub ~= true then bar.sub:SetText(opts.sub) end
    end
    if opts.onClose then bar.close = Chrome.CloseCross(bar, opts.onClose) end
    return bar
end

-- The strip along the bottom of frame that holds its buttons (placed by
-- the window); line = false: no line above it.
function Chrome.Footer(frame, opts)
    local footer = CreateFrame("Frame", nil, frame)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    if not (opts and opts.line == false) then Chrome.HorizontalLine(footer, "TOP") end
    return footer
end

-- A menu entry selected (accent) or not (idleColor); Hoverable leaves a
-- selected one alone.
function Chrome.PaintSelection(entry, selected, idleColor)
    Style.Paint(entry.text, selected and "accent" or idleColor)
    entry.selected = selected
end

-- A menu entry's hover paint: "text" under the mouse, idleColor after,
-- unless it is selected (button.selected); button.hover (optional) is a
-- fill shown under the mouse.
function Chrome.Hoverable(button, idleColor)
    button:SetScript("OnEnter", function(self)
        if not self.selected then Style.Paint(self.text, "text") end
        if self.hover then self.hover:Show() end
    end)
    button:SetScript("OnLeave", function(self)
        if not self.selected then Style.Paint(self.text, idleColor) end
        if self.hover then self.hover:Hide() end
    end)
end

-- Two-click action: the first click arms the button for a few seconds, the
-- second runs it. armedText (optional): the armed button's word, for a
-- button narrower than L.CONFIRM needs. needed (optional): asked at the
-- first click; false runs the action at once (nothing to confirm).
-- onDisarm (optional): called when an armed button disarms without running
-- (time, Disarm), e.g. to take back what the first click said.
function Chrome.ConfirmButton(parent, text, action, armedText, needed, onDisarm)
    local button, armed
    local function paintArmed() if armed then Style.Paint(button.text, "error") end end
    local function disarm()
        armed = nil
        button.text:SetText(text)
        button:GetScript("OnLeave")(button)
    end
    local function disarmUnused()
        local was = armed
        disarm()
        if was and onDisarm then onDisarm() end
    end
    button = Widgets.Button(parent, { text = text, width = CONFIRM_W, onClick = function()
        if armed then disarm(); action(); return end
        if needed and not needed() then action(); return end
        local token = {}
        armed = token
        button.text:SetText(armedText or L.CONFIRM)
        paintArmed()
        C_Timer.After(CONFIRM_SECONDS, function() if armed == token then disarmUnused() end end)
    end })
    button:HookScript("OnEnter", paintArmed)
    button:HookScript("OnLeave", paintArmed)
    button.Disarm = disarmUnused
    return button
end
