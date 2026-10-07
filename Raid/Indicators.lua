local _, ns = ...

-- Corner indicators of a raid cell: up to five small squares (the four
-- corners and the top centre), each showing while one of its spells is
-- on the unit (a HoT, a shield, a buff), in its own colour, with the time
-- left as a darkening swipe, a number, or not at all.
--
-- Each is an aura slot of the cell's container (Raid/CellAuras.lua) with
-- the container's own spell filter (candidateFilters.includeSpellIDs, a
-- map: Blizzard_AuraContainerUtil.lua looks up includeSpellIDs[spellId]).
-- Matching helpful auras by spell ID on group members is always allowed
-- (AuraContainerUtil.CanApplyIdentityCandidateFilters), in combat too; the
-- client picks the aura and shows the slot's frame, the addon reads
-- nothing. "Own casts only" adds PLAYER to the filter. A position without
-- spells makes no slot; one switched off later is disabled.
--
-- The square, its swipe and its number are regions of the slot's frame,
-- made in initializeFrame. Size, colour and the time display change only
-- out of combat; while auras are secret the frame refuses and they are
-- tried again after combat (Raid/CellAuras.lua).
local Indicators = {}
ns.RaidIndicators = Indicators

local Raid, Cell, Pixel, CellAuras = ns.Raid, ns.RaidCell, ns.Pixel, ns.RaidAuras
local get = Cell.Get

-- From the cell's edge, and the dark edge around the colour.
Indicators.INSET = 1
Indicators.EDGE = 1
Indicators.EDGE_COLOR = { 0, 0, 0, 1 }
-- The way in from each position.
local INWARD = { TOPLEFT = { 1, -1 }, TOPRIGHT = { -1, -1 }, BOTTOMLEFT = { 1, 1 }, BOTTOMRIGHT = { -1, 1 },
    TOP = { 0, -1 } }

-- The settings of a position share this start ("indicatorTopLeft").
function Indicators.Key(ind)
    return "indicator" .. ind.name
end

function Indicators.SlotKey(ind)
    return "indicator" .. ind.point
end

-- A spell list as the container wants it: spell ID -> true; nil for an
-- empty or unreadable list (the position is off).
function Indicators.SpellSet(text)
    local ids = Raid.SpellList(text or "")
    if not ids or #ids == 0 then return nil end
    local set = {}
    for _, id in ipairs(ids) do set[id] = true end
    return set
end

-- The size of the indicator at a point while it has spells, on the
-- pixel grid; nil while it is off (the dispel square, Raid/CellAuras.lua,
-- moves in beside it).
function Indicators.SizeAt(point)
    for _, ind in ipairs(Raid.INDICATORS) do
        local key = Indicators.Key(ind)
        if ind.point == point and Indicators.SpellSet(get(key .. "Spells")) then
            return Pixel.Snap(get(key .. "Size"), nil, 1)
        end
    end
    return nil
end

function Indicators.Filter(key)
    return get(key .. "Own") and "HELPFUL|PLAYER" or "HELPFUL"
end

-- Size, place, colour and font of a position's frame (a slot's, or a
-- pretend cell's plain one).
local function place(frame, button, ind)
    local key = Indicators.Key(ind)
    local size = Pixel.Snap(get(key .. "Size"), nil, 1)
    local inset, edge = Pixel.Snap(Indicators.INSET), Pixel.Snap(Indicators.EDGE, nil, 1)
    local d = INWARD[ind.point]
    button:SetSize(size, size)
    button:ClearAllPoints()
    button:SetPoint(ind.point, frame, ind.point, d[1] * inset, d[2] * inset)
    button.color:ClearAllPoints()
    button.color:SetPoint("TOPLEFT", button, "TOPLEFT", edge, -edge)
    button.color:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -edge, edge)
    local c = get(key .. "Color")
    button.color:SetVertexColor(c[1], c[2], c[3], c[4])
    local font = ns.Media.Font(ns.Config.Get(frame.key, "fontFace"))
    ns.Texts.SetFont(button.time, font, math.max(6, size), "OUTLINE")
