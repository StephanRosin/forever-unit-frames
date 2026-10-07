local _, ns = ...

-- Live auras through Blizzard's CustomAuraContainerTemplate
-- (Blizzard_AuraContainer). The client reads the auras and fills the icons
-- from secure code, in combat too; the addon only configures a container
-- (unit, filters, layout) and gives its buttons their look. Our own read
-- path (Elements/Auras.lua) stays for test mode samples and for clients
-- where a container cannot be made.
local AuraContainers = {}
ns.AuraContainers = AuraContainers

AuraContainers.TEMPLATE = "CustomAuraContainerTemplate"
-- The inbound calls this addon makes; a container without them is not
-- used.
AuraContainers.METHODS = { "SetUnit", "GetUnit", "UpdateAllAuras", "AddAuraGroup", "SetAuraGroupEnabled",
    "SetAuraGroupFilterString", "SetAuraGroupMaxFrameCount", "SetAuraGroupLayout", "SetFlowLayoutAxis",
    "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection", "SetFlowLayoutMaximumLineSize" }

-- nil until asked; then true or false for the session.
local supported

local function complete(container)
    for _, method in ipairs(AuraContainers.METHODS) do
        if type(container[method]) ~= "function" then return false end
    end
    return true
end

local function probe()
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, UIParent, AuraContainers.TEMPLATE)
    if not ok or type(container) ~= "table" then return false end
    container:Hide()
    local asked, answer = pcall(complete, container)
    return asked and answer
end

-- Whether this client can make aura containers for addons. Asked once,
-- with one hidden test container that is never used again.
function AuraContainers.Supported()
    if supported == nil then supported = probe() end
    return supported
end

-- Settings to container layout ---------------------------------------------------
-- A settings group (frame.auras.buffs / .debuffs, after Auras.Style read
-- its settings) becomes one container with two groups: "own" (yours, at
-- their own size) and "other" (the rest, or everything when yours are not
-- put first). Yours placed freely (group.ownFree) need a second container:
-- a container's groups share its one flow, and the container has one
-- anchor (Blizzard_CustomAuraContainer.lua, Blizzard_AuraContainerFlowLayout
-- .lua); it holds one group, "own", and the first one's "own" is off.
-- Plain values in, plain tables out; no widget is touched.
AuraContainers.PARTS = { "own", "other" }
-- Ten years in seconds: longer than any timed aura.
AuraContainers.ANY_DURATION = 10 * 365 * 86400

-- The tracking spells as the container wants them: a map, spell ID ->
-- true (Blizzard_AuraContainerUtil.lua looks up excludeSpellIDs[spellId]).
-- A plain list would hold the IDs as values and exclude nothing.
AuraContainers.TRACKING_SET = {}
for _, id in ipairs(ns.Settings.TRACKING_SPELLS) do AuraContainers.TRACKING_SET[id] = true end

-- The container's own filters for "hide permanent", "hide tracking" and
-- the hidden auras (group.blockSet: the account's and the frame's lists,
-- Core/AuraBlocklist.lua); nil when none is on. The excluded spells are
-- one set: tracking and the lists merged. The client applies them where
-- it allows filtering by spell (CanApplyIdentityCandidateFilters).
-- "Hide longer" is maxDuration itself: the client leaves out auras whose
-- full duration exceeds it, and auras without one.
function AuraContainers.CandidateFilters(group)
    local exclude = ns.AuraBlocklist.Merge(group.hideTracking and AuraContainers.TRACKING_SET or nil, group.blockSet)
    if not (group.hidePermanent or exclude or group.hideLonger) then return nil end
    local filters = {}
    if group.hidePermanent then filters.maxDuration = AuraContainers.ANY_DURATION end
    if group.hideLonger then filters.maxDuration = group.hideLonger end
    if exclude then filters.excludeSpellIDs = exclude end
    return filters
end

local HORIZONTAL = { RIGHT = true, LEFT = true }
local FLOW_NAMES = { RIGHT = "Right", LEFT = "Left", UP = "Up", DOWN = "Down" }

