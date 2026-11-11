local _, ns = ...

-- Builds single-unit frames (player, target, ...) and routes events to
-- their elements. Frames are secure buttons; everything that touches their
-- size, anchors or visibility runs out of combat.
local Single = {}
ns.Single = Single
ns.Frames = {}

local Config, Layout, Pixel = ns.Config, ns.Layout, ns.Pixel

-- The portrait strip's height (portraitMode TOP), on the pixel grid; 0
-- without one. It is added to the frame's configured height.
function Single.PortraitStrip(scope)
    if Config.Get(scope, "portraitMode") ~= "TOP" then return 0 end
    return Pixel.Snap(Config.Get(scope, "portraitHeight"))
end

-- The footer row's height on the pixel grid, 0 without one; also added to
-- the configured height.
function Single.Footer(scope)
    return Pixel.Snap(Config.Get(scope, "footerHeight"))
end

-- Width and height of a unit frame of scope, on the pixel grid.
function Single.Size(scope)
    return Pixel.Snap(Config.Get(scope, "width")),
        Pixel.Snap(Config.Get(scope, "height")) + Single.PortraitStrip(scope) + Single.Footer(scope)
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

-- A frame of a column (def.count, the boss frames): the room from one
-- frame's bottom edge to the next one's top, a docked castbar between
-- included (as Units/Party.lua stacks its members).
function Single.ColumnGap(scope)
    return Pixel.Snap(Config.Get(scope, "bossSpacing")) + ns.Castbar.DockedDepth(scope)
end

-- The whole column's size: count frames and the gaps between them.
function Single.ColumnSize(scope, count)
    local w, h = Single.Size(scope)
    return w, count * h + (count - 1) * Single.ColumnGap(scope)
end

local function place(frame)
    local scope = frame.key
    local w, h = Single.Size(scope)
    frame:SetSize(w, h)
    frame:ClearAllPoints()
    if frame.index and frame.index > 1 then
        frame:SetPoint("TOP", frame.previous, "BOTTOM", 0, -Single.ColumnGap(scope))
    elseif frame.index then
        -- The column's top edge: the mover's (Movers.FrameSpec), or with
        -- the column's centre at x / y.
        if frame.mover then
            frame:SetPoint("TOP", frame.mover, "TOP", 0, 0)
        else
            local _, columnH = Single.ColumnSize(scope, frame.count)
            frame:SetPoint("TOP", UIParent, "CENTER", Pixel.Centre(Config.Get(scope, "x"), w),
                Pixel.Centre(Config.Get(scope, "y"), columnH) + columnH / 2)
        end
    elseif frame.mover then
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
    local _, configured = Single.Size(scope)
    -- The rows are shares of the configured height, or of the actual one
    -- while that differs (see Single.LayoutSize); a portrait strip and the
    -- footer row are not theirs.
    local strip, footer = Single.PortraitStrip(scope), Single.Footer(scope)
    local rowsHeight = height == configured and Config.Get(scope, "height") or height - strip - footer
    height = height - strip - footer
    frame.layoutHeight, frame.portraitStrip, frame.footerHeight = height, strip, footer
    -- Hidden for a unit without power (Elements/Power.lua): health takes the row.
    local powerOn = Config.Get(scope, "powerEnabled") and not frame.powerEmpty
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
    frame.footer:ClearAllPoints()
    frame.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.footer:SetHeight(math.max(footer, pixel))
    frame.footer:SetShown(footer > 0)
    frame.footerWidth = frameWidth
    local width = frameWidth - left - right
    frame.titleWidth = width
    -- The overheal lane (Elements/HealPrediction.lua) takes the end of
    -- the health bar's row; the title row keeps the full width, the power
    -- bar too unless it is set to match the health bar.
    local lane = 0
    if Config.Get(scope, "healPrediction") and Config.Get(scope, "healOverflow") then
        lane = Pixel.Snap(Layout.OverhealLane(width))
    end
    frame.healthWidth, frame.overhealLane = width - lane, lane
    frame.health:ClearAllPoints()
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -(titleH + strip))
    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(right + lane), -(titleH + strip))
    frame.health:SetHeight(healthH)
    if frame.power then
        frame.power:ClearAllPoints()
        frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, footer)
        local powerLane = Config.Get(scope, "powerMatchesHealth") and lane or 0
        frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(right + powerLane), footer)
        frame.powerWidth = width - powerLane
        frame.power:SetHeight(powerShown and powerH or pixel)
        frame.power:SetShown(powerShown)
    end
end

-- The rows again without restyling, e.g. when the power bar comes or goes;
-- plain frames only, so fine in combat.
Single.LayoutBars = layoutBars

-- What shows and hides an enabled frame: the unit watch (shown while its
-- unit exists), or for the player hidden in a group the game's visibility
-- driver (the player always exists). Out of combat only.
local GROUP_DRIVER = "[group] hide; show"

function Single.Watch(frame)
    if frame.key == "player" and Config.Get("player", "playerHideInGroup") then
        UnregisterUnitWatch(frame)
        RegisterStateDriver(frame, "visibility", GROUP_DRIVER)
    else
        UnregisterStateDriver(frame, "visibility")
        RegisterUnitWatch(frame)
    end
end

function Single.Unwatch(frame)
    UnregisterUnitWatch(frame)
    UnregisterStateDriver(frame, "visibility")
end

local function applyEnabled(frame)
    if ns.FrameEnabled(frame.key) then
        Single.Watch(frame)
    else
        Single.Unwatch(frame)
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

-- index (optional): the frame's place in a column of def.count, whose
-- unit is def.unit .. index; ns.Frames holds it under def.key .. index.
function Single.Create(def, index)
    local name = def.key .. (index or "")
    local unit = index and def.unit .. index or def.unit
    local frame = CreateFrame("Button", "ForeverUnitFrames_" .. name, UIParent, "SecureUnitButtonTemplate")
    ns.Units.EnableTooltip(frame)
    ns.Units.EnableClickCast(frame)
    frame.key, frame.unit = def.key, unit
    if index then
        frame.index, frame.count, frame.previous = index, def.count, ns.Frames[def.key .. (index - 1)]
    end
    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
    -- The ping key over the frame pings its unit, as PingableUnitFrameTemplate
    -- does for the XML buttons (Blizzard_SharedXML/PingAttributes.xml).
    ns.Units.EnablePing(frame)
    frame:SetAttribute("ping-receiver", true)
    frame:RegisterForClicks("AnyUp")
    for _, el in ipairs(ns.Elements) do el.Build(frame) end
    ns.UnitEvents.Bind(frame)
    ns.Frames[name] = frame
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
            for index = 1, def.count or 1 do
                local i = def.count and index or nil
                if def.unit and usable and not ns.Frames[def.key .. (i or "")] then
                    local frame = Single.Create(def, i)
                    listen(frame, def)
                    if def.poll then Single.Poll(frame, def.poll) end
                end
            end
        end
        if onBuilt then onBuilt() end
    end)
end

local function restyle(scope)
    ns.AfterCombat("restyle:" .. (scope or "all"), function()
        -- A column's frames hang from the one above: top to bottom.
        for _, def in ipairs(ns.Units.List) do
            for index = 1, def.count or 1 do
                local frame = ns.Frames[def.key .. (def.count and index or "")]
                if frame and (scope == nil or scope == "general" or scope == def.key) then Single.StyleAll(frame) end
            end
        end
    end)
end
ns.Listen("CONFIG_CHANGED", restyle)
ns.Listen("PIXEL_GRID_CHANGED", function() restyle(nil) end)
