local _, ns = ...

-- Builds single-unit frames (player, target, ...) and routes events to
-- their elements. Frames are secure buttons; everything that touches their
-- size, anchors or visibility runs out of combat.
local Single = {}
ns.Single = Single
ns.Frames = {}

local Config, Layout = ns.Config, ns.Layout

local function place(frame)
    local scope = frame.key
    frame:SetSize(Config.Get(scope, "width"), Config.Get(scope, "height"))
    frame:ClearAllPoints()
    if frame.mover then
        frame:SetPoint("CENTER", frame.mover, "CENTER", 0, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", Config.Get(scope, "x"), Config.Get(scope, "y"))
    end
end

local function layoutBars(frame)
    local scope = frame.key
    local height = Config.Get(scope, "height")
    local powerOn = Config.Get(scope, "powerEnabled")
    local hh, gap, ph = Layout.Bars(height, Config.Get(scope, "healthPercent"),
        Config.Get(scope, "powerPercent"), powerOn)
    frame.health:ClearAllPoints()
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.health:SetHeight(hh)
    if frame.power then
        frame.power:ClearAllPoints()
        frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame.power:SetHeight(math.max(ph, 1))
        frame.power:SetShown(powerOn and ph > 0)
    end
    frame.gap = gap
end

local function border(frame)
    local size = Config.Get(frame.key, "borderSize")
    local c = Config.Get(frame.key, "borderColor")
    if not frame.border then
        frame.border = {}
        for i = 1, 4 do frame.border[i] = frame:CreateTexture(nil, "OVERLAY") end
    end
    local b = frame.border
    -- top, bottom, left, right; drawn just outside the frame
    b[1]:ClearAllPoints(); b[1]:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -size, 0); b[1]:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", size, 0); b[1]:SetHeight(size)
    b[2]:ClearAllPoints(); b[2]:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -size, 0); b[2]:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", size, 0); b[2]:SetHeight(size)
    b[3]:ClearAllPoints(); b[3]:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0); b[3]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0); b[3]:SetWidth(size)
    b[4]:ClearAllPoints(); b[4]:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0); b[4]:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0); b[4]:SetWidth(size)
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
    if not UnitExists(frame.unit) then return end
    for _, el in ipairs(ns.Elements) do el.Update(frame, event) end
end

function Single.StyleAll(frame)
    if frame.mover then ns.Movers.Sync(frame) end
    place(frame)
    layoutBars(frame)
    border(frame)
    for _, el in ipairs(ns.Elements) do el.Style(frame) end
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
    ns.Frames[def.key] = frame
    Single.StyleAll(frame)
    return frame
end

-- Event routing ----------------------------------------------------------------

local unitEventsRegistered = false
local function registerUnitEvents()
    if unitEventsRegistered then return end
    unitEventsRegistered = true
    -- One handler per (element, event) pair: several elements may share an
    -- event (e.g. Health and Texts both watch UNIT_HEALTH) and each must
    -- still run its own Update. registerUnitEvents only runs once, so this
    -- does not create duplicate handlers on repeated calls.
    for _, el in ipairs(ns.Elements) do
        for _, event in ipairs(el.unitEvents or {}) do
            ns.On(event, function(_, unit)
                for _, frame in pairs(ns.Frames) do
                    if frame.unit == unit and UnitExists(unit) then el.Update(frame, event) end
                end
            end)
        end
    end
end

-- onBuilt (optional) runs right after the frames exist, inside the same
-- out-of-combat run that built them.
function Single.CreateAll(onBuilt)
    ns.AfterCombat("createSingle", function()
        for _, def in ipairs(ns.Units.List) do
            if not ns.Frames[def.key] then
                local frame = Single.Create(def)
                for _, event in ipairs(def.events) do
                    ns.On(event, function(e) Single.UpdateAll(frame, e) end)
                end
            end
        end
        registerUnitEvents()
        if onBuilt then onBuilt() end
    end)
end

ns.Listen("CONFIG_CHANGED", function(scope)
    ns.AfterCombat("restyle:" .. (scope or "all"), function()
        for key, frame in pairs(ns.Frames) do
            if scope == nil or scope == "general" or scope == key then Single.StyleAll(frame) end
        end
    end)
end)