-- The container's flow: axis, the corner icons start in, both growth
-- directions and the row length at which icons wrap. A fixed number per
-- row is that many icons of the normal size; Auto is the frame's length.
function AuraContainers.Flow(group)
    local Layout = ns.Layout
    local primary = group.primary
    local row = Layout.AuraRowDirection(primary, group.row)
    local horizontal = HORIZONTAL[primary]
    local h, v = primary, row
    if not horizontal then h, v = row, primary end
    local perRow, lineSize = group.perRowSetting, group.length
    if perRow > 0 then lineSize = perRow * group.size + (perRow - 1) * group.spacing end
    return {
        axis = horizontal and AnchorUtil.FlowLayoutAxis.Horizontal or AnchorUtil.FlowLayoutAxis.Vertical,
        anchor = Layout.AuraCorner(primary, row),
        horizontal = AnchorUtil.FlowDirection[FLOW_NAMES[h]],
        vertical = AnchorUtil.FlowDirection[FLOW_NAMES[v]],
        -- The client adds snapped sizes up one by one: half a pixel of slack,
        -- so rounding cannot push the last icon of a row onto the next.
        lineSize = math.max(lineSize, group.size) + ns.Pixel.One() / 2,
    }
end

local function describe(group, enabled, filter, size, newLine)
    local spacing = group.spacing
    return {
        enabled = enabled and true or false,
        filter = filter,
        max = group.max,
        layout = { elementWidth = size, elementHeight = size, elementSpacing = spacing, lineSpacing = spacing,
            groupSpacing = spacing, groupLineSpacing = spacing, forceNewLine = newLine },
        -- Any maxDuration hides auras without one; this one keeps every
        -- timed aura (it is compared with the aura's full duration).
        candidateFilters = AuraContainers.CandidateFilters(group),
    }
end

-- One container group: shown or not, filter, maximum and layout. Split
-- (yours first, or borders by caster): "own" takes the PLAYER filter,
-- "other" the rest (nothing when only yours are shown); with "mine first"
-- yours are at the own size and the rest start a new line, unless they
-- share the rows (ownSameRow). Otherwise "own" is off and "other" shows
-- everything the group's filter lets through. apart: yours are in their
-- own container (default: group.ownFree); then "own" is off here and the
-- rest start at the first row.
function AuraContainers.Part(group, part, apart)
    if apart == nil then apart = group.ownFree end
    local split = group.highlightOwn or group.casterBorder
    if part == "own" then
        return describe(group, group.enabled and split and not apart, group.ownFilter, group.ownSize, false)
    elseif split then
        return describe(group, group.enabled and group.otherFilter ~= nil, group.otherFilter or group.filter,
            group.size, group.highlightOwn and not group.ownSameRow and not apart)
    end
    return describe(group, group.enabled, group.filter, group.size, false)
end

-- The one group of the container for yours placed freely: yours at the
-- own size; off unless they are placed freely.
function AuraContainers.FreePart(group)
    return describe(group, group.enabled and group.ownFree, group.ownFilter, group.ownSize, false)
end

-- A buff's border colour by caster (own or other group), or nil.
function AuraContainers.CasterBorder(group, own)
    if not group.casterBorder then return nil end
    return own and group.ownBorder or group.otherBorder
end

-- Buttons -----------------------------------------------------------------------
-- The container makes its buttons (a batch at a time, possibly in combat)
-- and hands each to initializeFrame before it locks them against us while
-- auras are secret. There they get our regions and look, and the regions
-- the client fills are registered: icon, swipe (its countdown numbers are
-- the time left), stack count and, for debuffs, the border coloured by
-- dispel type through our colour curve. Tooltips are the container's own.

-- Debuff border: our white texture keeps its asset; the client colours it
-- from the curve, for debuffs without a dispel type too (the NONE colour).
function AuraContainers.DispelOptions()
    return {
        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        showWithoutDispelType = true,
        customDispelColorCurve = ns.AuraButton.DispelCurve(),
    }
end

-- A decorated button's regions handed to the client: icon, swipe, count
-- and, for a debuff, the border coloured by dispel type. Tooltips on
-- hover, clicks through to the unit button below. In initializeFrame
-- only (Raid/CellAuras.lua wires its debuff icons the same way).
function AuraContainers.Wire(button, isDebuff)
    button:SetIcon(button.icon)
    button:SetDurationCooldown(button.cooldown)
    button:SetApplicationCount(button.count)
    if isDebuff then button:AddDispelTypeTexture(button.border, AuraContainers.DispelOptions()) end
    button:SetTooltipAnchorPoint("ANCHOR_BOTTOMRIGHT")
    pcall(button.SetMouseClickEnabled, button, false)
end

-- entry = { frame, key, isDebuff, buttons }; own: the button belongs to
-- the "own" group (drawn at the own size).
function AuraContainers.InitButton(entry, own, button)
    local AuraButton = ns.AuraButton
    local group = entry.frame.auras[entry.key]
    local size = own and group.ownSize or group.size
    AuraButton.Decorate(button, entry.isDebuff)
    button.casterBorder = AuraContainers.CasterBorder(group, own)
    -- Fonts before the count is registered: the client writes it at once.
    AuraButton.StyleManaged(button, entry.frame.key, size, group.showTime)
    entry.buttons[#entry.buttons + 1] = { button = button, own = own }
    AuraContainers.Wire(button, entry.isDebuff)
end

-- Containers per frame ------------------------------------------------------------
-- frame.auraContainers = { buffs = entry, debuffs = entry }, entry =
-- { container, frame, key, isDebuff, buttons, stale, ownContainer (yours
-- placed freely: made the first time they are), ownFailed, apart (yours
-- in ownContainer now) }. Made the first time
-- a frame shows live auras, so the pretend party (test mode only) never
-- gets any. Made and configured out of combat only: the container itself
-- would take settings in combat, but its buttons refuse us while auras
-- are secret, and their size must change together with the layout.

-- The groups a frame has containers for: those whose settings apply to
-- it (the dispels group only on the party). A frame may bring its own
-- list in frame.auraGroupKeys (raid cells: none, Raid/Cell.lua).
local function groupKeys(frame)
    if frame.auraGroupKeys then return frame.auraGroupKeys end
    local keys = {}
    for _, key in ipairs(ns.Settings.AURA_GROUPS) do
        if ns.Settings.AppliesTo(ns.Settings.Get(key .. "Enabled"), frame.key) then keys[#keys + 1] = key end
    end
    frame.auraGroupKeys = keys
    return keys
end

-- Every frame with containers.
local all = setmetatable({}, { __mode = "k" })
-- Frames waiting for the end of combat (to be made or configured).
local waiting = setmetatable({}, { __mode = "k" })
-- Frames whose buttons could not be restyled (auras were secret); tried
-- again after combat.
local stale = setmetatable({}, { __mode = "k" })

local function testing()
    return ns.TestMode ~= nil and ns.TestMode.IsOn()
end

-- Adds the container of one group to made (before anything can fail).
local function create(frame, key, made)
    local group = frame.auras[key]
    local container = CreateFrame("AuraContainer", nil, frame, AuraContainers.TEMPLATE)
    local entry = { container = container, frame = frame, key = key, isDebuff = group.isDebuff, buttons = {} }
    made[key] = entry
    -- Blizzard's Edit Mode would fill it with made-up auras.
    container:SetEditModePreviewEnabled(false)
    for _, part in ipairs(AuraContainers.PARTS) do
        local p, own = AuraContainers.Part(group, part), part == "own"
        container:AddAuraGroup(part, p.filter, { maxFrameCount = p.max, layout = p.layout,
            candidateFilters = p.candidateFilters,
            initializeFrame = function(button) AuraContainers.InitButton(entry, own, button) end })
    end
    container:SetUnit(frame.unit or "none")
end

-- The container for yours placed freely, made the first time they are
-- (out of combat: apply). On a refusal it is dropped, reported once, and
-- yours stay with the rest on this frame from then on.
local function ownContainer(frame, entry, group)
    if entry.ownContainer or entry.ownFailed or not group.ownFree then return entry.ownContainer end
    local container
    local ok, err = pcall(function()
        container = CreateFrame("AuraContainer", nil, frame, AuraContainers.TEMPLATE)
        container:SetEditModePreviewEnabled(false)
        local p = AuraContainers.FreePart(group)
        container:AddAuraGroup("own", p.filter, { maxFrameCount = p.max, layout = p.layout,
            candidateFilters = p.candidateFilters,
            initializeFrame = function(button) AuraContainers.InitButton(entry, true, button) end })
        container:SetUnit(frame.unit or "none")
    end)
    if not ok then
        if container then container:Hide() end
        entry.ownFailed = true
        geterrorhandler()(err)
        return nil
    end
    entry.ownContainer = container
    return container
end

-- Whether the client refused the container for yours placed freely on
-- frame (group key): yours stay with the rest there (Auras readFree).
function AuraContainers.OwnRefused(frame, key)
    local entry = frame.auraContainers and frame.auraContainers[key]
    return entry and entry.ownFailed or false
end

-- The same for any frame of a scope (the options grey its place rows).
function AuraContainers.OwnRefusedOn(scope, key)
    for frame in pairs(all) do
        if frame.key == scope and AuraContainers.OwnRefused(frame, key) then return true end
    end
    return false
end

-- Sizes and fonts of every button made so far; buttons made later get
-- them in InitButton. Refused while auras are secret: tried again later.
local function restyle(entry, group)
    local refused = false
    for _, record in ipairs(entry.buttons) do
        local size = record.own and group.ownSize or group.size
        record.button.casterBorder = AuraContainers.CasterBorder(group, record.own)
        if not pcall(ns.AuraButton.StyleManaged, record.button, entry.frame.key, size, group.showTime) then
            refused = true
        end
    end
    entry.stale = refused
    return refused
end

-- Room the player's weapon enchants take before the buffs
-- (Elements/WeaponEnchants.lua): that many icons along the growth
-- direction. The container moves on by it and its rows get as much
-- shorter, so the first row keeps its length.
local STEP_DIRECTION = { RIGHT = { 1, 0 }, LEFT = { -1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }

function AuraContainers.Lead(frame, key)
    if key ~= "buffs" then return 0, 0, 0 end
    local n = frame.enchantLead or 0
    if n == 0 then return 0, 0, 0 end
    local group = frame.auras[key]
    local step = n * (group.size + group.spacing)
    local d = STEP_DIRECTION[group.primary] or STEP_DIRECTION.RIGHT
    return step, d[1] * step, d[2] * step
end

local function place(frame, key)
    local Config = ns.Config
    local scope = frame.key
    local region = ns.Auras.AnchorRegion(frame, key, true)
    local x, y = ns.Auras.AnchorOffset(frame, key, region)
    local _, dx, dy = AuraContainers.Lead(frame, key)
    frame.auraContainers[key].container:SetPoint(Config.Get(scope, key .. "Point"),
        region, Config.Get(scope, key .. "FramePoint"), x + dx, y + dy)
end

-- Yours placed freely hang from the unit's block by their own points.
local function placeOwn(frame, key)
    local Config = ns.Config
    local scope = frame.key
    local region = frame.unitBox or frame
    local x, y = ns.Auras.AnchorOffset(frame, key, region, "Own")
    frame.auraContainers[key].ownContainer:SetPoint(Config.Get(scope, key .. "OwnPoint"),
        region, Config.Get(scope, key .. "OwnFramePoint"), x, y)
end

local function lineSize(frame, key, flow)
    local lead = AuraContainers.Lead(frame, key)
    return math.max(flow.lineSize - lead, frame.auras[key].size)
end

-- The weapon enchants changed in number: the buffs make room, combat
-- included (the container is a plain frame).
function AuraContainers.Relead(frame)
    local entry = frame.auraContainers and frame.auraContainers.buffs
    if not entry then return end
    local flow = AuraContainers.Flow(frame.auras.buffs)
    entry.container:SetFlowLayoutMaximumLineSize(lineSize(frame, "buffs", flow))
    entry.container:ClearAllPoints()
    place(frame, "buffs")
end

local function setFlow(container, flow, size)
    container:SetFlowLayoutAxis(flow.axis)
    container:SetFlowLayoutAnchorPoint(flow.anchor)
    container:SetFlowLayoutGrowthDirection(flow.horizontal, flow.vertical)
    container:SetFlowLayoutMaximumLineSize(size)
end

local function setPart(container, part, p)
    container:SetAuraGroupFilterString(part, p.filter)
    container:SetAuraGroupMaxFrameCount(part, p.max)
    container:SetAuraGroupLayout(part, p.layout)
    container:SetAuraGroupCandidateFilters(part, p.candidateFilters)
    container:SetAuraGroupEnabled(part, p.enabled)
end

-- A container onto unit: a new unit is read by SetUnit; the same token
-- read again unless the container's own UNIT_AURA brought it.
local function refreshOne(container, unit, event)
    if container:GetUnit() ~= unit then
        container:SetUnit(unit)
    elseif event ~= "UNIT_AURA" then
        container:UpdateAllAuras()
    end
end

-- Settings (read by Auras.Style into frame.auras) onto the containers.
local function apply(frame)
    local live = not testing()
    stale[frame] = nil
    local refusedNow = false
    for _, key in ipairs(groupKeys(frame)) do
        local group, entry = frame.auras[key], frame.auraContainers[key]
        local own, was = ownContainer(frame, entry, group), entry.apart
        refusedNow = refusedNow or (entry.ownFailed and group.ownFree)
        entry.apart = own ~= nil and group.ownFree or false
        local container, flow = entry.container, AuraContainers.Flow(group)
        setFlow(container, flow, lineSize(frame, key, flow))
        for _, part in ipairs(AuraContainers.PARTS) do setPart(container, part, AuraContainers.Part(group, part, entry.apart)) end
        if own then
            local ownFlow = AuraContainers.Flow(group.free)
            setFlow(own, ownFlow, ownFlow.lineSize)
            setPart(own, "own", AuraContainers.FreePart(group))
            own:SetFrameLevel(frame:GetFrameLevel() + ns.Auras.LEVELS)
            own:SetShown(live and group.enabled and entry.apart)
            -- Not refreshed while hidden: the frame's unit again now.
            if entry.apart and not was then refreshOne(own, frame.unit or "none", "APPLY") end
        end
        if restyle(entry, group) then stale[frame] = true end
        container:SetFrameLevel(frame:GetFrameLevel() + ns.Auras.LEVELS)
        container:SetShown(live and group.enabled)
    end
    -- Anchors last, all cleared first: a group may hang from the other.
    for _, key in ipairs(groupKeys(frame)) do
        local entry = frame.auraContainers[key]
        entry.container:ClearAllPoints()
        if entry.ownContainer then entry.ownContainer:ClearAllPoints() end
    end
    for _, key in ipairs(groupKeys(frame)) do
        place(frame, key)
        if frame.auraContainers[key].ownContainer then placeOwn(frame, key) end
    end
    if ns.WeaponEnchants then ns.WeaponEnchants.Layout(frame) end
    -- Refused just now: read again, yours with the rest (applies again).
    if refusedNow then ns.Auras.Style(frame) end
end

-- Makes both containers of a frame. On a refusal nothing made is kept
-- and the frame reads its auras itself from then on.
local function build(frame)
    local made = {}
    local ok, err = pcall(function()
        for _, key in ipairs(groupKeys(frame)) do create(frame, key, made) end
    end)
    if not ok then
        for _, entry in pairs(made) do entry.container:Hide() end
        frame.auraContainerFailed = true
        geterrorhandler()(err)
        return false
    end
    frame.auraContainers = made
    all[frame] = true
    apply(frame)
    return true
end

local function flush()
    local frames = {}
    for frame in pairs(waiting) do frames[#frames + 1] = frame end
    for _, frame in ipairs(frames) do
        waiting[frame] = nil
        if frame.auraContainers then
            apply(frame)
        elseif not frame.auraContainerFailed then
            build(frame)
        end
    end
end

local function later(frame)
    waiting[frame] = true
    ns.AfterCombat("auraContainers", flush)
end

-- Whether frame's live auras come from containers: made now, or waiting
-- for the end of combat. False: the addon reads them itself (no client
-- support, or the client refused this frame's containers).
function AuraContainers.Ensure(frame)
    if frame.auraContainers then return true end
    if frame.pretend or frame.auraContainerFailed or not AuraContainers.Supported() then return false end
    if InCombatLockdown() then
        later(frame)
        return true
    end
    return build(frame)
end

-- Settings changed (Auras.Style): applied now, or after combat.
function AuraContainers.Style(frame)
    if not frame.auraContainers then return end
    if InCombatLockdown() then
        later(frame)
        return
    end
    apply(frame)
end

ns.On("PLAYER_REGEN_ENABLED", function()
    for frame in pairs(stale) do
        if not waiting[frame] then apply(frame) end
    end
end)

-- Live updates ----------------------------------------------------------------------
-- The containers take UNIT_AURA for their unit themselves. What they cannot
-- know: the frame's unit changed (party slots, test mode), or the same
-- token now means someone else (a new target or focus) or has no aura
-- events at all (target of target, on the frame's timer). A hidden own
-- container (yours with the rest) is left alone until apply uses it.
function AuraContainers.Refresh(frame, event)
    if not frame.auraContainers then return end
    local unit = frame.unit or "none"
    for _, key in ipairs(groupKeys(frame)) do
        local entry = frame.auraContainers[key]
        refreshOne(entry.container, unit, event)
        if entry.apart then refreshOne(entry.ownContainer, unit, event) end
    end
end

-- Party slots reshuffled: party2 (and partypet2) may now be someone else
-- under the same token, which the container does not notice by itself.
ns.On("GROUP_ROSTER_UPDATE", function()
    for frame in pairs(all) do
        if frame.key == ns.Party.KEY or frame.key == ns.Party.PET_KEY then
            AuraContainers.Refresh(frame, "GROUP_ROSTER_UPDATE")
        end
    end
end)

-- Test mode shows our samples instead (a container shows only real auras).
function AuraContainers.Hide(frame)
    if not frame.auraContainers then return end
    for _, key in ipairs(groupKeys(frame)) do
        local entry = frame.auraContainers[key]
        entry.container:Hide()
        if entry.ownContainer then entry.ownContainer:Hide() end
    end
end

ns.Listen("TEST_MODE", function(on)
    if on then return end
    for frame in pairs(all) do
        for _, key in ipairs(groupKeys(frame)) do
            local entry, enabled = frame.auraContainers[key], frame.auras[key].enabled
            entry.container:SetShown(enabled)
            if entry.ownContainer then entry.ownContainer:SetShown(enabled and entry.apart) end
        end
    end
end)
