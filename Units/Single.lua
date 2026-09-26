local _, ns = ...

-- Builds single-unit frames (player, target, ...) and routes events to
-- their elements. Frames are secure buttons; everything that touches their
-- size, anchors or visibility runs out of combat.
local Single = {}
ns.Single = Single
ns.Frames = {}

local Config, Layout, Pixel = ns.Config, ns.Layout, ns.Pixel

-- Width and height of a unit frame of scope, on the pixel grid.
function Single.Size(scope)
    return Pixel.Snap(Config.Get(scope, "width")), Pixel.Snap(Config.Get(scope, "height"))
end

-- The size a frame's contents are laid out for: its configured size, or
-- in combat the size it actually has. A button the group header makes in
-- combat keeps its XML size until the relayout after combat (Units/
-- Party.lua), and its bars and texts must fit that size until then.
function Single.LayoutSize(frame)
    local w, h = Single.Size(frame.key)
    if not InCombatLockdown() then return w, h end
    local actualW, actualH = frame:GetWidth(), frame:GetHeight()
    if actualW > 0 and actualH > 0 then return actualW, actualH end
    return w, h
end

-- Border thickness of scope on the pixel grid (ns.Border.Size).
function Single.BorderSize(scope)
    return ns.Border.Size(scope)
end

local function place(frame)
    local scope = frame.key
    local w, h = Single.Size(scope)
    frame:SetSize(w, h)
    frame:ClearAllPoints()
    if frame.mover then
        frame:SetPoint("CENTER", frame.mover, "CENTER", 0, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER",
            Pixel.Centre(Config.Get(scope, "x"), w), Pixel.Centre(Config.Get(scope, "y"), h))
    end
end

-- The split is worked out in whole units, then put on the pixel grid:
-- title row and power bar are snapped, health takes the rest of the
-- (snapped) frame height, so the rows always fill the frame exactly.
local function layoutBars(frame)
    local scope = frame.key
    local frameWidth, height = Single.LayoutSize(frame)
    frame.layoutHeight = height
    -- The rows are shares of the configured height, or of the actual one
    -- while that differs (see Single.LayoutSize).
    local _, configured = Single.Size(scope)
    local rowsHeight = height == configured and Config.Get(scope, "height") or height
    local powerOn = Config.Get(scope, "powerEnabled")
    local th, _, ph = Layout.Rows(rowsHeight, Config.Get(scope, "titlePercent"),
        Config.Get(scope, "healthPercent"), Config.Get(scope, "powerPercent"), powerOn)
    local powerShown = powerOn and ph > 0
    local pixel = Pixel.Snap(1, nil, 1)
    local titleH = th > 0 and Pixel.Snap(th, nil, 1) or 0
    local powerH = powerShown and Pixel.Snap(ph, nil, 1) or 0
    local healthH = math.max(height - titleH - powerH, pixel)
    local left, right = Layout.PortraitInsets(Config.Get(scope, "portraitMode"), height)
    local title = frame.title
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", left, 0)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, 0)
    title:SetHeight(math.max(titleH, pixel))
    title:SetShown(titleH > 0)
    frame.titleHeight = titleH
    frame.titleLeft, frame.titleRight = left, right
    local width = frameWidth - left - right
    -- The overheal lane (Elements/HealPrediction.lua) takes the end of
    -- the health bar's row; the title row keeps the full width, the power
    -- bar too unless it is set to match the health bar.
    local lane = 0
    if Config.Get(scope, "healPrediction") and Config.Get(scope, "healOverflow") then
        lane = Pixel.Snap(Layout.OverhealLane(width))
    end
    frame.healthWidth, frame.overhealLane = width - lane, lane
    frame.health:ClearAllPoints()
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -titleH)
    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(right + lane), -titleH)
    frame.health:SetHeight(healthH)
    if frame.power then
        frame.power:ClearAllPoints()
        frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, 0)
        local powerLane = Config.Get(scope, "powerMatchesHealth") and lane or 0
        frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(right + powerLane), 0)
        frame.power:SetHeight(powerShown and powerH or pixel)
        frame.power:SetShown(powerShown)
    end
