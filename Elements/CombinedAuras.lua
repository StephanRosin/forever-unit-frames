local _, ns = ...

-- Optional single native flow for helpful + harmful auras. Four Blizzard
-- aura groups share ONE CustomAuraContainerTemplate and hence one wrapping
-- layout. The original two containers are retained, ready to show again.
-- Never inspect aura data in Lua: the client sorts and updates it in combat.
local Combined = {}
ns.CombinedAuras = Combined

local Config, Native, Auras = ns.Config, ns.AuraContainers, ns.Auras
local original = {
    Ensure = Native.Ensure, Style = Native.Style, Refresh = Native.Refresh,
    Hide = Native.Hide, Relead = Native.Relead,
}
local KEYS = { "buffs", "debuffs" }
local PARTS = { "own", "other" }
local STEP = { RIGHT = { 1, 0 }, LEFT = { -1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
local pending = setmetatable({}, { __mode = "k" })
local known = setmetatable({}, { __mode = "k" })
local previewed = setmetatable({}, { __mode = "k" })

local function testing(frame)
    return ns.TestMode and ns.TestMode.Covers(frame) or false
end

local function eligible(frame)
    return frame and frame.auras and frame.auras.buffs and frame.auras.debuffs
        and frame.auraContainers and frame.auraContainers.buffs and frame.auraContainers.debuffs
        and not frame.pretend
end

local function wanted(frame)
    return eligible(frame) and Config.Get(frame.key, "combineAuras") == true
end

-- In combined mode the other aura container is deliberately hidden.
-- Resolve Buffs->OTHER to the unit frame, never through any Debuffs setting.
-- All other anchor choices and all points/offsets come from Buffs.
local function anchorRegion(frame, live)
    if Config.Get(frame.key, "buffsAnchor") == "OTHER" then return frame.unitBox or frame end
    return Auras.AnchorRegion(frame, "buffs", live)
end

local function lead(frame, group)
    if frame.key ~= "player" or not frame.auras.buffs.enabled then return 0, 0, 0 end
    local n = frame.enchantLead or 0
    local amount = n * (group.size + group.spacing)
    local direction = STEP[group.primary] or STEP.RIGHT
    return amount, direction[1] * amount, direction[2] * amount
end

-- Existing weapon enchants are plain icons, not auras. Position them at
-- the start of the combined stream, using the SAME anchor/size/direction.
local function placeEnchants(frame, key)
    if frame.key ~= "player" or not frame.enchantButtons then return end
    if not frame.auras.buffs.enabled then return end
    local group = frame.auras[key]
    local region = anchorRegion(frame, true)
    local x, y = Auras.AnchorOffset(frame, key, region)
    local direction = STEP[group.primary] or STEP.RIGHT
    for i, button in ipairs(frame.enchantButtons) do
        if button:IsShown() then
            ns.AuraButton.Style(button, frame.key, group.size, frame.auras.buffs.showTime)
            local step = (i - 1) * (group.size + group.spacing)
            button:ClearAllPoints()
            button:SetPoint(Config.Get(frame.key, key .. "Point"), region,
                Config.Get(frame.key, key .. "FramePoint"), x + direction[1] * step, y + direction[2] * step)
        end
    end
end

local function flowAndPlace(frame, entry)
    local key = "buffs"
    local group = frame.auras.buffs
    local flow = Native.Flow(group)
    local occupied, dx, dy = lead(frame, group)
    local container = entry.container
    container:SetFlowLayoutAxis(flow.axis)
    container:SetFlowLayoutAnchorPoint(flow.anchor)
    container:SetFlowLayoutGrowthDirection(flow.horizontal, flow.vertical)
    container:SetFlowLayoutMaximumLineSize(math.max(flow.lineSize - occupied, group.size))
    local region = anchorRegion(frame, true)
    local x, y = Auras.AnchorOffset(frame, key, region)
    container:ClearAllPoints()
    container:SetPoint(Config.Get(frame.key, key .. "Point"), region,
        Config.Get(frame.key, key .. "FramePoint"), x + dx, y + dy)
    placeEnchants(frame, key)
    return group.size, group.spacing
end

-- Both types use the same icon size and spacing in combined mode, or the
-- client's row wrapping can skip or overlap cells of different sizes.
-- Group filters and per-type maximums stay independent.
-- The Buffs panel is the single source of truth for all presentation,
-- display filters and sizing while combined. Only HELPFUL/HARMFUL identity,
-- whether each type is enabled, and its spell blocklist remain per type.
-- The separate dispels container still owns dispellable harmful auras.
local function specification(frame, group, part, base)
    local own = part == "own"
    local split = base.highlightOwn or base.casterBorder
    local onlyMine = Config.Get(frame.key, "buffsOnlyMine") == true
    -- When split, BOTH PLAYER and !PLAYER groups must remain enabled,
    -- except when Buffs is configured to show only the player's auras.
    local enabled = group.enabled and (own and split or (not own and (not split or not onlyMine)))
    local filter = group.isDebuff and "HARMFUL" or "HELPFUL"
    if group.isDebuff and Auras.DispelsShown(frame) then filter = filter .. "|!RAID" end
    if onlyMine then
        filter = filter .. "|PLAYER"
    elseif split then
        filter = filter .. (own and "|PLAYER" or "|!PLAYER")
    end
    -- The same hide-duration/tracking rules as Buffs, but retain each
    -- aura type's own blocklist and the shield-watch exclusion only on buffs.
    local filters = Native.CandidateFilters({
        hidePermanent = base.hidePermanent,
        hideLonger = base.hideLonger,
        hideTracking = base.hideTracking,
        blockSet = group.blockSet,
    })
    local ownSize = (own and base.highlightOwn) and base.ownSize or base.size
    local spacing = base.spacing
    return {
        enabled = enabled,
        filter = filter,
        max = base.max,
        candidateFilters = filters,
        layout = {
            elementWidth = ownSize, elementHeight = ownSize,
            elementSpacing = spacing, lineSpacing = spacing,
            groupSpacing = spacing, groupLineSpacing = spacing,
            -- Never insert an artificial line at the buff/debuff boundary.
            forceNewLine = false,
        },
    }
end

local function create(frame)
    local container
    local entry = { buttons = {}, active = false }
    local ok, err = pcall(function()
        container = CreateFrame("AuraContainer", nil, frame, Native.TEMPLATE)
        entry.container = container
        container:SetEditModePreviewEnabled(false)
        local base = frame.auras.buffs
        for _, key in ipairs(KEYS) do
            local group = frame.auras[key]
            for _, part in ipairs(PARTS) do
                local own = part == "own"
                local p = specification(frame, group, part, base)
                container:AddAuraGroup(key .. part, p.filter, {
                    maxFrameCount = p.max, layout = p.layout, candidateFilters = p.candidateFilters,
                    initializeFrame = function(button)
                        ns.AuraButton.Decorate(button, group.isDebuff)
                        button.casterBorder = Native.CasterBorder(group, own)
                        ns.AuraButton.StyleManaged(button, frame.key, (own and base.highlightOwn) and base.ownSize or base.size, base.showTime)
                        entry.buttons[#entry.buttons + 1] = { button = button, key = key, own = own }
                        Native.Wire(button, group.isDebuff)
                    end,
                })
            end
        end
        container:SetUnit(frame.unit or "none")
        container:Hide()
    end)
    if not ok then
        if container then container:Hide() end
        frame.fufCombinedAurasFailed = true
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(err) end
        return nil
    end
    frame.combinedAuraEntry = entry
    known[frame] = true
    return entry
end

local function setPart(container, name, p)
    container:SetAuraGroupFilterString(name, p.filter)
    container:SetAuraGroupMaxFrameCount(name, p.max)
    container:SetAuraGroupLayout(name, p.layout)
    container:SetAuraGroupCandidateFilters(name, p.candidateFilters)
    container:SetAuraGroupEnabled(name, p.enabled)
end

local function restyle(frame, entry, size)
    local retry = false
    for _, record in ipairs(entry.buttons) do
        local group = frame.auras[record.key]
        record.button.casterBorder = Native.CasterBorder(group, record.own)
        local ownSize = record.own and frame.auras.buffs.highlightOwn
            and frame.auras.buffs.ownSize or size
        if not pcall(ns.AuraButton.StyleManaged, record.button, frame.key, ownSize,
            frame.auras.buffs.showTime) then
            retry = true
        end
    end
    entry.stale = retry
end

local function separateVisibility(frame, show)
    for _, key in ipairs(KEYS) do
        local native = frame.auraContainers[key]
        local group = frame.auras[key]
        local visible = show and group.enabled and not testing(frame)
        native.container:SetShown(visible and true or false)
        if native.ownContainer then native.ownContainer:SetShown(visible and native.apart or false) end
    end
end

local function display(frame, entry, active)
    entry.active = active and true or false
    entry.container:SetShown(entry.active and not testing(frame))
    separateVisibility(frame, not entry.active)
end

-- Forward declaration (deferred combat changes need this function).
local sync
local function flush()
    for frame in pairs(pending) do
        pending[frame] = nil
        if frame.auraContainers then sync(frame) end
    end
end
local function defer(frame)
    pending[frame] = true
    ns.AfterCombat("fufCombinedAuras", flush)
end

sync = function(frame)
    if not eligible(frame) or frame.fufCombinedSyncing then return end
    if InCombatLockdown() then defer(frame); return end
    frame.fufCombinedSyncing = true
    local enabled = wanted(frame)
    local entry = frame.combinedAuraEntry
    if enabled and not entry and not frame.fufCombinedAurasFailed then entry = create(frame) end
    if not enabled or not entry then
        local wasCombined = entry and entry.active
        if entry then display(frame, entry, false) else separateVisibility(frame, true) end
        -- The original layout put weapon enchants before the buff group.
        -- Restore that anchor when leaving combined mode.
        if wasCombined and ns.WeaponEnchants then ns.WeaponEnchants.Layout(frame) end
        frame.fufCombinedSynchronized = true
        frame.fufCombinedSyncing = nil
        return
    end
    local wasActive = entry.active
    local ok, err = pcall(function()
        local size, spacing = flowAndPlace(frame, entry)
        for _, key in ipairs(KEYS) do
            for _, part in ipairs(PARTS) do
                setPart(entry.container, key .. part, specification(frame, frame.auras[key], part, frame.auras.buffs))
            end
        end
        restyle(frame, entry, size)
        local base = frame.auras.buffs
        entry.applied = { size = base.size, spacing = base.spacing,
            growth = base.primary, rowGrowth = base.row, max = base.max,
            showTime = base.showTime, anchor = Config.Get(frame.key, "buffsAnchor"),
            perRow = base.perRowSetting, hidePermanent = base.hidePermanent,
            onlyMine = Config.Get(frame.key, "buffsOnlyMine") }
        display(frame, entry, true)
        if not wasActive then
            -- The container may have been hidden while its unit changed.
            if entry.container:GetUnit() ~= (frame.unit or "none") then
                entry.container:SetUnit(frame.unit or "none")
            else
                entry.container:UpdateAllAuras()
            end
        end
    end)
    if not ok then
        frame.fufCombinedAurasFailed = true
        entry.container:Hide()
        display(frame, entry, false)
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(err) end
    end
    frame.fufCombinedSynchronized = true
    frame.fufCombinedSyncing = nil
end

function Combined.Active(frame)
    return frame and frame.combinedAuraEntry and frame.combinedAuraEntry.active or false
end

-- Preserve the existing client-driven implementation and intercept only
-- the points where combined geometry/visibility must change.
function Native.Ensure(frame)
    local ok = original.Ensure(frame)
    if ok and frame.auraContainers and not frame.fufCombinedSynchronized then
        sync(frame)
    elseif ok and not frame.auraContainers and frame.auras
        and Config.Get(frame.key, "combineAuras") then
        -- Native.Ensure can report success while its creation is deferred
        -- until combat ends; arrange the combined setup after that job.
        defer(frame)
    end
    return ok
end

function Native.Style(frame)
    original.Style(frame)
    if not frame.auraContainers then return end
    frame.fufCombinedSynchronized = nil
    sync(frame)
end

function Native.Refresh(frame, event)
    original.Refresh(frame, event)
    local entry = frame.combinedAuraEntry
    if not entry or not entry.active or testing(frame) then return end
    local unit = frame.unit or "none"
    if entry.container:GetUnit() ~= unit then
        entry.container:SetUnit(unit)
    elseif event ~= "UNIT_AURA" then
        entry.container:UpdateAllAuras()
    end
end

function Native.Hide(frame)
    original.Hide(frame)
    if frame.combinedAuraEntry then frame.combinedAuraEntry.container:Hide() end
end

function Native.Relead(frame)
    original.Relead(frame)
    local entry = frame.combinedAuraEntry
    if entry and entry.active and not frame.fufCombinedSyncing then
        -- Like the original Relead, a plain aura container can adjust its
        -- layout during combat when weapon enchants are added/removed.
        local ok = pcall(flowAndPlace, frame, entry)
        if not ok then defer(frame) end
    end
end

-- Test Mode uses plain sample icons, not the native Blizzard containers.
-- Do not repurpose each old group's sample buttons: Auras.showSamples() uses
-- Debuffs' own max/size/own-placement settings, and leaves excess icons at
-- the old anchor. Instead, suppress those two sets of sample icons and draw
-- a single preview pool with Buffs' settings as the only layout source.
-- The native live path above is unchanged.
local previousAurasUpdate = Auras.Update
local previousAurasStyle = Auras.Style
local DIRECTION = {
    RIGHT = { 1, 0 }, LEFT = { -1, 0 },
    UP = { 0, 1 }, DOWN = { 0, -1 },
}

local function previewWanted(frame)
    return frame and frame.auras and frame.auras.buffs and frame.auras.debuffs
        and testing(frame) and Config.Get(frame.key, "combineAuras") == true
end

local function hideOriginalSamples(frame)
    for _, key in ipairs(KEYS) do
        local group = frame.auras[key]
        for _, block in ipairs({ group, group.free }) do
            for _, button in ipairs(block.buttons) do button:Hide() end
        end
    end
end

local function previewState(frame)
    local state = frame.fufCombinedPreview
    if not state then
        local holder = CreateFrame("Frame", nil, frame)
        state = { holder = holder, buttons = {}, started = GetTime() }
        frame.fufCombinedPreview = state
    elseif not previewed[frame] then
        -- Test Mode can be entered repeatedly during a session. Start
        -- sample cooldown swipes anew instead of reusing expired times.
        state.started = GetTime()
    end
    return state
end

local function previewButton(frame, state, key, index)
    state.buttons[key] = state.buttons[key] or {}
    local button = state.buttons[key][index]
    if not button then
        button = ns.AuraButton.Create(state.holder, key == "debuffs")
        state.buttons[key][index] = button
    end
    return button
end

local function restorePreview(frame)
    if not previewed[frame] then return end
    previewed[frame] = nil
    local state = frame.fufCombinedPreview
    if state then
        state.holder:Hide()
        for _, key in ipairs(KEYS) do
            for _, button in ipairs(state.buttons[key] or {}) do button:Hide() end
        end
    end
    -- Auras.Style() does not call ShowSample on icons that this preview
    -- hid. When switching back to separate mode while Test Mode remains
    -- on, explicitly regenerate both original sample groups once.
    if testing(frame) and frame.auraSamples then previousAurasUpdate(frame) end
end

local function placePreview(frame, forceStyle)
    if not previewWanted(frame) then
        restorePreview(frame)
        return
    end
    -- Samples are not ready until the original Auras.Update has run.
    if not frame.auraSamples then return end

    local base, state = frame.auras.buffs, previewState(frame)
    local holder = state.holder
    local scope = frame.key
    local region = anchorRegion(frame, false)
    local x, y = Auras.AnchorOffset(frame, "buffs", region)
    local _, dx, dy = lead(frame, base)
    holder:ClearAllPoints()
    holder:SetPoint(Config.Get(scope, "buffsPoint"), region,
        Config.Get(scope, "buffsFramePoint"), x + dx, y + dy)
    holder:SetFrameLevel(frame:GetFrameLevel() + Auras.LEVELS)

    local spacing = base.spacing
    local rowLimit = base.perRowSetting
    local length = base.length
    if rowLimit > 0 then length = rowLimit * base.size + (rowLimit - 1) * spacing end
    local direction = DIRECTION[base.primary] or DIRECTION.RIGHT
    local rowDirection = DIRECTION[base.row] or DIRECTION.DOWN
    local along, across, rowDepth, inRow = 0, 0, 0, 0
    local maxAlong, maxAcross = 0, 0
    local ownLimit = Auras.OWN_SAMPLES or 2
    local onlyMine = Config.Get(scope, "buffsOnlyMine") == true
    local split = base.highlightOwn or base.casterBorder

    for _, key in ipairs(KEYS) do
        local group = frame.auras[key]
        local samples = Auras.SAMPLES[key]
        local count = group.enabled and base.max or 0
        for i = 1, count do
            local button = previewButton(frame, state, key, i)
            local own = onlyMine or (split and i <= ownLimit)
            local size = own and base.highlightOwn and base.ownSize or base.size
            if inRow > 0 and ((rowLimit > 0 and inRow >= rowLimit)
                or (rowLimit == 0 and along + size > length + 0.5)) then
                across, along, rowDepth, inRow = across + rowDepth + spacing, 0, 0, 0
            end
            if forceStyle or button.styledSize ~= size or button.fufCombinedPreviewTime ~= base.showTime then
                ns.AuraButton.Style(button, scope, size, base.showTime)
                button.styledSize, button.fufCombinedPreviewTime = size, base.showTime
            end
            local sample = samples[(i - 1) % #samples + 1]
            ns.AuraButton.ShowSample(button, sample, state.started)
            ns.AuraButton.SetCasterBorder(button, Native.CasterBorder(group, own))
            local bx = direction[1] * along + rowDirection[1] * across
            local by = direction[2] * along + rowDirection[2] * across
            button:ClearAllPoints()
            button:SetPoint(base.corner, holder, base.corner, bx, by)
            maxAlong = math.max(maxAlong, along + size)
            maxAcross = math.max(maxAcross, across + size)
            rowDepth = math.max(rowDepth, size)
            along, inRow = along + size + spacing, inRow + 1
        end
        -- A previous test selection may have made more buttons than the
        -- currently selected maximum. Hide every surplus button rather
        -- than leaving its old buff/debuff row visible.
        for i = count + 1, #(state.buttons[key] or {}) do state.buttons[key][i]:Hide() end
    end
    local horizontal = base.primary == "LEFT" or base.primary == "RIGHT"
    local width, height = horizontal and maxAlong or maxAcross,
        horizontal and maxAcross or maxAlong
    holder:SetSize(math.max(width, ns.Pixel.One()), math.max(height, ns.Pixel.One()))
    holder:Show()
    hideOriginalSamples(frame)
    previewed[frame] = true
end

function Auras.Update(frame, ...)
    previousAurasUpdate(frame, ...)
    if previewWanted(frame) or previewed[frame] then placePreview(frame, false) end
end

function Auras.Style(frame, ...)
    previousAurasStyle(frame, ...)
    if previewWanted(frame) or previewed[frame] then placePreview(frame, true) end
end

ns.Listen("TEST_MODE", function(on)
    if not on then
        for frame in pairs(previewed) do restorePreview(frame) end
    end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
    for frame in pairs(known) do
        if frame.combinedAuraEntry and frame.combinedAuraEntry.stale then sync(frame) end
    end
end)

ns.Listen("TEST_MODE", function(on)
    if on then return end
    -- The native module shows the two original groups when leaving test
    -- mode; restore the combined visibility if it is still selected.
    for frame in pairs(known) do
        if frame.combinedAuraEntry then
            local entry = frame.combinedAuraEntry
            display(frame, entry, wanted(frame) and not frame.fufCombinedAurasFailed)
            if entry.active then entry.container:UpdateAllAuras() end
        end
    end
end)
