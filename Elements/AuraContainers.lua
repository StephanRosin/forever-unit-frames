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
        lineSize = math.max(lineSize, group.size),
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
