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

-- Border thickness of scope on the pixel grid: at least one pixel unless
-- the border is off.
function Single.BorderSize(scope)
    local size = Config.Get(scope, "borderSize")
    if size <= 0 then return 0 end
    return Pixel.Snap(size, nil, 1)
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
-- title row, power bar and gap are snapped, health takes the rest of the
-- (snapped) frame height, so the rows always fill the frame exactly.
local function layoutBars(frame)
    local scope = frame.key
    local _, height = Single.Size(scope)
    local powerOn = Config.Get(scope, "powerEnabled")
    local th, _, gap, ph = Layout.Rows(Config.Get(scope, "height"), Config.Get(scope, "titlePercent"),
        Config.Get(scope, "healthPercent"), Config.Get(scope, "powerPercent"), powerOn)
    local powerShown = powerOn and ph > 0
    local pixel = Pixel.Snap(1, nil, 1)
    local titleH = th > 0 and Pixel.Snap(th, nil, 1) or 0
    local powerH = powerShown and Pixel.Snap(ph, nil, 1) or 0
    gap = powerShown and Pixel.Snap(gap) or 0
    local healthH = math.max(height - titleH - gap - powerH, pixel)
    local left, right = Layout.PortraitInsets(Config.Get(scope, "portraitMode"), height)
    local title = frame.title
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", left, 0)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, 0)
    title:SetHeight(math.max(titleH, pixel))
    title:SetShown(titleH > 0)
    frame.titleHeight = titleH
    frame.titleLeft, frame.titleRight = left, right
    frame.health:ClearAllPoints()
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -titleH)
    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -right, -titleH)
    frame.health:SetHeight(healthH)
    if frame.power then
        frame.power:ClearAllPoints()
        frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left, 0)
        frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -right, 0)
        frame.power:SetHeight(powerShown and powerH or pixel)
        frame.power:SetShown(powerShown)
    end
    frame.gap = gap
end

-- A 1-2 px border just outside owner (a unit frame or its castbar), in the
-- border size and colour of scope.
function Single.DrawBorder(owner, scope)
    local size = Single.BorderSize(scope)
    local c = Config.Get(scope, "borderColor")
    if not owner.border then
        owner.border = {}
        for i = 1, 4 do owner.border[i] = owner:CreateTexture(nil, "OVERLAY") end
    end
    local b = owner.border
    -- top, bottom, left, right; drawn just outside the owner
    b[1]:ClearAllPoints(); b[1]:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", -size, 0); b[1]:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", size, 0); b[1]:SetHeight(size)
    b[2]:ClearAllPoints(); b[2]:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", -size, 0); b[2]:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", size, 0); b[2]:SetHeight(size)
    b[3]:ClearAllPoints(); b[3]:SetPoint("TOPRIGHT", owner, "TOPLEFT", 0, 0); b[3]:SetPoint("BOTTOMRIGHT", owner, "BOTTOMLEFT", 0, 0); b[3]:SetWidth(size)
    b[4]:ClearAllPoints(); b[4]:SetPoint("TOPLEFT", owner, "TOPRIGHT", 0, 0); b[4]:SetPoint("BOTTOMLEFT", owner, "BOTTOMRIGHT", 0, 0); b[4]:SetWidth(size)
    for i = 1, 4 do
        b[i]:SetColorTexture(c[1], c[2], c[3], c[4])
        b[i]:SetShown(size > 0)
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

function Single.UpdateAll(frame, event)
    if not frame.unit or not UnitExists(frame.unit) then return end
    for _, el in ipairs(ns.Elements) do el.Update(frame, event) end
end

-- Everything inside a unit button that is not itself protected: bars,
-- border, element regions. Party buttons use this in combat too.
function Single.StyleContent(frame)
    layoutBars(frame)
    Single.DrawBorder(frame, frame.key)
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
