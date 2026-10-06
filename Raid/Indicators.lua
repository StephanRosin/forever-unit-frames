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

function Indicators.Filter(key)
    return get(key .. "Own") and "HELPFUL|PLAYER" or "HELPFUL"
end

-- Size, place, colour and time display of a position's frame.
local function look(frame, button, ind)
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
    local time = get(key .. "Time")
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
-- the time runs out, a number. No mouse: the cell below takes it.
local function init(frame, button, ind)
    pcall(button.SetMouseClickEnabled, button, false)
    pcall(button.SetMouseMotionEnabled, button, false)
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
    look(frame, button, ind)
end

CellAuras.AddPart({
    Apply = function(frame, container)
        local refused = false
        for _, ind in ipairs(Raid.INDICATORS) do
            local key = Indicators.Key(ind)
            local spells = Indicators.SpellSet(get(key .. "Spells"))
            local slot = CellAuras.SetSlot(frame, container, Indicators.SlotKey(ind), Indicators.Filter(key),
                spells ~= nil, function(f, b) init(f, b, ind) end, spells and { includeSpellIDs = spells })
            if slot and not pcall(look, frame, slot, ind) then refused = true end
        end
        return refused
    end,
})