end

-- The slot's frame: placed, and its time display handed to the client.
local function look(frame, button, ind)
    place(frame, button, ind)
    local time = get(Indicators.Key(ind) .. "Time")
    if time == "SWIPE" then
        button:SetDurationCooldown(button.cooldown)
    else
        button:ClearDurationCooldown()
        button.cooldown:Clear()
    end
    if time == "NUMBER" then
        button:SetDurationText(button.time)
    else
        button:ClearDurationText()
        button.time:SetText("")
    end
end

-- The frame's regions: a dark edge, the colour, a swipe that darkens as
-- the time runs out, a number.
local function regions(button)
    local e = Indicators.EDGE_COLOR
    button.edge = button:CreateTexture(nil, "BACKGROUND")
    button.edge:SetAllPoints(button)
    button.edge:SetColorTexture(e[1], e[2], e[3], e[4])
    button.color = button:CreateTexture(nil, "ARTWORK")
    button.color:SetColorTexture(1, 1, 1, 1)
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.color)
    button.cooldown:SetReverse(true)
    button.cooldown:SetDrawEdge(false)
    button.cooldown:SetHideCountdownNumbers(true)
    button.time = button:CreateFontString(nil, "OVERLAY")
    button.time:SetPoint("CENTER", button, "CENTER", 0, 0)
end

-- A slot's frame. No mouse: the cell below takes it.
local function init(frame, button, ind)
    pcall(button.SetMouseClickEnabled, button, false)
    pcall(button.SetMouseMotionEnabled, button, false)
    regions(button)
    look(frame, button, ind)
end

-- Test mode: what a sample's time display shows.
Indicators.SAMPLE_DURATION = 15
Indicators.SAMPLE_LEFT = 12

CellAuras.AddPart({
    Apply = function(frame, container)
        local refused = false
        for _, ind in ipairs(Raid.INDICATORS) do
            local key = Indicators.Key(ind)
            local spells = Indicators.SpellSet(get(key .. "Spells"))
            -- Hidden auras (Raid/CellAuras.lua): left out even when listed here.
            local filters = spells and { includeSpellIDs = spells, excludeSpellIDs = CellAuras.BlockSet() }
            local slot = CellAuras.SetSlot(frame, container, Indicators.SlotKey(ind), Indicators.Filter(key),
                spells ~= nil, function(f, b) init(f, b, ind) end, filters)
            if slot and not pcall(look, frame, slot, ind) then refused = true end
        end
        return refused
    end,
    BuildSample = function(frame, samples)
        samples.indicators = {}
        for i in ipairs(Raid.INDICATORS) do
            local button = CreateFrame("Frame", nil, frame)
            regions(button)
            button:Hide()
            samples.indicators[i] = button
        end
    end,
    -- Every position with spells, on a living member.
    ShowSample = function(frame, samples, member, start)
        for i, ind in ipairs(Raid.INDICATORS) do
            local button, key = samples.indicators[i], Indicators.Key(ind)
            local shown = member ~= nil and not member.status and Indicators.SpellSet(get(key .. "Spells")) ~= nil
            button:SetFrameLevel(frame:GetFrameLevel() + CellAuras.LEVELS + 1)
            place(frame, button, ind)
            local time = get(key .. "Time")
            local elapsed = Indicators.SAMPLE_DURATION - Indicators.SAMPLE_LEFT
            if shown and time == "SWIPE" then
                button.cooldown:SetCooldown(start - elapsed, Indicators.SAMPLE_DURATION)
            else
                button.cooldown:Clear()
            end
            button.time:SetText(shown and time == "NUMBER" and tostring(Indicators.SAMPLE_LEFT) or "")
            button:SetShown(shown)
        end
    end,
})
