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
-- put first). Plain values in, plain tables out; no widget is touched.
AuraContainers.PARTS = { "own", "other" }

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

-- One container group: shown or not, filter, maximum and layout. Yours
-- first: "own" takes the PLAYER filter at the own size, "other" the rest
-- on a new line (nothing when only yours are shown). Otherwise "own" is
-- off and "other" shows everything the group's filter lets through.
function AuraContainers.Part(group, part)
    local own = part == "own"
    local enabled, filter, size, newLine
    if own then
        enabled, filter, size, newLine = group.enabled and group.highlightOwn, group.ownFilter, group.ownSize, false
    elseif group.highlightOwn then
        enabled, filter, size, newLine = group.enabled and group.otherFilter ~= nil,
            group.otherFilter or group.filter, group.size, true
    else
        enabled, filter, size, newLine = group.enabled, group.filter, group.size, false
    end
    local spacing = group.spacing
    return {
        enabled = enabled and true or false,
        filter = filter,
        max = group.max,
        layout = { elementWidth = size, elementHeight = size, elementSpacing = spacing, lineSpacing = spacing,
            groupLineSpacing = spacing, forceNewLine = newLine },
    }
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
local function dispelOptions()
    return {
        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        showWithoutDispelType = true,
        customDispelColorCurve = ns.AuraButton.DispelCurve(),
    }
end

-- entry = { frame, key, isDebuff, buttons }; own: the button belongs to
-- the "own" group (drawn at the own size).
function AuraContainers.InitButton(entry, own, button)
    local AuraButton = ns.AuraButton
    local group = entry.frame.auras[entry.key]
    local size = own and group.ownSize or group.size
    AuraButton.Decorate(button, entry.isDebuff)
    -- Fonts before the count is registered: the client writes it at once.
    AuraButton.StyleManaged(button, entry.frame.key, size, group.showTime)
    entry.buttons[#entry.buttons + 1] = { button = button, own = own }
    button:SetIcon(button.icon)
    button:SetDurationCooldown(button.cooldown)
    button:SetApplicationCount(button.count)
    if entry.isDebuff then button:AddDispelTypeTexture(button.border, dispelOptions()) end
    button:SetTooltipAnchorPoint("ANCHOR_BOTTOMRIGHT")
    -- Tooltips on hover, clicks through to the unit button below.
    pcall(button.SetMouseClickEnabled, button, false)
end

-- Containers per frame ------------------------------------------------------------
-- frame.auraContainers = { buffs = entry, debuffs = entry }, entry =
-- { container, frame, key, isDebuff, buttons, stale }. Made the first time
-- a frame shows live auras, so the pretend party (test mode only) never
-- gets any. Made and configured out of combat only: the container itself
-- would take settings in combat, but its buttons refuse us while auras
-- are secret, and their size must change together with the layout.

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
            initializeFrame = function(button) AuraContainers.InitButton(entry, own, button) end })
    end
    container:SetUnit(frame.unit or "none")
end

-- Sizes and fonts of every button made so far; buttons made later get
-- them in InitButton. Refused while auras are secret: tried again later.
local function restyle(entry, group)
    local refused = false
    for _, record in ipairs(entry.buttons) do
        local size = record.own and group.ownSize or group.size
        if not pcall(ns.AuraButton.StyleManaged, record.button, entry.frame.key, size, group.showTime) then
            refused = true
        end
    end
    entry.stale = refused
    return refused
end

local function place(frame, key)
    local Config = ns.Config
    local scope = frame.key
    local region = ns.Auras.AnchorRegion(frame, key, true)
    frame.auraContainers[key].container:SetPoint(Config.Get(scope, key .. "Point"),
        region, Config.Get(scope, key .. "FramePoint"), ns.Auras.AnchorOffset(frame, key, region))
end

-- Settings (read by Auras.Style into frame.auras) onto the containers.
local function apply(frame)
    local live = not testing()
    stale[frame] = nil
    for _, key in ipairs(ns.Settings.AURA_GROUPS) do
        local group, entry = frame.auras[key], frame.auraContainers[key]
        local container, flow = entry.container, AuraContainers.Flow(group)
        container:SetFlowLayoutAxis(flow.axis)
        container:SetFlowLayoutAnchorPoint(flow.anchor)
        container:SetFlowLayoutGrowthDirection(flow.horizontal, flow.vertical)
        container:SetFlowLayoutMaximumLineSize(flow.lineSize)
        for _, part in ipairs(AuraContainers.PARTS) do
            local p = AuraContainers.Part(group, part)
            container:SetAuraGroupFilterString(part, p.filter)
            container:SetAuraGroupMaxFrameCount(part, p.max)
            container:SetAuraGroupLayout(part, p.layout)
            container:SetAuraGroupEnabled(part, p.enabled)
        end
        if restyle(entry, group) then stale[frame] = true end
        container:SetFrameLevel(frame:GetFrameLevel() + ns.Auras.LEVELS)
        container:SetShown(live and group.enabled)
    end
    -- Anchors last, all cleared first: a group may hang from the other.
    for _, key in ipairs(ns.Settings.AURA_GROUPS) do frame.auraContainers[key].container:ClearAllPoints() end
    for _, key in ipairs(ns.Settings.AURA_GROUPS) do place(frame, key) end
end

-- Makes both containers of a frame. On a refusal nothing made is kept
-- and the frame reads its auras itself from then on.
local function build(frame)
    local made = {}
    local ok, err = pcall(function()
        for _, key in ipairs(ns.Settings.AURA_GROUPS) do create(frame, key, made) end
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
-- events at all (target of target, on the frame's timer).
function AuraContainers.Refresh(frame, event)
    if not frame.auraContainers then return end
    local unit = frame.unit or "none"
    for _, key in ipairs(ns.Settings.AURA_GROUPS) do
        local container = frame.auraContainers[key].container
        if container:GetUnit() ~= unit then
            container:SetUnit(unit)
        elseif event ~= "UNIT_AURA" then
            container:UpdateAllAuras()
        end
    end
end

-- Party slots reshuffled: party2 may now be someone else under the same
-- token, which the container does not notice by itself.
ns.On("GROUP_ROSTER_UPDATE", function()
    for frame in pairs(all) do
        if frame.key == ns.Party.KEY then AuraContainers.Refresh(frame, "GROUP_ROSTER_UPDATE") end
    end
end)

-- Test mode shows our samples instead (a container shows only real auras).
function AuraContainers.Hide(frame)
    if not frame.auraContainers then return end
    for _, key in ipairs(ns.Settings.AURA_GROUPS) do frame.auraContainers[key].container:Hide() end
end

ns.Listen("TEST_MODE", function(on)
    if on then return end
    for frame in pairs(all) do
        for _, key in ipairs(ns.Settings.AURA_GROUPS) do
            frame.auraContainers[key].container:SetShown(frame.auras[key].enabled)
        end
    end
end)
