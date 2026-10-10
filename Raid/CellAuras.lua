local _, ns = ...

-- The auras of a raid cell. The addon reads none itself (other members'
-- auras are secret in combat): a cell gets one aura container
-- (CustomAuraContainerTemplate) when it first shows a unit, and the
-- client fills what this file configures on it, in combat too. Parts add
-- their slots and groups to it:
-- * the centre icon: one aura slot (AddAuraSlot) with the most important
--   debuff you can dispel ("HARMFUL|RAID": RAID is "dispellable by the
--   player", AuraUtil.AuraFilters) or any dispellable one
--   ("HARMFUL|DISPELLABLE"), bordered in its type's colour through our
--   colour curve, as the unit frames' debuff icons are;
-- * or, in its place, the square: a slot with the same filter whose only
--   region is a texture filling a small frame in one of the cell's
--   corners, coloured by the client from the borders' curve; beside a
--   corner indicator in the same corner (Raid/Indicators.lua), not under
--   it;
-- * the tint: a further slot with the same filter whose only region is a
--   texture over the health bar, coloured by the client from a curve of
--   the same colours at a lower opacity. Its own slot, so switching it is
--   a container call (SetAuraSlotEnabled), never a touch of a button;
-- * the border: one more slot with the same filter whose regions are a
--   ring of textures inside the cell (Core/Border.lua), coloured by the
--   client from the borders' curve at full opacity; tint and border
--   combine;
-- * the debuff row: an aura group along the bottom of the health bar
--   with every debuff ("HARMFUL"). The centre slot shows one aura only, so
--   a negated filter would hide every dispellable debuff after the first;
--   the one in the centre may show in the row as well;
-- * more parts register with CellAuras.AddPart (the corner indicators,
--   Raid/Indicators.lua).
-- A slot is made the first time it is switched on: cells that never use
-- one never pay for its frame.
--
-- As for the unit frames' containers (Elements/AuraContainers.lua): made
-- and configured out of combat only, a cell the header made in combat
-- waits for the end of combat; buttons are given their regions in
-- initializeFrame, restyled later only out of combat and, while auras are
-- secret, refused (tried again after combat). No scripts on them.
-- The group header could hand every cell a container itself
-- (auraContainerTemplate), in combat too, but slots can only be added out
-- of combat anyway, and it would give one to every child it makes, the
-- empty one each header keeps for its size included.
--
-- Test mode's pretend cells have no container: each part draws a sample
-- with plain frames of their own (part.BuildSample, part.ShowSample) from
-- the cell's pretend member (frame.sample, Raid/TestMode.lua): its
-- debuffs (indices into CellAuras.SAMPLES), and whether it is alive (the
-- corner indicators show on the living).
local CellAuras = { name = "RaidAuras" }
ns.RaidAuras = CellAuras

local Cell, AuraButton, Pixel = ns.RaidCell, ns.AuraButton, ns.Pixel
local get = Cell.Get

CellAuras.FILTERS = { MINE = "HARMFUL|RAID", ALL = "HARMFUL|DISPELLABLE" }
CellAuras.ROW_FILTER = "HARMFUL"
CellAuras.ROW_GROUP = "debuffs"
-- The row's distance from the health bar's corner and between its icons.
CellAuras.ROW_INSET = 1
CellAuras.ROW_SPACING = 1
-- Above the bars' texts (+10), below the raid marker and icons (+18).
CellAuras.LEVELS = 12
-- The tint lies on the health bar, under its texts.
CellAuras.TINT_LEVELS = 2
CellAuras.TINT_ALPHA = 0.35
-- The border lies on the bars and the tint, under the texts and icons.
CellAuras.BORDER_LEVELS = 3
-- Everything a container must take before a cell uses it.
CellAuras.METHODS = { "SetUnit", "GetUnit", "UpdateAllAuras", "SetEditModePreviewEnabled", "AddAuraSlot",
    "SetAuraSlotEnabled", "SetAuraSlotFilterString", "SetAuraSlotCandidateFilters", "AddAuraGroup",
    "SetAuraGroupEnabled", "SetAuraGroupFilterString", "SetAuraGroupMaxFrameCount", "SetAuraGroupLayout",
    "SetAuraGroupCandidateFilters",
    "SetFlowLayoutAxis", "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection" }

-- Test mode's debuffs: the unit frames' samples (dispel types Magic,
-- Curse, Poison, Disease, then one without).
CellAuras.SAMPLES = ns.Auras.SAMPLES.debuffs

-- part.Apply(frame, container, auras) configures the part out of combat;
-- it returns true when a button refused to be restyled. Optional, for
-- pretend cells: part.BuildSample(frame, samples) makes plain frames,
-- part.ShowSample(frame, samples, member, start) draws them (member nil:
-- hidden).
local parts = {}
function CellAuras.AddPart(part)
    parts[#parts + 1] = part
end

-- Cells waiting for the end of combat, cells whose buttons refused a
-- restyle.
local waiting = setmetatable({}, { __mode = "k" })
local stale = setmetatable({}, { __mode = "k" })

-- Hidden auras: the shown size's list and the unit frames' account list
-- (Core/AuraBlocklist.lua), as a set; nil when both are empty. The buff
-- indicators and the debuff row leave them out where the client allows
-- filtering by spell.
function CellAuras.BlockSet()
    local Blocklist = ns.AuraBlocklist
    return Blocklist.Merge(Blocklist.Set(ns.Config.Get("general", "auraBlockAccount")), Blocklist.Set(get("auraBlock")))
end

-- Slots -------------------------------------------------------------------------------

-- Whether two values are the same, tables compared by contents.
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

-- Switches a slot of the cell's container, making it when it is wanted
-- for the first time (init(frame, button) gives its frame regions); one
-- that was never wanted is not made. candidateFilters (optional) are the
-- container's own filters for it, given again only when they changed.
-- Returns its frame, or nil.
-- auras.slots[key] is the frame, auras.candidates[key] its last filters.
function CellAuras.SetSlot(frame, container, key, filter, wanted, init, candidateFilters)
    local auras = frame.raidAuras
    local slots = auras.slots
    if not slots[key] and not wanted then return nil end
    auras.candidates = auras.candidates or {}
    if not slots[key] then
        slots[key] = container:AddAuraSlot(key, filter, { candidateFilters = candidateFilters,
            initializeFrame = function(b) init(frame, b) end })
        auras.candidates[key] = candidateFilters
    end
    container:SetAuraSlotFilterString(key, filter)
    if candidateFilters and not same(candidateFilters, auras.candidates[key]) then
        container:SetAuraSlotCandidateFilters(key, candidateFilters)
        auras.candidates[key] = candidateFilters
    end
    container:SetAuraSlotEnabled(key, wanted == true)
    return slots[key]
end

-- The unit frames' debuff icon look, for the centre icon and the row.
local function decorate(frame, button, size)
    AuraButton.Decorate(button, true)
    AuraButton.StyleManaged(button, frame.key, size, false)
    ns.AuraContainers.Wire(button, true)
end

-- The centre icon, the square and the tint --------------------------------------------

local function dispelSize()
    return Pixel.Snap(get("dispelIconSize"), nil, 1)
end

-- The icon, centred on the health bar.
local function initIcon(frame, button)
    decorate(frame, button, dispelSize())
    button:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
end

-- The square: just inside its corner; with a corner indicator there, that
-- far further in along the edge and a gap more.
CellAuras.SQUARE_GAP = 1

local function placeSquare(frame, square)
    local point = get("dispelSquarePoint")
    local size = Pixel.Snap(get("dispelSquareSize"), nil, 1)
    local inset = Pixel.Snap(ns.RaidIndicators.INSET)
    local dx, dy = Cell.Inset(point)
    local x, y = dx * inset, dy * inset
    local beside = ns.RaidIndicators.SizeAt(point)
    if beside then x = x + dx * (beside + Pixel.Snap(CellAuras.SQUARE_GAP)) end
    square:SetSize(size, size)
    square:ClearAllPoints()
    square:SetPoint(point, frame, point, x, y)
end

-- A slot frame with no mouse whose texture the client colours by the
-- debuff's type.
local function initSquare(frame, button)
    pcall(button.SetMouseClickEnabled, button, false)
    pcall(button.SetMouseMotionEnabled, button, false)
    local square = button:CreateTexture(nil, "ARTWORK")
    square:SetColorTexture(1, 1, 1, 1)
    square:SetAllPoints(button)
    button.square = square
    button:AddDispelTypeTexture(square, { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        customDispelColorCurve = AuraButton.DispelCurve() })
    placeSquare(frame, button)
end

-- The tint: a slot frame of one pixel with no mouse; its texture covers
-- the health bar.
local function initTint(frame, button)
    pcall(button.SetMouseClickEnabled, button, false)
    pcall(button.SetMouseMotionEnabled, button, false)
    button:SetSize(1, 1)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    button:SetFrameLevel(frame:GetFrameLevel() + CellAuras.TINT_LEVELS)
    local tint = button:CreateTexture(nil, "ARTWORK")
    tint:SetColorTexture(1, 1, 1, 1)
    tint:SetAllPoints(frame.health)
    button.tint = tint
    button:AddDispelTypeTexture(tint, { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        customDispelColorCurve = AuraButton.DispelCurve(CellAuras.TINT_ALPHA) })
end

-- The border: a slot frame of one pixel with no mouse, like the tint's;
-- its ring lies inside the cell.
local function borderSize()
    return Pixel.Snap(get("dispelBorderSize"), nil, 1)
end

local function placeBorder(frame, button)
    ns.Border.PlaceInnerRing(button.ring, frame, borderSize())
end

local function initBorder(frame, button)
    pcall(button.SetMouseClickEnabled, button, false)
    pcall(button.SetMouseMotionEnabled, button, false)
    button:SetSize(1, 1)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    button:SetFrameLevel(frame:GetFrameLevel() + CellAuras.BORDER_LEVELS)
    button.ring = ns.Border.NewInnerRing(button)
    placeBorder(frame, button)
    local curve = AuraButton.DispelCurve()
    for _, piece in ipairs(ns.Border.InnerRingPieces(button.ring)) do
        button:AddDispelTypeTexture(piece, { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
            customDispelColorCurve = curve })
    end
end

-- A pretend member's debuffs, in its order.
local function memberDebuffs(member)
    local list = {}
    for _, i in ipairs(member and member.debuffs or {}) do list[#list + 1] = CellAuras.SAMPLES[i] end
    return list
end

-- A pretend member's debuffs: the one the centre icon shows (the first
-- with a dispel type) and the rest.
local function sampleDebuffs(member)
    local centre, rest = nil, {}
    for _, sample in ipairs(memberDebuffs(member)) do
        if not centre and sample.dispel then centre = sample else rest[#rest + 1] = sample end
    end
    return centre, rest
end
CellAuras.SampleDebuffs = sampleDebuffs

-- Which of the two shows the debuff: "ICON", "SQUARE", or nil (off).
local function dispelShows()
    if not get("dispelIcon") then return nil end
    return get("dispelStyle")
end

CellAuras.AddPart({
    Apply = function(frame, container)
        local filter, shows = CellAuras.FILTERS[get("dispelFilter")], dispelShows()
        local icon = CellAuras.SetSlot(frame, container, "dispel", filter, shows == "ICON", initIcon)
        local square = CellAuras.SetSlot(frame, container, "square", filter, shows == "SQUARE", initSquare)
        CellAuras.SetSlot(frame, container, "tint", filter, get("dispelTint"), initTint)
        local border = CellAuras.SetSlot(frame, container, "border", filter, get("dispelBorder"), initBorder)
        local refused = icon ~= nil and not pcall(AuraButton.StyleManaged, icon, frame.key, dispelSize(), false)
        if square ~= nil and not pcall(placeSquare, frame, square) then refused = true end
        if border ~= nil and not pcall(placeBorder, frame, border) then refused = true end
        return refused
    end,
    BuildSample = function(frame, samples)
        samples.icon = AuraButton.Create(frame, true)
        samples.square = CreateFrame("Frame", nil, frame)
        samples.square.texture = samples.square:CreateTexture(nil, "ARTWORK")
        samples.square.texture:SetColorTexture(1, 1, 1, 1)
        samples.square.texture:SetAllPoints(samples.square)
        samples.square:Hide()
        -- A frame needs a rect of its own for its texture to be drawn.
        samples.tint = CreateFrame("Frame", nil, frame)
        samples.tint:SetAllPoints(frame.health)
        samples.tint.texture = samples.tint:CreateTexture(nil, "ARTWORK")
        samples.tint.texture:SetColorTexture(1, 1, 1, 1)
        samples.tint.texture:SetAllPoints(frame.health)
        samples.tint:Hide()
    end,
    ShowSample = function(frame, samples, member, start)
        local centre, shows = sampleDebuffs(member), dispelShows()
        local icon, square, tint = samples.icon, samples.square, samples.tint
        icon:SetFrameLevel(frame:GetFrameLevel() + CellAuras.LEVELS)
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
        AuraButton.Style(icon, frame.key, dispelSize(), false)
        if centre and shows == "ICON" then AuraButton.ShowSample(icon, centre, start) else AuraButton.Clear(icon) end
        local c = centre and AuraButton.DISPEL_COLORS[centre.dispel]
        square:SetFrameLevel(frame:GetFrameLevel() + CellAuras.LEVELS)
        placeSquare(frame, square)
        if c then square.texture:SetVertexColor(c[1], c[2], c[3], 1) end
        square:SetShown(c ~= nil and shows == "SQUARE")
        tint:SetFrameLevel(frame:GetFrameLevel() + CellAuras.TINT_LEVELS)
        if c then tint.texture:SetVertexColor(c[1], c[2], c[3], CellAuras.TINT_ALPHA) end
        tint:SetShown(c ~= nil and get("dispelTint") == true)
    end,
})

-- The debuff row ----------------------------------------------------------------------

local function rowSize()
    return Pixel.Snap(get("debuffSize"), nil, 1)
end

local function rowLayout(size)
    local spacing = Pixel.Snap(CellAuras.ROW_SPACING)
    return { elementWidth = size, elementHeight = size, elementSpacing = spacing, lineSpacing = spacing }
end

local function initRowButton(frame, row, button)
    decorate(frame, button, rowSize())
    row[#row + 1] = button
end

-- The group is made the first time the row is switched on; its buttons
-- (a batch at a time, the client's choice) are recorded for restyling;
-- auras.row is set once the group exists, so a refused group leaves none.
CellAuras.AddPart({
    Apply = function(frame, container, auras)
        local wanted, key = get("debuffRow") == true, CellAuras.ROW_GROUP
        if not auras.row and not wanted then return false end
        local size = rowSize()
        local layout = rowLayout(size)
        local block = CellAuras.BlockSet()
        local filters = block and { excludeSpellIDs = block } or nil
        if not auras.row then
            local row = {}
            container:AddAuraGroup(key, CellAuras.ROW_FILTER, { maxFrameCount = get("debuffCount"), layout = layout,
                candidateFilters = filters, initializeFrame = function(b) initRowButton(frame, row, b) end })
            auras.row = row
            auras.rowFilters = filters
        end
        -- Given again only when they changed (the container then looks
        -- at every aura again).
        if not same(filters, auras.rowFilters) then
            container:SetAuraGroupCandidateFilters(key, filters)
            auras.rowFilters = filters
        end
        container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
        container:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
        container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
        container:SetAuraGroupFilterString(key, CellAuras.ROW_FILTER)
        container:SetAuraGroupMaxFrameCount(key, get("debuffCount"))
        container:SetAuraGroupLayout(key, layout)
        container:SetAuraGroupEnabled(key, wanted)
        local refused = false
        for _, button in ipairs(auras.row) do
            if not pcall(AuraButton.StyleManaged, button, frame.key, size, false) then refused = true end
        end
        return refused
    end,
    -- As many plain icons as the row can hold.
    BuildSample = function(frame, samples)
        samples.row = {}
        for i = 1, ns.RaidSettings.Get("debuffCount").max do samples.row[i] = AuraButton.Create(frame, true) end
    end,
    -- Every debuff of the member, as the live row (the centre's one too).
    ShowSample = function(frame, samples, member, start)
        local debuffs = memberDebuffs(member)
        local size, inset = rowSize(), Pixel.Snap(CellAuras.ROW_INSET)
        local step = size + Pixel.Snap(CellAuras.ROW_SPACING)
        local count = get("debuffRow") and get("debuffCount") or 0
        for i, button in ipairs(samples.row) do
            button:SetFrameLevel(frame:GetFrameLevel() + CellAuras.LEVELS)
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", frame.health, "BOTTOMLEFT", inset + (i - 1) * step, inset)
            AuraButton.Style(button, frame.key, size, false)
            if i <= count and debuffs[i] then
                AuraButton.ShowSample(button, debuffs[i], start)
            else
                AuraButton.Clear(button)
            end
        end
    end,
})

-- The container -----------------------------------------------------------------------

local function usable(container)
    for _, method in ipairs(CellAuras.METHODS) do
        if type(container[method]) ~= "function" then return false end
    end
    return true
end

-- Every part onto the container; out of combat. The container sits where
-- the debuff row starts, row or not, so it always has a place.
local function apply(frame)
    local container = frame.raidAuras.container
    stale[frame] = nil
    container:SetFrameLevel(frame:GetFrameLevel() + CellAuras.LEVELS)
    local inset = Pixel.Snap(CellAuras.ROW_INSET)
    container:ClearAllPoints()
    container:SetPoint("BOTTOMLEFT", frame.health, "BOTTOMLEFT", inset, inset)
    for _, part in ipairs(parts) do
        if part.Apply(frame, container, frame.raidAuras) then stale[frame] = true end
    end
end

-- The container and its first configuration, out of combat. A client
-- without the calls a cell needs, or a refusal, leaves the cell without
-- auras for the session (a refusal is reported once).
local function build(frame)
    local auras = frame.raidAuras
    local ok, err = pcall(function()
        local container = CreateFrame("AuraContainer", nil, frame, ns.AuraContainers.TEMPLATE)
        auras.container = container
        if not usable(container) then
            auras.failed = true
            return
        end
        container:SetEditModePreviewEnabled(false)
        apply(frame)
        container:SetUnit(frame.unit or "none")
    end)
    if not ok then
        auras.failed = true
        geterrorhandler()(err)
    end
    if auras.failed then
        if auras.container then auras.container:Hide() end
        auras.container = nil
        return false
    end
    auras.built = true
    return true
end

local function flush()
    local frames = {}
    for frame in pairs(waiting) do frames[#frames + 1] = frame end
    for _, frame in ipairs(frames) do
        waiting[frame] = nil
        local auras = frame.raidAuras
        if auras.built then
            apply(frame)
        elseif not auras.failed then
            build(frame)
        end
    end
end

local function later(frame)
    waiting[frame] = true
    ns.AfterCombat("raidAuras", flush)
end

-- Whether the cell's container is configured and can be told its unit.
local function ready(frame)
    local auras = frame.raidAuras
    if not auras or auras.failed or frame.pretend then return false end
    if auras.built then return true end
    if not ns.AuraContainers.Supported() then
        auras.failed = true
        return false
    end
    if InCombatLockdown() then
        later(frame)
        return false
    end
    return build(frame)
end

-- Element -------------------------------------------------------------------------------

-- Pretend cells get the parts' sample frames instead of a container.
function CellAuras.Build(frame)
    if not Cell.Is(frame) then return end
    frame.raidAuras = { slots = {} }
    if not frame.pretend then return end
    local samples = {}
    for _, part in ipairs(parts) do
        if part.BuildSample then part.BuildSample(frame, samples) end
    end
    frame.raidAuras.samples = samples
end

-- The sample of a pretend cell, drawn from its member; nil member hides it.
local function showSamples(frame, member)
    local auras = frame.raidAuras
    auras.sampleStart = member and (auras.sampleStart or GetTime()) or nil
    for _, part in ipairs(parts) do
        if part.ShowSample then part.ShowSample(frame, auras.samples, member, auras.sampleStart) end
    end
end

-- Settings changed: applied now, or after combat; a pretend cell redraws
-- its sample.
function CellAuras.Style(frame)
    local auras = frame.raidAuras
    if auras and auras.samples then
        if auras.previewing then showSamples(frame, frame.sample) end
        return
    end
    if not (auras and auras.built) then return end
    if InCombatLockdown() then later(frame) else apply(frame) end
end

-- Test mode: a pretend cell shows its member's sample.
function CellAuras.Preview(frame, on)
    local auras = frame.raidAuras
    if not (auras and auras.samples) then return end
    auras.previewing = on and frame.sample ~= nil or nil
    showSamples(frame, auras.previewing and frame.sample or nil)
end

-- A new unit, or the same raid unit after a roster change (it may be
-- someone else now): the container looks again.
function CellAuras.Update(frame)
    if not ready(frame) then return end
    local container, unit = frame.raidAuras.container, frame.unit or "none"
    if container:GetUnit() ~= unit then
        container:SetUnit(unit)
    else
        container:UpdateAllAuras()
    end
end

-- A cell made ahead of time (Units/Units.lua): its container now, out of
-- combat, holding no unit until the header hands it one.
function CellAuras.Prepare(frame)
    ready(frame)
end

-- The cell lost its unit: its container stops looking at the old one.
-- In combat too: SetUnit only re-registers the container's events.
-- A cell without a container yet gets none for it.
function CellAuras.Release(frame)
    local auras = frame.raidAuras
    if not (auras and auras.built) then return end
    auras.container:SetUnit("none")
end

ns.On("PLAYER_REGEN_ENABLED", function()
    for frame in pairs(stale) do
        if not waiting[frame] then apply(frame) end
    end
end)

ns.RegisterElement(CellAuras)