end

local function applyEnabled(frame)
    if Config.Get(frame.key, "enabled") then
        RegisterUnitWatch(frame)
    else
        UnregisterUnitWatch(frame)
        frame:Hide()
    end
end

-- Test mode: every element with sample data shows (or drops) it.
function Single.Preview(frame, on)
    for _, el in ipairs(ns.Elements) do
        if el.Preview then el.Preview(frame, on) end
    end
end

function Single.UpdateAll(frame, event)
    if not frame.unit or not UnitExists(frame.unit) then return end
    for _, el in ipairs(ns.Elements) do el.Update(frame, event) end
end

-- Everything inside a unit button that is not itself protected: bars and
-- element regions (the border is Elements/Shape.lua). Party buttons use
-- this in combat too.
function Single.StyleContent(frame)
    layoutBars(frame)
    for _, el in ipairs(ns.Elements) do el.Style(frame) end
end

function Single.StyleAll(frame)
    if frame.mover then ns.Movers.Sync(frame) end
    place(frame)
    Single.StyleContent(frame)
    applyEnabled(frame)
    Single.UpdateAll(frame)
end

function Single.Create(def)
    local frame = CreateFrame("Button", "ForeverUnitFrames_" .. def.key, UIParent, "SecureUnitButtonTemplate")
    ns.Units.EnableTooltip(frame)
    frame.key, frame.unit = def.key, def.unit
    frame:SetAttribute("unit", def.unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
    frame:RegisterForClicks("AnyUp")
    for _, el in ipairs(ns.Elements) do el.Build(frame) end
    ns.UnitEvents.Bind(frame)
    ns.Frames[def.key] = frame
    Single.StyleAll(frame)
    return frame
end

-- Points a frame at another unit: the secure attribute for clicks, the
-- Lua field for updates, and its event registrations. Out of combat only
-- (the attribute is protected).
function Single.SetUnit(frame, unit)
    frame.unit = unit
    frame:SetAttribute("unit", unit)
    ns.UnitEvents.Bind(frame)
end

-- The event an Update gets when a timer, not the game, asked for it.
Single.POLL = "FUF_POLL"

-- Whole-frame refreshes: the unit changed (target, pet, ...).
local function listen(frame, def)
    local listener = CreateFrame("Frame")
    for _, event in ipairs(def.events) do
        local unit = def.eventUnit and def.eventUnit[event]
        if unit then listener:RegisterUnitEvent(event, unit) else listener:RegisterEvent(event) end
    end
    listener:SetScript("OnEvent", function(_, event) Single.UpdateAll(frame, event) end)
end

-- Plain driver frame: OnUpdate on the secure button itself is not needed.
function Single.Poll(frame, interval)
    local driver, elapsedTotal = CreateFrame("Frame"), 0
    driver:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < interval then return end
        elapsedTotal = 0
        if frame:IsShown() then Single.UpdateAll(frame, Single.POLL) end
    end)
    frame.pollDriver = driver
end

-- onBuilt (optional) runs right after the frames exist, inside the same
-- out-of-combat run that built them. Group entries (party) are built by
-- their own module.
function Single.CreateAll(onBuilt)
    ns.AfterCombat("createSingle", function()
        for _, def in ipairs(ns.Units.List) do
            local usable = def.available == nil or def.available()
            if def.unit and usable and not ns.Frames[def.key] then
                local frame = Single.Create(def)
                listen(frame, def)
                if def.poll then Single.Poll(frame, def.poll) end
            end
        end
        if onBuilt then onBuilt() end
    end)
end

local function restyle(scope)
    ns.AfterCombat("restyle:" .. (scope or "all"), function()
        for key, frame in pairs(ns.Frames) do
            if scope == nil or scope == "general" or scope == key then Single.StyleAll(frame) end
        end
    end)
end
ns.Listen("CONFIG_CHANGED", restyle)
ns.Listen("PIXEL_GRID_CHANGED", function() restyle(nil) end)
